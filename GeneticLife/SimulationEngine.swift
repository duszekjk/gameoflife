import SwiftUI
import Combine

@MainActor
final class SimulationEngine: ObservableObject {
    @Published var configuration = SimulationConfiguration()
    @Published private(set) var organisms: [Organism] = []
    @Published private(set) var step: EvolutionStep = .initialPopulation
    @Published private(set) var generation: Int = 1
    @Published private(set) var elapsedTime: Double = 0
    @Published private(set) var isRunningEnvironment = false
    @Published var automaticMode = false
    @Published private(set) var selectedParents: [Organism] = []
    @Published private(set) var offspring: [Organism] = []
    @Published private(set) var mutatedGeneDescription: String?
    @Published private(set) var statusMessage: String?

    var arenaSize = CGSize(width: 700, height: 430)

    private var timer: Timer?
    private var lastTick = Date()
    private var automaticTask: Task<Void, Never>?

    init() {
        resetPopulation()
    }

    deinit {
        timer?.invalidate()
        automaticTask?.cancel()
    }

    func resetPopulation() {
        stopTimer()
        automaticTask?.cancel()
        generation = 1
        step = .initialPopulation
        elapsedTime = 0
        selectedParents = []
        offspring = []
        mutatedGeneDescription = nil
        statusMessage = nil
        organisms = makeRandomPopulation()
    }

    func applyConfigurationAndReset() {
        configuration.minimumAnimalSurvivors = min(
            configuration.minimumAnimalSurvivors,
            max(1, configuration.animalCount - 1)
        )
        resetPopulation()
    }

    func nextStep() {
        guard !isRunningEnvironment else { return }

        switch step {
        case .initialPopulation:
            beginEnvironment()
        case .environment:
            finishEnvironment()
        case .fitness:
            performSelection()
            step = .selection
            scheduleAutomaticAdvanceIfNeeded()
        case .selection:
            performCrossover()
            step = .crossover
            scheduleAutomaticAdvanceIfNeeded()
        case .crossover:
            performMutation()
            step = .mutation
            scheduleAutomaticAdvanceIfNeeded()
        case .mutation:
            installNewGeneration()
            step = .newGeneration
            scheduleAutomaticAdvanceIfNeeded()
        case .newGeneration:
            step = .initialPopulation
            selectedParents = []
            offspring = []
            mutatedGeneDescription = nil
            statusMessage = nil
            scheduleAutomaticAdvanceIfNeeded()
        }
    }

    func setAutomaticMode(_ enabled: Bool) {
        automaticMode = enabled
        automaticTask?.cancel()
        if enabled && !isRunningEnvironment {
            scheduleAutomaticAdvanceIfNeeded()
        }
    }

    func stats() -> GenerationStatistics {
        let living = organisms.filter(\.isAlive)
        let animals = living.filter { $0.genome.kind != .plant }
        let plants = living.filter { $0.genome.kind == .plant }

        return GenerationStatistics(
            averageSize: average(living.map { $0.genome.size }),
            averageSpeed: average(animals.map { $0.genome.speed }),
            averageVision: average(animals.map { $0.genome.vision }),
            averageGreen: average(plants.map { $0.genome.green }),
            livingPlants: plants.count,
            livingHerbivores: living.filter { $0.genome.kind == .herbivore }.count,
            livingPredators: living.filter { $0.genome.kind == .predator }.count
        )
    }

    func geneComparisons() -> [GeneComparison] {
        guard let child = offspring.first else { return [] }
        let sameTypeParents = selectedParents.filter { $0.genome.kind == child.genome.kind }
        guard sameTypeParents.count >= 2 else { return [] }

        let a = sameTypeParents[0].genome
        let b = sameTypeParents[1].genome
        let c = child.genome

        return [
            comparison("Size", a.size, c.size, b.size),
            comparison("Speed", a.speed, c.speed, b.speed),
            comparison("Vision", a.vision, c.vision, b.vision),
            comparison("Red", a.red, c.red, b.red),
            comparison("Green", a.green, c.green, b.green),
            comparison("Blue", a.blue, c.blue, b.blue)
        ]
    }

    private func comparison(_ name: String, _ a: Double, _ child: Double, _ b: Double) -> GeneComparison {
        GeneComparison(
            name: name,
            parentA: a,
            child: child,
            parentB: b,
            inheritedFromA: abs(child - a) <= abs(child - b)
        )
    }

    private func beginEnvironment() {
        step = .environment
        elapsedTime = 0
        statusMessage = nil
        isRunningEnvironment = true
        lastTick = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func finishEnvironment() {
        stopTimer()
        evaluateFitness()
        step = .fitness
        scheduleAutomaticAdvanceIfNeeded()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunningEnvironment = false
    }

    private func tick() {
        let now = Date()
        let dt = min(0.05, now.timeIntervalSince(lastTick))
        lastTick = now
        elapsedTime += dt

        updatePlants(dt: dt)
        updateAnimals(dt: dt)
        resolveCollisions()

        let livingAnimals = organisms.filter { $0.isAlive && $0.genome.kind != .plant }.count
        if elapsedTime >= configuration.simulationDuration ||
            livingAnimals <= configuration.minimumAnimalSurvivors {
            if livingAnimals <= configuration.minimumAnimalSurvivors {
                statusMessage = "The environment ended early because only \(livingAnimals) animals remain."
            }
            finishEnvironment()
        }
    }

    private func updatePlants(dt: Double) {
        for index in organisms.indices where organisms[index].isAlive && organisms[index].genome.kind == .plant {
            let genome = organisms[index].genome
            let production = (0.7 + genome.size * 1.4) * genome.photosynthesisEfficiency
            organisms[index].energy = min(140, organisms[index].energy + production * dt)
        }
    }

    private func updateAnimals(dt: Double) {
        let snapshot = organisms

        for index in organisms.indices {
            guard organisms[index].isAlive, organisms[index].genome.kind != .plant else { continue }

            let me = snapshot[index]
            let desired = steeringVector(for: me, in: snapshot)
            let speed = 22 + me.genome.speed * 68

            if desired.dx != 0 || desired.dy != 0 {
                let direction = normalized(desired)
                organisms[index].velocity = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
            } else if hypot(me.velocity.dx, me.velocity.dy) < 1 {
                organisms[index].velocity = randomVelocity(speed: speed)
            }

            organisms[index].position.x += organisms[index].velocity.dx * dt
            organisms[index].position.y += organisms[index].velocity.dy * dt
            keepInsideArena(index: index)

            let movementCost = 0.45 + me.genome.speed * 0.75 + me.genome.size * 0.42
            let visionCost = me.genome.vision * 0.55
            organisms[index].energy -= (movementCost + visionCost) * dt

            if organisms[index].energy <= 0 {
                organisms[index].energy = 0
                organisms[index].isAlive = false
            }
        }
    }

    private func steeringVector(for organism: Organism, in snapshot: [Organism]) -> CGVector {
        let visible = snapshot.filter { target in
            guard target.id != organism.id, target.isAlive else { return false }
            let distance = distance(organism.position, target.position)
            let effectiveVision = (45 + organism.genome.vision * 155) * (0.55 + target.genome.visibility)
            return distance <= effectiveVision
        }

        if organism.genome.kind == .herbivore {
            let threats = visible.filter { $0.genome.kind == .predator && $0.genome.size >= organism.genome.size * 0.75 }
            if let threat = nearest(to: organism, among: threats) {
                return CGVector(
                    dx: organism.position.x - threat.position.x,
                    dy: organism.position.y - threat.position.y
                )
            }

            let plants = visible.filter { $0.genome.kind == .plant }
            if let plant = nearest(to: organism, among: plants) {
                return CGVector(
                    dx: plant.position.x - organism.position.x,
                    dy: plant.position.y - organism.position.y
                )
            }
        }

        if organism.genome.kind == .predator {
            let prey = visible.filter {
                $0.genome.kind != .plant &&
                $0.genome.kind != organism.genome.kind &&
                $0.genome.size < organism.genome.size * 1.25
            } + visible.filter {
                $0.genome.kind == .predator &&
                $0.genome.size < organism.genome.size * 0.72
            }

            if let target = nearest(to: organism, among: prey) {
                return CGVector(
                    dx: target.position.x - organism.position.x,
                    dy: target.position.y - organism.position.y
                )
            }
        }

        let current = organism.velocity
        let jitter = CGVector(dx: Double.random(in: -12...12), dy: Double.random(in: -12...12))
        return CGVector(dx: current.dx + jitter.dx, dy: current.dy + jitter.dy)
    }

    private func resolveCollisions() {
        guard organisms.count > 1 else { return }

        for i in organisms.indices {
            guard organisms[i].isAlive else { continue }

            for j in organisms.indices where j > i {
                guard organisms[j].isAlive else { continue }

                let collisionDistance = organisms[i].radius + organisms[j].radius
                guard distance(organisms[i].position, organisms[j].position) <= collisionDistance else { continue }

                handleInteraction(i, j)
            }
        }
    }

    private func handleInteraction(_ i: Int, _ j: Int) {
        let kindA = organisms[i].genome.kind
        let kindB = organisms[j].genome.kind

        if kindA == .herbivore && kindB == .plant {
            consumePlant(eater: i, plant: j)
            return
        }
        if kindB == .herbivore && kindA == .plant {
            consumePlant(eater: j, plant: i)
            return
        }

        if kindA == .predator && kindB != .plant {
            tryPredation(predator: i, prey: j)
            return
        }
        if kindB == .predator && kindA != .plant {
            tryPredation(predator: j, prey: i)
        }
    }

    private func consumePlant(eater: Int, plant: Int) {
        guard organisms[eater].isAlive, organisms[plant].isAlive else { return }
        let plantGenome = organisms[plant].genome
        let gain = 15 + (plantGenome.size * 34 * plantGenome.photosynthesisEfficiency)
        organisms[eater].energy = min(170, organisms[eater].energy + gain)
        organisms[eater].foodEaten += 1
        organisms[plant].isAlive = false
        organisms[plant].energy = 0
    }

    private func tryPredation(predator: Int, prey: Int) {
        guard organisms[predator].isAlive, organisms[prey].isAlive else { return }
        let predatorSize = organisms[predator].genome.size
        let preySize = organisms[prey].genome.size

        guard preySize < predatorSize * 1.25 else { return }

        let gain = 32 + preySize * 48
        organisms[predator].energy = min(190, organisms[predator].energy + gain)
        organisms[predator].foodEaten += 1
        organisms[prey].isAlive = false
        organisms[prey].energy = 0
    }

    private func evaluateFitness() {
        for index in organisms.indices {
            guard organisms[index].isAlive else {
                organisms[index].fitness = 0
                continue
            }

            let foodBonus = Double(organisms[index].foodEaten) * 16
            let survivalBonus = organisms[index].genome.kind == .plant ? 8.0 : 20.0
            organisms[index].fitness = max(0, organisms[index].energy) + foodBonus + survivalBonus
        }
    }

    private func performSelection() {
        selectedParents = []
        let requiredKinds: [OrganismKind] = [.plant, .herbivore, .predator]

        for kind in requiredKinds {
            let candidates = organisms.filter { $0.isAlive && $0.genome.kind == kind }
            guard !candidates.isEmpty else { continue }

            let count = kind == .plant ? max(2, configuration.plantCount) :
                (kind == .herbivore ? max(2, configuration.herbivoreCount) : max(2, configuration.predatorCount))

            for _ in 0..<count {
                if let chosen = weightedChoice(from: candidates) {
                    selectedParents.append(chosen)
                }
            }
        }

        if selectedParents.isEmpty {
            statusMessage = "No organisms survived. The next generation will be reseeded randomly so the lesson can continue."
        }
    }

    private func performCrossover() {
        offspring = []
        offspring += makeOffspring(kind: .plant, count: configuration.plantCount)
        offspring += makeOffspring(kind: .herbivore, count: configuration.herbivoreCount)
        offspring += makeOffspring(kind: .predator, count: configuration.predatorCount)
    }

    private func makeOffspring(kind: OrganismKind, count: Int) -> [Organism] {
        let parents = selectedParents.filter { $0.genome.kind == kind }

        return (0..<count).map { _ in
            let genome: Genome
            if let a = parents.randomElement(), let b = parents.randomElement() {
                genome = crossoverSameType(a.genome, b.genome)
            } else {
                genome = .random(kind: kind)
            }

            return Organism(
                genome: genome,
                position: randomPosition(),
                velocity: kind == .plant ? .zero : randomVelocity(speed: 22 + genome.speed * 68)
            )
        }
    }

    private func crossoverSameType(_ a: Genome, _ b: Genome) -> Genome {
        precondition(a.kind == b.kind, "Crossover is only valid between organisms of the same type.")

        Genome(
            kind: a.kind,
            size: Bool.random() ? a.size : b.size,
            speed: a.kind == .plant ? 0 : (Bool.random() ? a.speed : b.speed),
            vision: a.kind == .plant ? 0 : (Bool.random() ? a.vision : b.vision),
            red: Bool.random() ? a.red : b.red,
            green: Bool.random() ? a.green : b.green,
            blue: Bool.random() ? a.blue : b.blue
        )
    }

    private func performMutation() {
        mutatedGeneDescription = nil

        for index in offspring.indices {
            guard Double.random(in: 0...1) < configuration.mutationRate else { continue }

            let gene = Int.random(in: 0...5)
            let amount = Double.random(in: -0.10...0.10)

            switch gene {
            case 0:
                let old = offspring[index].genome.size
                offspring[index].genome.size = clamp(old + amount)
                recordMutationIfNeeded(name: "size", old: old, new: offspring[index].genome.size)
            case 1 where offspring[index].genome.kind != .plant:
                let old = offspring[index].genome.speed
                offspring[index].genome.speed = clamp(old + amount)
                recordMutationIfNeeded(name: "speed", old: old, new: offspring[index].genome.speed)
            case 2 where offspring[index].genome.kind != .plant:
                let old = offspring[index].genome.vision
                offspring[index].genome.vision = clamp(old + amount)
                recordMutationIfNeeded(name: "vision", old: old, new: offspring[index].genome.vision)
            case 3:
                let old = offspring[index].genome.red
                offspring[index].genome.red = clamp(old + amount)
                recordMutationIfNeeded(name: "red", old: old, new: offspring[index].genome.red)
            case 4:
                let old = offspring[index].genome.green
                offspring[index].genome.green = clamp(old + amount)
                recordMutationIfNeeded(name: "green", old: old, new: offspring[index].genome.green)
            default:
                let old = offspring[index].genome.blue
                offspring[index].genome.blue = clamp(old + amount)
                recordMutationIfNeeded(name: "blue", old: old, new: offspring[index].genome.blue)
            }
        }

        if mutatedGeneDescription == nil {
            mutatedGeneDescription = "No mutation happened in this sample. Mutation is probabilistic, so some generations contain none."
        }
    }

    private func recordMutationIfNeeded(name: String, old: Double, new: Double) {
        guard mutatedGeneDescription == nil else { return }
        mutatedGeneDescription = "\(name.capitalized): \(old.formatted(.number.precision(.fractionLength(2)))) → \(new.formatted(.number.precision(.fractionLength(2))))"
    }

    private func installNewGeneration() {
        organisms = offspring
        generation += 1
        elapsedTime = 0
    }

    private func weightedChoice(from candidates: [Organism]) -> Organism? {
        guard !candidates.isEmpty else { return nil }
        let total = candidates.reduce(0) { $0 + max(0.001, $1.fitness) }
        var needle = Double.random(in: 0..<total)

        for candidate in candidates {
            needle -= max(0.001, candidate.fitness)
            if needle <= 0 { return candidate }
        }
        return candidates.last
    }

    private func makeRandomPopulation() -> [Organism] {
        var result: [Organism] = []

        func add(_ kind: OrganismKind, count: Int) {
            for _ in 0..<count {
                let genome = Genome.random(kind: kind)
                result.append(
                    Organism(
                        genome: genome,
                        position: randomPosition(),
                        velocity: kind == .plant ? .zero : randomVelocity(speed: 22 + genome.speed * 68)
                    )
                )
            }
        }

        add(.plant, count: configuration.plantCount)
        add(.herbivore, count: configuration.herbivoreCount)
        add(.predator, count: configuration.predatorCount)
        return result
    }

    private func scheduleAutomaticAdvanceIfNeeded() {
        automaticTask?.cancel()
        guard automaticMode, !isRunningEnvironment else { return }

        automaticTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.automaticMode else { return }
                self.nextStep()
            }
        }
    }

    private func randomPosition() -> CGPoint {
        let margin: CGFloat = 24
        return CGPoint(
            x: CGFloat.random(in: margin...max(margin + 1, arenaSize.width - margin)),
            y: CGFloat.random(in: margin...max(margin + 1, arenaSize.height - margin))
        )
    }

    private func randomVelocity(speed: Double) -> CGVector {
        let angle = Double.random(in: 0...(Double.pi * 2))
        return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
    }

    private func keepInsideArena(index: Int) {
        let radius = organisms[index].radius
        let maxX = max(radius, arenaSize.width - radius)
        let maxY = max(radius, arenaSize.height - radius)

        if organisms[index].position.x < radius {
            organisms[index].position.x = radius
            organisms[index].velocity.dx = abs(organisms[index].velocity.dx)
        } else if organisms[index].position.x > maxX {
            organisms[index].position.x = maxX
            organisms[index].velocity.dx = -abs(organisms[index].velocity.dx)
        }

        if organisms[index].position.y < radius {
            organisms[index].position.y = radius
            organisms[index].velocity.dy = abs(organisms[index].velocity.dy)
        } else if organisms[index].position.y > maxY {
            organisms[index].position.y = maxY
            organisms[index].velocity.dy = -abs(organisms[index].velocity.dy)
        }
    }

    private func nearest(to organism: Organism, among candidates: [Organism]) -> Organism? {
        candidates.min {
            distance(organism.position, $0.position) < distance(organism.position, $1.position)
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(Double(a.x - b.x), Double(a.y - b.y))
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0 else { return .zero }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0.05, value))
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
