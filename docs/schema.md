# Data Model

## Overview

The schema has four main concerns:
1. **Food knowledge graph** — ingredients, foods, sensitivity categories
2. **Experiment design** — meal plans, washout windows, slots
3. **Logging** — meals eaten, symptoms, daily controls
4. **Hypothesis engine** — suspected foods, suggestions, integrations

## Schema

### Food Knowledge Graph

```ruby
foods
  id, name, open_food_facts_id, barcode

food_sensitivity_categories
  id, name, slug
  # histamine, fodmap, salicylate, oxalate, lectin, glutamate, capsaicin

food_category_memberships
  food_id, sensitivity_category_id, severity (low/medium/high)

ingredients
  id, name, canonical_name
  # canonical_name handles normalization — "whole milk", "milk", "full fat milk" → "milk"

ingredient_food_mappings
  ingredient_id, food_id
```

### Users & Suspected Foods

```ruby
users
  id, ...

user_suspect_foods
  user_id, food_id, added_at
```

### Meal Plans & Scheduling

```ruby
meal_plans
  id, user_id, starts_on, ends_on

meal_plan_slots
  id, meal_plan_id, scheduled_for, meal_id (nullable)
  # meal_id null = slot planned but recipe not yet assigned

washout_windows
  id, meal_plan_id, sensitivity_category_id, start_date, end_date
  # active washout periods per category — hypothesis engine checks before suggesting

meals
  id, user_id, eaten_at, planned (bool), notes

meal_ingredients
  meal_id, ingredient_id, food_id (nullable)
  # food_id present if scanned via barcode; ingredient_id if manual entry
```

### Symptom & Control Logging

```ruby
symptom_types
  id, name, slug
  # bloating, headache, fatigue, skin_reaction, brain_fog, etc.

symptom_logs
  id, user_id, logged_at, score (1-5), symptom_type_id, notes

daily_controls
  id, user_id, date
  sleep_hours (decimal)
  sleep_quality (1-5)
  stress_level (1-5)
  exercise_intensity (none/light/moderate/intense)
  notes

daily_control_flags
  id, daily_control_id, flag_type, value
  # extensible: menstrual_phase, illness, medication, alcohol
  # kept separate to avoid adding columns for each new confounder type
```

### Hypothesis Engine

```ruby
hypothesis_suggestions
  id, user_id, suggested_food_id, reason_category_id, status (pending/accepted/rejected)
  # "we noticed A, B, C are all high histamine — want to test D?"
  # only surfaced after active washout window for that category has cleared
```

### External Integrations

```ruby
connected_integrations
  id, user_id, provider (apple_health/google_fit/cronometer/clue/etc)
  access_token, refresh_token, scopes, last_synced_at

integration_sync_logs
  id, connected_integration_id, synced_at, records_imported, status
```

### Lab Results (future)

```ruby
lab_results
  id, user_id, collected_at, provider

lab_result_markers
  id, lab_result_id, marker_name, value, unit
  reference_range_low, reference_range_high, flag (normal/low/high)
  sensitivity_category_id (nullable)
  # links a lab marker directly to the sensitivity category graph
  # e.g. DAO result → histamine category
```

## Key Design Decisions

**Ingredient normalization** — Open Food Facts returns inconsistent ingredient names. `canonical_name` on the ingredients table handles this at ingest time. Worth investing in early.

**`daily_control_flags`** — kept as a separate extensible table rather than columns on `daily_controls`. Users can opt into tracking menstrual cycle, medications, etc. without schema changes.

**`meal_plan_slots` with nullable `meal_id`** — separates the scheduling skeleton from the actual recipe assignment. Slots can exist before recipes are chosen, which is how the Latin square scheduling works.

**`washout_windows` as first-class records** — the hypothesis engine queries these directly before surfacing suggestions. Keeps the logic clean.

**Symptom types as a table** — allows user-defined symptoms eventually, and enables category-level correlation analysis (histamine → systemic symptoms like skin/head vs FODMAPs → gut symptoms).
