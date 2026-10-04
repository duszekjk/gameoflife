import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SimulationEngine()
    @State private var showSettings = true
    @State private var showVision = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    teachingHeader

                    if showSettings {
                        settingsPanel
                    }

                    simulationPanel
                    stepVisualization
                    controls
                    statisticsPanel
                }
                .padding()
                .frame(maxWidth: 1050)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Genetic Life")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showSettings ? "Hide settings" : "Settings") {
                        withAnimation { showSettings.toggle() }
                    }
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
                .font(.body)
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
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Experiment settings")
                .font(.headline)

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

            doubleSlider(
                title: "Environment duration",
                value: Binding(
                    get: { engine.configuration.simulationDuration },
                    set: { engine.configuration.simulationDuration = $0 }
                ),
                range: 3...15,
                valueText: "\(engine.configuration.simulationDuration.formatted(.number.precision(.fractionLength(0)))) s"
            )

            doubleSlider(
                title: "Mutation probability",
                value: Binding(
                    get: { engine.configuration.mutationRate },
                    set: { engine.configuration.mutationRate = $0 }
                ),
                range: 0.01...0.25,
                valueText: engine.configuration.mutationRate.formatted(.percent.precision(.fractionLength(0)))
            )

            integerSlider(
                title: "Stop when animals fall to",
                value: binding(
                    get: { engine.configuration.minimumAnimalSurvivors },
                    set: { engine.configuration.minimumAnimalSurvivors = $0 }
                ),
                range: 1...max(2, engine.configuration.animalCount - 1)
            )

            HStack {
                Toggle("Show vision", isOn: $showVision)
                Spacer()
                Button("Apply & restart") {
                    engine.applyConfigurationAndReset()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var simulationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Plant", systemImage: "leaf.fill")
                Text("✿")
                Divider().frame(height: 18)
                Text("◆")
                Text("Herbivore")
                Divider().frame(height: 18)
                Text("▲")
                Text("Predator")
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
                body: "Circle size represents the size gene. Fill colour comes directly from RGB genes. Moving animals also inherit speed and vision. The symbol inside each circle identifies its ecological role, so colour stays free to evolve."
            )

        case .environment:
            conceptCard(
                title: "Genes meet the environment",
                body: "Vision circles show detection range. Visible prey flee predators; predators steer toward prey; herbivores seek plants. Larger vision, faster motion and larger bodies all cost energy. Greener plants generate more energy."
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
            conceptCard(
                title: "Inheritance completed",
                body: "Generation \(engine.generation) now contains the offspring. Their genomes came from selected parents, with occasional mutations. Press Next to inspect this population before running its environment."
            )
        }
    }

    private var fitnessExplanation: some View {
        let ranked = engine.organisms
            .filter { $0.isAlive }
            .sorted { $0.fitness > $1.fitness }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Fitness converts survival into a number")
                .font(.headline)
            Text("The labels in the arena are fitness scores. Remaining energy, food eaten and a survival bonus contribute to fitness. Dead organisms have fitness 0 and cannot become parents.")
                .foregroundStyle(.secondary)

            ForEach(Array(ranked)) { organism in
                HStack {
                    Text(organism.genome.kind.symbol)
                    Text(organism.genome.kind.title)
                    Spacer()
                    Text("energy \(organism.energy.formatted(.number.precision(.fractionLength(0))))")
                        .foregroundStyle(.secondary)
                    Text("fitness \(organism.fitness.formatted(.number.precision(.fractionLength(0))))")
                        .monospacedDigit()
                        .bold()
                }
                .font(.callout)
            }
        }
        .panelStyle()
    }

    private var selectionExplanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selection is weighted, not deterministic")
                .font(.headline)
            Text("Outlined organisms were sampled as parents. Fitness controls probability: a high-fitness organism can be selected several times, while another survivor may not be selected at all.")
                .foregroundStyle(.secondary)

            HStack {
                Text("Parent samples")
                Spacer()
                Text("\(engine.selectedParents.count)")
                    .monospacedDigit()
                    .bold()
            }
            .font(.callout)
        }
        .panelStyle()
    }

    private var crossoverExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crossover mixes parental genes")
                .font(.headline)

            if engine.geneComparisons().isEmpty {
                Text("A species without surviving parents is reseeded randomly so the educational simulation can continue.")
                    .foregroundStyle(.secondary)
            } else {
                Text("This table shows one example child. Each trait is independently copied from one of its two parents.")
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                    GridRow {
                        Text("Gene").bold()
                        Text("Parent A").bold()
                        Text("Child").bold()
                        Text("Parent B").bold()
                    }

                    ForEach(engine.geneComparisons()) { row in
                        GridRow {
                            Text(row.name)
                            Text(row.parentA.formatted(.number.precision(.fractionLength(2))))
                                .foregroundStyle(row.inheritedFromA ? .primary : .secondary)
                            Text(row.child.formatted(.number.precision(.fractionLength(2))))
                                .bold()
                            Text(row.parentB.formatted(.number.precision(.fractionLength(2))))
                                .foregroundStyle(row.inheritedFromA ? .secondary : .primary)
                        }
                        .monospacedDigit()
                    }
                }
                .font(.callout)
            }
        }
        .panelStyle()
    }

    private var mutationExplanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mutation introduces new variation")
                .font(.headline)
            Text("Each child has a \(engine.configuration.mutationRate.formatted(.percent.precision(.fractionLength(0)))) chance of one small gene mutation. Selection does not choose mutations; it can only favour or reject their consequences later.")
                .foregroundStyle(.secondary)

            if let mutation = engine.mutatedGeneDescription {
                Text(mutation)
                    .font(.title3.monospacedDigit().bold())
            }
        }
        .panelStyle()
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
                    stat("Plant green", value: stats.averageGreen.formatted(.number.precision(.fractionLength(2))))
                    Color.clear
                    Color.clear
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        VStack(spacing: 5) {
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
        VStack(spacing: 5) {
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
