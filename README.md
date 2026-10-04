# Genetic Life

A small SwiftUI teaching app that explains a genetic algorithm through an animated ecosystem.

## Run

1. Open `GeneticLife.xcodeproj` in Xcode 16 or newer.
2. Select an iOS 17+ simulator or device.
3. Run the `GeneticLife` target.

## Genetic algorithm lesson

Each generation is presented as seven explicit steps:

1. Random population
2. Environment and natural selection
3. Fitness evaluation
4. Parent selection
5. Crossover
6. Mutation
7. New generation

The app pauses between genetic-algorithm steps so the current operation can be inspected. The environment step is animated for a configurable number of seconds and can finish early when the animal population falls below a configurable threshold.

## Genome

Animals and plants inherit:

- size
- RGB colour
- speed (animals only)
- vision distance (animals only)

Roles are visually marked inside each organism:

- ✿ plant
- ◆ herbivore
- ▲ predator

Greener plants produce more energy. Animal colour influences how easily it can be detected. Larger vision ranges improve detection but consume more energy. Movement speed and size also carry energy costs.

The project intentionally keeps the ecosystem rules simple. Its primary goal is to make selection, crossover and mutation visible and understandable rather than to model a biologically realistic ecosystem.
