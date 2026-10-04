import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SimulationEngine()
    @State private var showVision = true

    var body: some View {
        NavigationSplitView {
            settingsSidebar
                .navigationTitle("Settings")
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            ScrollView {
                VStack(spacing: 18) {
                    teachingHeader
                    simulationPanel
                    stepVisualization
                    controls
                    statisticsPanel
                }
                .padding()
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Genetic Life")
        }
    }

    private var settingsSidebar: some View {
        Form {
            Section("Population") {
                integerSlider(
                    title: "Plants",
                    value: binding(
                        get: { engine.configuration.plantCount },
                        set: { engine.configuration.plantCount = $0 }
                    ),
                    range: 5...60
                )

                integerSlider(
                    title: "Herbivores",
                    value: binding(
                        get: { engine.configuration.herbivoreCount },
                        set: { engine.configuration.herbivoreCount = $0 }
                    ),
                    range: 5...50
                )

                integerSlider(
                    title: "Predators",
                    value: binding(
                        get: { engine.configuration.predatorCount },
                        set: { engine.configuration.predatorCount = $0 }
                    ),
                    range: 1...25
                )
            }

            Section("Genetic algorithm") {
                doubleSlider(
                    title: "Mutation probability",
                    value: Binding(
                        get: { engine.configuration.mutationRate },
                        set: { engine.configuration.mutationRate = $0 }
                    ),
                    range: 0.01...0.25,
                    valueText: engine.configuration.mutationRate.formatted(.percent.precision(.fractionLength(0)))
                )
            }

            Section("Environment") {
                doubleSlider(
                    title: "Simulation duration",
                    value: Binding(
                        get: { engine.configuration.simulationDuration },
                        set: { engine.configuration.simulationDuration = $0 }
                    ),
                    range: 3...15,
                    valueText: "\(engine.configuration.simulationDuration.formatted(.number.precision(.fractionLength(0)))) s"
                )

                integerSlider(
                    title: "Early stop animals",
                    value: binding(
                        get: { engine.configuration.minimumAnimalSurvivors },
                        set: { engine.configuration.minimumAnimalSurvivors = $0 }
                    ),
                    range: 1...max(2, engine.configuration.animalCount - 1)
                )

                Toggle("Show vision circles", isOn: $showVision)
            }

            Section {
                Button("Apply & restart") {
                    engine.applyConfigurationAndReset()
                }
                .frame(maxWidth: .infinity)
            }

            Section("Symbols") {
                Label {
                    Text("Plant")
                } icon: {
                    Text("✿")
                }

                Label {
                    Text("Herbivore")
                } icon: {
                    Text("◆")
                }

                Label {
                    Text("Predator")
                } icon: {
                    Text("▲")
                }
            }
        }
    }

    private var teachingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Generation \(engine.generation)")
                    .font(.headline)
                Spacer()
                Text("Step \(engine.step.number) of \(EvolutionStep.allCases.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(engine.step.number),
                total: Double(EvolutionStep.allCases.count)
            )

            Text(engine.step.title)
                .font(.title2.bold())

            Text(engine.step.explanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let status = engine.statusMessage {
                Label(status, systemImage: "info.circle.fill")
                    .font(.callout)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .panelStyle()
    }

    private var simulationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("✿ Plant")
                Divider().frame(height: 18)
                Text("◆ Herbivore")
                Divider().frame(height: 18)
                Text("▲ Predator")
                Spacer()

                if engine.step == .environment {
                    Text("\(engine.elapsedTime.formatted(.number.precision(.fractionLength(1)))) / \(engine.configuration.simulationDuration.formatted(.number.precision(.fractionLength(0)))) s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.08))

                    ForEach(engine.organisms.filter(\.isAlive)) { organism in
                        organismView(organism)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onAppear {
                    engine.arenaSize = proxy.size
                }
                .onChange(of: proxy.size) { _, newSize in
                    engine.arenaSize = newSize
                }
            }
            .frame(height: 430)
        }
    }

    @ViewBuilder
    private func organismView(_ organism: Organism) -> some View {
        let selected = engine.selectedParents.contains(where: { $0.id == organism.id })
        let showFitness = engine.step == .fitness || engine.step == .selection
        let showSight = showVision && engine.step == .environment && organism.genome.kind != .plant

        ZStack {
            if showSight {
                Circle()
                    .stroke(organism.genome.color.opacity(0.22), lineWidth: 1)
                    .frame(
                        width: 90 + organism.genome.vision * 310,
                        height: 90 + organism.genome.vision * 310
                    )
            }

            Circle()
                .fill(organism.genome.color)
                .overlay(
                    Circle()
                        .stroke(selected ? Color.primary : Color.white.opacity(0.55), lineWidth: selected ? 3 : 1)
                )
                .frame(width: organism.radius * 2, height: organism.radius * 2)

            Text(organism.genome.kind.symbol)
                .font(.system(size: max(9, organism.radius * 0.85), weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 1)

            if showFitness {
                Text(organism.fitness.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(y: organism.radius + 11)
            }
        }
        .position(organism.position)
        .opacity(engine.step == .selection && !selected ? 0.38 : 1)
    }

    @ViewBuilder
    private var stepVisualization: some View {
        switch engine.step {
        case .initialPopulation:
            conceptCard(
                title: "What is inherited?",
                body: "Circle size is the size gene, fill colour is the RGB genome, and the symbol identifies the fixed ecological role. Animals also inherit speed and vision. Plants have speed and vision fixed at zero."
            )

        case .environment:
            conceptCard(
                title: "Genes meet the environment",
                body: "Vision circles show detection range. Herbivores flee visible predators and seek plants. Predators chase visible prey. Movement, body size and vision cost energy, while greener plants generate energy more efficiently."
            )

        case .fitness:
            fitnessExplanation

        case .selection:
            selectionExplanation

        case .crossover:
            crossoverExplanation

        case .mutation:
            mutationExplanation

        case .newGeneration:
            newGenerationExplanation
        }
    }

    private var fitnessExplanation: some View {
        let ranked = engine.organisms
            .filter { $0.isAlive }
            .sorted { $0.fitness > $1.fitness }
        let examples = Array(ranked.prefix(4))

        return VStack(alignment: .leading, spacing: 14) {
            Text("Fitness converts survival into a number")
                .font(.headline)

            Text("The whole population is scored first. Below are four concrete survivors so you can connect their visible phenotype with the fitness value used by selection.")
                .foregroundStyle(.secondary)

            aggregateFitnessTable(ranked: Array(ranked.prefix(8)))

            exampleGrid {
                ForEach(examples) { organism in
                    specimenCard(
                        organism,
                        title: organism.genome.kind.title,
                        footer: "Energy \(organism.energy.formatted(.number.precision(.fractionLength(0)))) · Food \(organism.foodEaten) · Fitness \(organism.fitness.formatted(.number.precision(.fractionLength(0))))"
                    )
                }
            }
        }
        .panelStyle()
    }

    private var selectionExplanation: some View {
        let examples = Array(engine.selectedParents.prefix(4))

        return VStack(alignment: .leading, spacing: 14) {
            Text("Selection chooses parents probabilistically")
                .font(.headline)

            Text("Selection happens independently inside each type. Plants compete with plants, herbivores with herbivores, and predators with predators. Higher fitness increases the probability of being sampled.")
                .foregroundStyle(.secondary)

            HStack {
                Text("Total parent samples")
                Spacer()
                Text("\(engine.selectedParents.count)")
                    .monospacedDigit()
                    .bold()
            }

            exampleGrid {
                ForEach(examples) { organism in
                    specimenCard(
                        organism,
                        title: "Selected \(organism.genome.kind.title)",
                        footer: "Fitness \(organism.fitness.formatted(.number.precision(.fractionLength(0)))) · selection chance ≈ \(selectionChance(for: organism).formatted(.percent.precision(.fractionLength(1))))"
                    )
                }
            }
        }
        .panelStyle()
    }

    private var crossoverExplanation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Crossover mixes DNA from two same-type parents")
                .font(.headline)

            Text("These are actual parent pairings used to create offspring in this generation. Each row shows the two parents, the child that was produced, and which genes came from Parent A. All remaining genes came from Parent B.")
                .foregroundStyle(.secondary)

            if engine.crossoverExamples.isEmpty {
                Text("No valid same-type parent pair was available for an example.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(engine.crossoverExamples.prefix(4))) { example in
                    crossoverCard(example)
                }
            }
        }
        .panelStyle()
    }

    private var mutationExplanation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mutation changes offspring after crossover")
                .font(.headline)

            Text("Four offspring are sampled from the real population. Each has the configured mutation probability. Some examples may show no mutation at all—that is part of the algorithm.")
                .foregroundStyle(.secondary)

            ForEach(Array(engine.mutationExamples.prefix(4))) { example in
                mutationCard(example)
            }
        }
        .panelStyle()
    }

    private var newGenerationExplanation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The offspring become Generation \(engine.generation)")
                .font(.headline)

            Text("The full offspring population now replaces the previous generation. Here are four examples of organisms that actually entered the new population.")
                .foregroundStyle(.secondary)

            exampleGrid {
                ForEach(Array(engine.organisms.prefix(4))) { organism in
                    specimenCard(
                        organism,
                        title: organism.genome.kind.title,
                        footer: genomeSummary(organism.genome)
                    )
                }
            }
        }
        .panelStyle()
    }

    private func aggregateFitnessTable(ranked: [Organism]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
            GridRow {
                Text("Type").bold()
                Text("Energy").bold()
                Text("Food").bold()
                Text("Fitness").bold()
            }

            ForEach(ranked) { organism in
                GridRow {
                    Text("\(organism.genome.kind.symbol) \(organism.genome.kind.title)")
                    Text(organism.energy.formatted(.number.precision(.fractionLength(0))))
                    Text("\(organism.foodEaten)")
                    Text(organism.fitness.formatted(.number.precision(.fractionLength(0))))
                        .bold()
                }
                .monospacedDigit()
            }
        }
        .font(.caption)
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func crossoverCard(_ example: CrossoverExample) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                specimenVisual(example.parentA, label: "Parent A")
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
                specimenVisual(example.parentB, label: "Parent B")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                specimenVisual(example.child, label: "Offspring")
            }
            .frame(maxWidth: .infinity)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                GridRow {
                    Text("Gene").bold()
                    Text("A").bold()
                    Text("Child").bold()
                    Text("B").bold()
                    Text("From").bold()
                }

                geneRow("Size", key: "size", a: example.parentA.genome.size, child: example.child.genome.size, b: example.parentB.genome.size, inherited: example.inheritedFromA)
                if example.child.genome.kind != .plant {
                    geneRow("Speed", key: "speed", a: example.parentA.genome.speed, child: example.child.genome.speed, b: example.parentB.genome.speed, inherited: example.inheritedFromA)
                    geneRow("Vision", key: "vision", a: example.parentA.genome.vision, child: example.child.genome.vision, b: example.parentB.genome.vision, inherited: example.inheritedFromA)
                }
                geneRow("Red", key: "red", a: example.parentA.genome.red, child: example.child.genome.red, b: example.parentB.genome.red, inherited: example.inheritedFromA)
                geneRow("Green", key: "green", a: example.parentA.genome.green, child: example.child.genome.green, b: example.parentB.genome.green, inherited: example.inheritedFromA)
                geneRow("Blue", key: "blue", a: example.parentA.genome.blue, child: example.child.genome.blue, b: example.parentB.genome.blue, inherited: example.inheritedFromA)
            }
            .font(.caption.monospacedDigit())
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func geneRow(
        _ name: String,
        key: String,
        a: Double,
        child: Double,
        b: Double,
        inherited: [String]
    ) -> some View {
        let fromA = inherited.contains(key)

        return GridRow {
            Text(name)
            Text(a.formatted(.number.precision(.fractionLength(2))))
                .foregroundStyle(fromA ? .primary : .secondary)
            Text(child.formatted(.number.precision(.fractionLength(2))))
                .bold()
            Text(b.formatted(.number.precision(.fractionLength(2))))
                .foregroundStyle(fromA ? .secondary : .primary)
            Text(fromA ? "A" : "B")
                .bold()
        }
    }

    private func mutationCard(_ example: MutationExample) -> some View {
        HStack(spacing: 18) {
            specimenVisual(example.before, label: "Before")

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            specimenVisual(example.after, label: "After")

            Divider()
                .frame(height: 64)

            VStack(alignment: .leading, spacing: 5) {
                if let gene = example.gene,
                   let old = example.oldValue,
                   let new = example.newValue {
                    Text("\(gene.capitalized) mutated")
                        .font(.headline)
                    Text("\(old.formatted(.number.precision(.fractionLength(2)))) → \(new.formatted(.number.precision(.fractionLength(2))))")
                        .font(.title3.monospacedDigit().bold())
                } else {
                    Text("No mutation")
                        .font(.headline)
                    Text("This offspring passed through mutation unchanged.")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func specimenCard(_ organism: Organism, title: String, footer: String) -> some View {
        VStack(spacing: 8) {
            specimenVisual(organism, label: title)
            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func specimenVisual(_ organism: Organism, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(organism.genome.color)
                    .frame(
                        width: 34 + organism.genome.size * 30,
                        height: 34 + organism.genome.size * 30
                    )

                Text(organism.genome.kind.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
            .frame(width: 70, height: 70)

            Text(label)
                .font(.caption.bold())

            Text(genomeSummary(organism.genome))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func genomeSummary(_ genome: Genome) -> String {
        var parts = [
            "size \(genome.size.formatted(.number.precision(.fractionLength(2))))",
            "RGB \(genome.red.formatted(.number.precision(.fractionLength(2))))/\(genome.green.formatted(.number.precision(.fractionLength(2))))/\(genome.blue.formatted(.number.precision(.fractionLength(2))))"
        ]

        if genome.kind != .plant {
            parts.append("speed \(genome.speed.formatted(.number.precision(.fractionLength(2))))")
            parts.append("vision \(genome.vision.formatted(.number.precision(.fractionLength(2))))")
        }

        return parts.joined(separator: " · ")
    }

    private func selectionChance(for organism: Organism) -> Double {
        let sameType = engine.organisms.filter {
            $0.isAlive && $0.genome.kind == organism.genome.kind
        }
        let total = sameType.reduce(0) { $0 + max(0.001, $1.fitness) }
        guard total > 0 else { return 0 }
        return max(0.001, organism.fitness) / total
    }

    private func exampleGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
            spacing: 12
        ) {
            content()
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                engine.nextStep()
            } label: {
                Label(
                    engine.step == .initialPopulation ? "Run environment" : "Next step",
                    systemImage: "arrow.right.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(engine.isRunningEnvironment)

            Toggle(
                isOn: Binding(
                    get: { engine.automaticMode },
                    set: { engine.setAutomaticMode($0) }
                )
            ) {
                Label("Automatic", systemImage: "play.circle")
            }
            .toggleStyle(.button)

            Button {
                engine.resetPopulation()
            } label: {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var statisticsPanel: some View {
        let stats = engine.stats()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Population snapshot")
                .font(.headline)

            Grid(horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    stat("Plants", value: "\(stats.livingPlants)")
                    stat("Herbivores", value: "\(stats.livingHerbivores)")
                    stat("Predators", value: "\(stats.livingPredators)")
                }
                GridRow {
                    stat("Avg size", value: stats.averageSize.formatted(.number.precision(.fractionLength(2))))
                    stat("Avg speed", value: stats.averageSpeed.formatted(.number.precision(.fractionLength(2))))
                    stat("Avg vision", value: stats.averageVision.formatted(.number.precision(.fractionLength(2))))
                }
                GridRow {
                    stat("Avg plant green", value: stats.averageGreen.formatted(.number.precision(.fractionLength(2))))
                    Color.clear
                    Color.clear
                }
            }
        }
        .panelStyle()
    }

    private func stat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func conceptCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private func integerSlider(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
    }

    private func doubleSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func binding(get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<Int> {
        Binding(get: get, set: set)
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
