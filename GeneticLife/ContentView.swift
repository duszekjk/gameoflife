import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SimulationEngine()
    @State private var showVision = true

    var body: some View {
        NavigationSplitView {
            settingsSidebar
                .navigationTitle("Settings")
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
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
                    range: 5...max(20, engine.configuration.animalCount - 1)
                )

                Toggle("Show vision circles", isOn: $showVision)
            }

            Section {
                Button("Apply & restart") {
                    engine.applyConfigurationAndReset()
                }
                .frame(maxWidth: .infinity)
            }

            Section("Decision trees") {
                Toggle(
                    "Enable decision-tree lesson",
                    isOn: Binding(
                        get: { engine.decisionTreeMode },
                        set: { engine.setDecisionTreeMode($0) }
                    )
                )

                Text("Off by default. Turn this on before running the environment to predict whether one plant, one herbivore, and one predator will survive.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                    .font(.title3.bold())
                Spacer()
                Text("Step \(engine.step.number) of \(EvolutionStep.allCases.count)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(engine.step.number),
                total: Double(EvolutionStep.allCases.count)
            )

            Text(engine.step.title)
                .font(.largeTitle.bold())

            Text(engine.step.explanation)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let status = engine.statusMessage {
                Label(status, systemImage: "info.circle.fill")
                    .font(.body)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .panelStyle()
    }

    private var simulationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
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
            .font(.title3.bold())

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.08))

                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.35), lineWidth: 3)

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
            VStack(spacing: 18) {
                conceptCard(
                    title: "What is inherited?",
                    body: "Circle size is the size gene, fill colour is the RGB genome, and the symbol identifies the fixed ecological role. Animals also inherit speed and vision. Plants have speed and vision fixed at zero."
                )

                if engine.decisionTreeMode {
                    decisionTreeEditor
                }
            }

        case .environment:
            VStack(spacing: 18) {
                conceptCard(
                    title: "Genes meet the environment",
                    body: "Vision circles show detection range. Herbivores flee visible predators and seek plants. Predators chase visible prey. Movement, body size and vision cost energy, while greener plants generate energy more efficiently."
                )

                if engine.decisionTreeMode {
                    conceptCard(
                        title: "Now we test the expert rules",
                        body: "The decision trees are frozen. They do not control the animals. The simulation now runs independently, and afterward we compare each prediction with what actually happened."
                    )
                }
            }

        case .fitness:
            VStack(spacing: 18) {
                if engine.decisionTreeMode {
                    decisionTreeResults
                }
                fitnessExplanation
            }

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
                .font(.title2.bold())

            Text("The whole population is scored first. Below are four concrete survivors so you can connect their visible phenotype with the fitness value used by selection.")
                .font(.title3)
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
        let examples = engine.selectionExamples

        return VStack(alignment: .leading, spacing: 14) {
            Text("Selection chooses parents probabilistically")
                .font(.title2.bold())

            Text("Selection happens independently inside each type. Plants compete with plants, herbivores with herbivores, and predators with predators. Higher fitness increases the probability of being sampled.")
                .font(.title3)
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
                .font(.title2.bold())

            Text("These are actual parent pairings used to create offspring in this generation. Each row shows the two parents, the child that was produced, and which genes came from Parent A. All remaining genes came from Parent B.")
                .font(.title3)
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
                .font(.title2.bold())

            Text("Four offspring are sampled from the real population. Each has the configured mutation probability. Some examples may show no mutation at all—that is part of the algorithm.")
                .font(.title3)
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
                .font(.title2.bold())

            Text("The full offspring population now replaces the previous generation. Here are four examples of organisms that actually entered the new population.")
                .font(.title3)
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

    private var decisionTreeEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Decision trees — make a prediction before the simulation")
                .font(.largeTitle.bold())

            Text("Act as the domain expert. A decision tree is a sequence of branching questions: each answer sends the specimen down one branch until it reaches a leaf. Different specimens may therefore be evaluated by different questions. Configure the thresholds, inspect the path, then test the prediction against the simulation.")
                .font(.title3)
                .foregroundStyle(.secondary)

            ForEach(engine.decisionTreeCases) { caseStudy in
                decisionTreeCaseEditor(caseStudy)
            }
        }
        .panelStyle()
    }

    private func decisionTreeCaseEditor(_ caseStudy: DecisionTreeCase) -> some View {
        let organism = caseStudy.organism

        return VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                specimenVisual(organism, label: caseStudy.title)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Build the expert tree")
                        .font(.title2.bold())

                    Text(decisionTreeExplanation(for: caseStudy))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("How a decision tree works")
                    .font(.title2.bold())

                Text("Start at the root question. Follow exactly one branch based on YES or NO. That branch may lead to another decision node, and eventually to a leaf such as Survive or Die. Only the questions on the chosen path are evaluated.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            thresholdControls(for: caseStudy)

            Divider()

            Text("Tree structure")
                .font(.title2.bold())

            decisionTreeDiagram(caseStudy)

            Divider()

            Text("Path for this organism")
                .font(.title2.bold())

            VStack(spacing: 12) {
                ForEach(Array(engine.decisionPath(for: caseStudy).enumerated()), id: \.element.id) { index, node in
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.title2.bold())
                            .frame(width: 36, height: 36)
                            .background(.thinMaterial, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(node.question)
                                .font(.title3.bold())

                            Text("value \(node.value.formatted(.number.precision(.fractionLength(2))))  •  threshold \(node.threshold.formatted(.number.precision(.fractionLength(2))))")
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(node.passed ? "YES" : "NO")
                            .font(.title2.bold())

                        Image(systemName: "arrow.right")

                        Text(node.branchLabel)
                            .font(.title3.bold())
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            HStack {
                Text("Final prediction")
                    .font(.title2.bold())
                Spacer()
                Text(engine.decisionPrediction(for: caseStudy).rawValue)
                    .font(.largeTitle.bold())
            }
            .padding(.top, 6)
        }
        .padding(18)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func thresholdControls(for caseStudy: DecisionTreeCase) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Node thresholds")
                .font(.title2.bold())

            Text("A feature may appear in several nodes with different thresholds. That is normal in a decision tree: earlier branches restrict which specimens reach each later split.")
                .font(.title3)
                .foregroundStyle(.secondary)

            largeThresholdSlider(
                title: "Root: minimum energy",
                value: decisionBinding(caseStudy.id, keyPath: \.energyLowThreshold),
                range: 0...120,
                valueText: caseStudy.rules.energyLowThreshold.formatted(.number.precision(.fractionLength(0)))
            )

            largeThresholdSlider(
                title: "Second energy split: high energy",
                value: decisionBinding(caseStudy.id, keyPath: \.energyHighThreshold),
                range: 40...140,
                valueText: caseStudy.rules.energyHighThreshold.formatted(.number.precision(.fractionLength(0)))
            )

            switch caseStudy.kind {
            case .plant:
                largeThresholdSlider(
                    title: "High-energy branch: greenness",
                    value: decisionBinding(caseStudy.id, keyPath: \.plantGreenHighThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.plantGreenHighThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Green branch: size threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.plantSizeIfGreenThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.plantSizeIfGreenThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Less-green / medium-energy branch: size threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.plantSizeIfNotGreenThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.plantSizeIfNotGreenThreshold.formatted(.number.precision(.fractionLength(2)))
                )

            case .herbivore:
                largeThresholdSlider(
                    title: "High-energy branch: speed threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.herbivoreSpeedHighEnergyThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.herbivoreSpeedHighEnergyThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Medium-energy branch: speed threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.herbivoreSpeedMediumEnergyThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.herbivoreSpeedMediumEnergyThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Fast branch: vision threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.herbivoreVisionFastThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.herbivoreVisionFastThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Medium-energy branch: visibility threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.herbivoreCamouflageSlowThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.herbivoreCamouflageSlowThreshold.formatted(.number.precision(.fractionLength(2)))
                )

            case .predator:
                largeThresholdSlider(
                    title: "High-energy branch: vision threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.predatorVisionHighEnergyThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.predatorVisionHighEnergyThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Medium-energy branch: vision threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.predatorVisionMediumEnergyThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.predatorVisionMediumEnergyThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Good-vision branch: speed threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.predatorSpeedGoodVisionThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.predatorSpeedGoodVisionThreshold.formatted(.number.precision(.fractionLength(2)))
                )

                largeThresholdSlider(
                    title: "Medium-energy branch: size threshold",
                    value: decisionBinding(caseStudy.id, keyPath: \.predatorSizePoorVisionThreshold),
                    range: 0.05...1.0,
                    valueText: caseStudy.rules.predatorSizePoorVisionThreshold.formatted(.number.precision(.fractionLength(2)))
                )
            }
        }
    }

    @ViewBuilder
    private func decisionTreeDiagram(_ caseStudy: DecisionTreeCase) -> some View {
        switch caseStudy.kind {
        case .plant:
            plantDecisionTree(caseStudy)
        case .herbivore:
            herbivoreDecisionTree(caseStudy)
        case .predator:
            predatorDecisionTree(caseStudy)
        }
    }

    private func plantDecisionTree(_ c: DecisionTreeCase) -> some View {
        VStack(spacing: 16) {
            treeNode("ROOT: Energy ≥ \(fmt(c.rules.energyLowThreshold))?", subtitle: "NO → Die | YES → next energy split")
            treeConnector("YES")
            treeNode("Energy ≥ \(fmt(c.rules.energyHighThreshold))?", subtitle: "YES and NO lead to different subtrees")

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 10) {
                    treeBranchLabel("YES — high energy")
                    treeNode("Green ≥ \(fmt(c.rules.plantGreenHighThreshold))?", subtitle: "Different size rule on each branch")
                    HStack(spacing: 12) {
                        VStack {
                            treeBranchLabel("YES")
                            treeNode("Size ≥ \(fmt(c.rules.plantSizeIfGreenThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                        VStack {
                            treeBranchLabel("NO")
                            treeNode("Size ≥ \(fmt(c.rules.plantSizeIfNotGreenThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                    }
                }

                VStack(spacing: 10) {
                    treeBranchLabel("NO — medium energy")
                    treeNode("Green ≥ \(fmt(c.rules.plantGreenHighThreshold))?", subtitle: "")
                    HStack(spacing: 12) {
                        VStack {
                            treeBranchLabel("YES")
                            treeNode("Size ≥ \(fmt(c.rules.plantSizeIfNotGreenThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                        VStack {
                            treeBranchLabel("NO")
                            treeLeaf("Die")
                        }
                    }
                }
            }
        }
    }

    private func herbivoreDecisionTree(_ c: DecisionTreeCase) -> some View {
        VStack(spacing: 16) {
            treeNode("ROOT: Energy ≥ \(fmt(c.rules.energyLowThreshold))?", subtitle: "NO → Die")
            treeConnector("YES")
            treeNode("Energy ≥ \(fmt(c.rules.energyHighThreshold))?", subtitle: "This split chooses which speed threshold applies")

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 10) {
                    treeBranchLabel("YES — high energy")
                    treeNode("Speed ≥ \(fmt(c.rules.herbivoreSpeedHighEnergyThreshold))?", subtitle: "Stricter speed split")
                    HStack(spacing: 12) {
                        VStack {
                            treeBranchLabel("YES")
                            treeNode("Vision ≥ \(fmt(c.rules.herbivoreVisionFastThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                        VStack {
                            treeBranchLabel("NO")
                            treeLeaf("Die")
                        }
                    }
                }

                VStack(spacing: 10) {
                    treeBranchLabel("NO — medium energy")
                    treeNode("Speed ≥ \(fmt(c.rules.herbivoreSpeedMediumEnergyThreshold))?", subtitle: "Different, lower speed split")
                    HStack(spacing: 12) {
                        VStack {
                            treeBranchLabel("YES")
                            treeNode("Visibility ≤ \(fmt(c.rules.herbivoreCamouflageSlowThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                        VStack {
                            treeBranchLabel("NO")
                            treeLeaf("Die")
                        }
                    }
                }
            }
        }
    }

    private func predatorDecisionTree(_ c: DecisionTreeCase) -> some View {
        VStack(spacing: 16) {
            treeNode("ROOT: Energy ≥ \(fmt(c.rules.energyLowThreshold))?", subtitle: "NO → Die")
            treeConnector("YES")
            treeNode("Energy ≥ \(fmt(c.rules.energyHighThreshold))?", subtitle: "Different vision thresholds by energy branch")

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 10) {
                    treeBranchLabel("YES — high energy")
                    treeNode("Vision ≥ \(fmt(c.rules.predatorVisionHighEnergyThreshold))?", subtitle: "")
                    HStack(spacing: 12) {
                        VStack {
                            treeBranchLabel("YES")
                            treeNode("Speed ≥ \(fmt(c.rules.predatorSpeedGoodVisionThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                        VStack {
                            treeBranchLabel("NO")
                            treeLeaf("Die")
                        }
                    }
                }

                VStack(spacing: 10) {
                    treeBranchLabel("NO — medium energy")
                    treeNode("Vision ≥ \(fmt(c.rules.predatorVisionMediumEnergyThreshold))?", subtitle: "Lower vision threshold on this branch")
                    HStack(spacing: 12) {
                        VStack {
                            treeBranchLabel("YES")
                            treeNode("Size ≥ \(fmt(c.rules.predatorSizePoorVisionThreshold))?", subtitle: "")
                            HStack { treeLeaf("Survive"); treeLeaf("Die") }
                        }
                        VStack {
                            treeBranchLabel("NO")
                            treeLeaf("Die")
                        }
                    }
                }
            }
        }
    }

    private func treeNode(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.28), lineWidth: 2)
        )
    }

    private func treeLeaf(_ title: String) -> some View {
        Text("LEAF: \(title)")
            .font(.title3.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func treeConnector(_ label: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.title3.bold())
            Image(systemName: "arrow.down")
                .font(.title2)
        }
    }

    private func treeBranchLabel(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }

    private func fmt(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value > 2 ? 0 : 2)))
    }

    private var decisionTreeResults: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Decision-tree predictions vs reality")
                .font(.largeTitle.bold())

            Text("Now we evaluate the expert system. A decision tree can be clear and interpretable, but it is only as good as the rules and thresholds chosen by the expert.")
                .font(.title3)
                .foregroundStyle(.secondary)

            if engine.decisionTreeResults.isEmpty {
                Text("No decision-tree results are available for this generation.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.decisionTreeResults) { result in
                    HStack(spacing: 22) {
                        specimenVisual(result.caseStudy.organism, label: result.caseStudy.title)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prediction: \(result.predicted.rawValue)")
                                .font(.title2.bold())
                            Text("Actual result: \(result.actual.rawValue)")
                                .font(.title2.bold())

                            Label(
                                result.wasCorrect ? "The decision tree predicted correctly" : "The decision tree was wrong",
                                systemImage: result.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                            )
                            .font(.title3.bold())
                        }

                        Spacer()
                    }
                    .padding(18)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .panelStyle()
    }

    private func decisionTreeExplanation(for caseStudy: DecisionTreeCase) -> String {
        switch caseStudy.kind {
        case .plant:
            return "For the plant, use energy, size and greenness. Greener plants produce energy more efficiently, so these are plausible expert questions."
        case .herbivore:
            return "For the herbivore, use energy, size and speed. Speed may help it reach plants or escape predators, but it also costs energy."
        case .predator:
            return "For the predator, use energy, size and vision. Larger predators can eat more prey, while better vision helps them find targets."
        }
    }

    private func decisionBinding(
        _ id: UUID,
        keyPath: WritableKeyPath<DecisionTreeRules, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                engine.decisionTreeCases.first(where: { $0.id == id })?.rules[keyPath: keyPath] ?? 0
            },
            set: { newValue in
                engine.updateDecisionTreeRules(for: id) { rules in
                    rules[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func largeThresholdSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                Text(valueText)
                    .font(.title2.monospacedDigit().bold())
            }

            Slider(value: value, in: range)
                .controlSize(.large)
        }
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
        .font(.title3)
        .padding(18)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func crossoverCard(_ example: CrossoverExample) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 18) {
                specimenVisual(example.parentA, label: "Parent A")
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundStyle(.secondary)
                specimenVisual(example.parentB, label: "Parent B")
                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundStyle(.secondary)
                specimenVisual(example.child, label: "Offspring")
            }
            .frame(maxWidth: .infinity)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 12) {
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
            .font(.title3.monospacedDigit())
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
                        .font(.title2.bold())
                    Text("\(old.formatted(.number.precision(.fractionLength(2)))) → \(new.formatted(.number.precision(.fractionLength(2))))")
                        .font(.title3.monospacedDigit().bold())
                } else {
                    Text("No mutation")
                        .font(.title2.bold())
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
                .font(.title3)
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
                        width: 52 + organism.genome.size * 44,
                        height: 52 + organism.genome.size * 44
                    )

                Text(organism.genome.kind.symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
            .frame(width: 108, height: 108)

            Text(label)
                .font(.title3.bold())

            Text(genomeSummary(organism.genome))
                .font(.title3.monospacedDigit())
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
            .controlSize(.regular)
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
            .controlSize(.regular)

            Button {
                engine.resetPopulation()
            } label: {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var statisticsPanel: some View {
        let stats = engine.stats()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Population snapshot")
                .font(.title2.bold())

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
                .font(.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.monospacedDigit().bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func conceptCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
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
