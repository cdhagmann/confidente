# Confidente

> Food sensitivity tracking powered by structured meal plans and statistical analysis.

Confidente helps people identify food sensitivities through a scientifically-informed approach — generating structured meal plans that function as controlled experiments, logging symptoms and meals (planned or not), and using statistical modeling to surface ingredient-symptom correlations.

The name combines **confidence interval** (the statistical concept) and **al dente** (the food reference). Con-fi-DEN-tay.

## Status

Pre-alpha. Active development.

## Concept

Traditional elimination diets are hard to follow and produce unreliable results because they rely on strict compliance and informal pattern recognition. Confidente treats food sensitivity testing as an experiment:

- Meal plans are generated using Latin square-inspired design to ensure controlled ingredient exposure
- "Cheats" and off-plan meals are just additional data points, not failures
- Symptom scores are weighted against daily control variables (sleep, stress, etc.)
- A hypothesis engine detects sensitivity category patterns (histamine, FODMAPs, salicylates, oxalates, etc.) and suggests additional foods to test
- Statistical modeling correlates ingredient exposure to symptom outcomes over time

## Tech Stack

- **Rails 8.1** / Ruby 3.4
- **PostgreSQL**
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS**
- **Propshaft** asset pipeline
- **Solid Queue / Solid Cache / Solid Cable** (database-backed)
- **PWA** (progressive web app) → **Hotwire Native** (planned)
- **Kamal** for deployment

## External Integrations

- **Open Food Facts** — barcode scanning and ingredient lookup
- **Spoonacular or Edamam** — recipe pool for meal plan generation
- **Apple HealthKit / Google Health Connect** — sleep, activity, and biometric data (planned)
- **Clue API** — menstrual cycle tracking as confounder (planned)

## Getting Started

```bash
bundle install
rails db:create db:migrate
bin/dev
```

Requires PostgreSQL running locally.

## Architecture

See [`docs/`](docs/) for detailed documentation:

- [`docs/concept.md`](docs/concept.md) — full product concept and methodology
- [`docs/schema.md`](docs/schema.md) — data model and schema decisions
- [`docs/integrations.md`](docs/integrations.md) — external API integrations
- [`docs/roadmap.md`](docs/roadmap.md) — MVP scope and future milestones

## License

AGPL-3.0 — free to use and modify, but commercial use as a hosted service requires open sourcing your version. See [LICENSE](LICENSE).

Copyright (C) 2025 Christopher Hagmann
