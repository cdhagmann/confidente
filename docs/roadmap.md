# Roadmap

## MVP (v0.1)

The goal of the MVP is to validate the core loop: onboarding → meal plan → logging → basic signal.

**Scope:**
- User onboarding — collect suspected foods and baseline symptoms
- Ingredient and food database (Open Food Facts integration)
- Meal plan generation — weekly plan with basic ingredient scheduling
- Meal logging — planned meals (tap to confirm) and off-plan meals (barcode scan or manual)
- Symptom logging — daily score per symptom type
- Daily controls — manual entry for sleep and stress
- Basic dashboard — ingredient exposure vs symptom score over time

**Out of scope for MVP:**
- Hypothesis engine (v0.2)
- Statistical modeling beyond simple correlation display (v0.2)
- HealthKit / Google Health Connect (v0.3)
- Hotwire Native (v0.3)
- Lab integration (future)

**Success criteria:** A user can complete onboarding, follow a one-week meal plan, log meals and symptoms daily, and see a basic report at the end.

---

## v0.2 — Hypothesis Engine + Stats

- Sensitivity category graph populated with seed data
- Hypothesis engine: detect category patterns in suspected foods, suggest additional test foods
- Washout window enforcement in meal plan generation
- Confounder weighting: adjust symptom scores based on daily control quality
- Improved dashboard with ingredient-level signal indicators

---

## v0.3 — Integrations + Native

- Apple HealthKit integration (sleep, activity → daily_controls)
- Google Health Connect integration
- Hotwire Native shell for iOS and Android
- Push notifications for meal reminders and daily check-in
- Clue API integration (menstrual cycle phase)

---

## v0.4 — Scale + Community

- Multi-user aggregate data (opt-in)
- Population-level hypothesis validation — does X pattern hold across users?
- Cronometer import for existing food trackers
- Improved statistical modeling (mixed effects)

---

## Future (no timeline)

- Lab integration (DAO, IgG, oxalate markers)
- Dietitian/practitioner portal
- Dual licensing for commercial use
- Monetization TBD

---

## Explicitly Out of Scope (forever)

- Diagnosing medical conditions
- Replacing professional medical advice
- Strict elimination diet enforcement (compliance is not the goal)
