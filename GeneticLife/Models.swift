import SwiftUI

enum OrganismKind: String, CaseIterable, Codable, Hashable {
    case plant
    case herbivore
    case predator

    var title: String {
        switch self {
        case .plant: return "Plant"
        case .herbivore: return "Herbivore"
        case .predator: return "Predator"
        }
    }

    var symbol: String {
        switch self {
        case .plant: return "✿"
        case .herbivore: return "◆"
        case .predator: return "▲"
        }
    }
}

struct Genome: Identifiable, Equatable {
    let id = UUID()
    var kind: OrganismKind
    var size: Double
    var speed: Double
    var vision: Double
    var red: Double
    var green: Double
    var blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var visibility: Double {
        let redSensitivity = 1.20
        let greenSensitivity = 0.80
        let blueSensitivity = 1.00
        return ((red * redSensitivity) + (green * greenSensitivity) + (blue * blueSensitivity)) / 3.0
    }

    var photosynthesisEfficiency: Double {
        0.25 + (0.75 * green)
    }

    static func random(kind: OrganismKind) -> Genome {
        Genome(
            kind: kind,
            size: Double.random(in: 0.30...1.00),
            speed: kind == .plant ? 0 : Double.random(in: 0.25...1.00),
            vision: kind == .plant ? 0 : Double.random(in: 0.20...1.00),
            red: Double.random(in: 0.10...1.00),
            green: Double.random(in: 0.10...1.00),
            blue: Double.random(in: 0.10...1.00)
        )
    }
}

struct Organism: Identifiable, Equatable {
    let id: UUID
    var genome: Genome
    var position: CGPoint
    var velocity: CGVector
    var energy: Double
    var isAlive: Bool
    var foodEaten: Int
    var fitness: Double

    init(genome: Genome, position: CGPoint, velocity: CGVector, energy: Double = 100) {
        self.id = UUID()
        self.genome = genome
        self.position = position
        self.velocity = velocity
        self.energy = energy
        self.isAlive = true
        self.foodEaten = 0
        self.fitness = 0
    }

    var radius: CGFloat {
        CGFloat(7 + genome.size * 11)
    }
}

struct SimulationConfiguration {
    var plantCount: Int = 40
    var herbivoreCount: Int = 35
    var predatorCount: Int = 15
    var simulationDuration: Double = 10
    var mutationRate: Double = 0.08
    var minimumAnimalSurvivors: Int = 20

    var animalCount: Int {
        herbivoreCount + predatorCount
    }

    var totalPopulation: Int {
        plantCount + animalCount
    }
}

enum EvolutionStep: Int, CaseIterable {
    case initialPopulation
    case environment
    case fitness
    case selection
    case crossover
    case mutation
    case newGeneration

    var number: Int { rawValue + 1 }

    var title: String {
        switch self {
        case .initialPopulation: return "Random population"
        case .environment: return "Environment & natural selection"
        case .fitness: return "Fitness evaluation"
        case .selection: return "Parent selection"
        case .crossover: return "Crossover"
        case .mutation: return "Mutation"
        case .newGeneration: return "Next generation"
        }
    }

    var explanation: String {
        switch self {
        case .initialPopulation:
            return "Every organism starts with a random genome. Size, speed, vision and RGB colour are inherited traits. Plants cannot move or see."
        case .environment:
            return "The environment turns genes into consequences. Animals spend energy to move and see. Herbivores seek plants, predators seek prey, and prey flee visible predators."
        case .fitness:
            return "Each survivor receives a fitness score from remaining energy and food eaten. Organisms that were eaten or ran out of energy receive zero fitness."
        case .selection:
            return "Parents are sampled probabilistically. Higher fitness means a higher chance of selection, but it never guarantees selection."
        case .crossover:
            return "Each child combines genes from two selected parents. Individual traits are copied independently, so a child becomes a new mixture."
        case .mutation:
            return "A small random mutation may alter inherited genes. Mutation introduces variation that selection can act on in later generations."
        case .newGeneration:
            return "The offspring replace the previous animals. Plants are also reproduced from successful plants, and the environment starts again with inherited traits."
        }
    }
}

struct GeneComparison: Identifiable {
    let id = UUID()
    let name: String
    let parentA: Double
    let child: Double
    let parentB: Double
    let inheritedFromA: Bool
}

struct CrossoverExample: Identifiable {
    let id = UUID()
    let parentA: Organism
    let parentB: Organism
    let child: Organism
    let inheritedFromA: [String]
}

struct MutationExample: Identifiable {
    let id = UUID()
    let before: Organism
    let after: Organism
    let gene: String?
    let oldValue: Double?
    let newValue: Double?

    var didMutate: Bool { gene != nil }
}

struct GenerationStatistics {
    var averageSize: Double = 0
    var averageSpeed: Double = 0
    var averageVision: Double = 0
    var averageGreen: Double = 0
    var livingPlants: Int = 0
    var livingHerbivores: Int = 0
    var livingPredators: Int = 0
}


enum DecisionOutcome: String, CaseIterable, Identifiable {
    case survive = "Survive"
    case die = "Die"

    var id: String { rawValue }
}

struct DecisionTreeRules {
    var energyThreshold: Double = 70
    var sizeThreshold: Double = 0.50
    var traitThreshold: Double = 0.50
    var requireGreen: Bool = true
    var predictedOutcome: DecisionOutcome = .survive
}

struct DecisionTreeCase: Identifiable {
    let id = UUID()
    let organismID: UUID
    let kind: OrganismKind
    let organism: Organism
    var rules: DecisionTreeRules

    var title: String {
        "\(kind.symbol) \(kind.title)"
    }
}

struct DecisionTreeResult: Identifiable {
    let id = UUID()
    let caseStudy: DecisionTreeCase
    let predicted: DecisionOutcome
    let actual: DecisionOutcome

    var wasCorrect: Bool {
        predicted == actual
    }
}
