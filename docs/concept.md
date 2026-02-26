# Concept

## The Problem

Traditional elimination diets have poor completion rates and unreliable results. They require strict compliance, rely on informal pattern recognition, and can't distinguish food reactions from confounders like poor sleep or high stress. A "cheat" invalidates the experiment. Results are subjective and hard to act on.

## The Approach

Confidente treats food sensitivity testing as a structured experiment. The core insight is that **compliance is not the goal — logging is**. Off-plan meals are additional data points, not failures.

### Meal Plans as Experimental Design

Meal plans are generated using Latin square-inspired scheduling to ensure:
- Each target ingredient appears multiple times across the test period
- Adequate washout windows between exposures to the same ingredient
- Controlled introduction of new ingredients based on hypothesis suggestions

### The Hypothesis Engine

When a user flags multiple foods as suspected triggers, Confidente checks whether they share a sensitivity category. If A, B, and C are all high-histamine foods, the engine suggests adding D (another high-histamine food) to the test plan — but delays it until after the current washout window.

### Sensitivity Categories

Foods are tagged with one or more sensitivity categories with severity levels:

| Category | Notes |
|---|---|
| **Histamine** | Fermented foods, aged cheeses, leftovers, alcohol |
| **FODMAPs** | Fermentable carbohydrates — onion, garlic, wheat, legumes |
| **Salicylates** | Many fruits, vegetables, spices — often missed because foods seem "healthy" |
| **Oxalates** | Spinach, nuts, chocolate, beets — common in "clean eating" |
| **Lectins** | Beans, grains, nightshades — relevant for autoimmune presentations |
| **Glutamates** | Tomatoes, parmesan, soy sauce, mushrooms — neurological symptoms |
| **Capsaicin** | All peppers including bell peppers — gut motility trigger |

Foods can belong to multiple categories (e.g. avocado is both high-histamine and high-salicylate).

### Confounder Controls

Daily control variables are tracked to weight symptom scores:

- Sleep quality and duration (auto-populated via Apple HealthKit / Google Health Connect)
- Stress level
- Exercise intensity
- Menstrual cycle phase (significant histamine interaction)
- Illness / medications

High-stress or poor-sleep days discount food signal — the data isn't discarded, it's held more loosely by the model.

### Statistical Layer

The model starts simple — regression of symptom scores against ingredient exposure frequency, weighted by daily control quality scores. Mixed effects modeling is the target once data volume warrants it.

The statistical logic is abstracted behind service objects so the underlying implementation can be upgraded without changing the interface.

## User Experience Philosophy

The science is the engine. Users never see it. The UI exposes:

- Simple onboarding: "what do you suspect is causing problems?"
- Meal plan presented as a weekly view — tap to log, tap to swap
- "I ate something else" → barcode scan or ingredient search
- Daily check-in: quick symptom score + control variables (pre-populated from HealthKit where possible)
- Dashboard: "You seem to react to X" with a plain-language confidence indicator

## Future: Lab Integration

At-home finger-prick tests (DAO enzyme levels, IgG food antibodies, oxalate markers, gut inflammation) could close the loop between behavioral inference and biochemistry. Lab results would feed directly into the sensitivity category graph to boost or suppress hypothesis confidence.

This is explicitly out of scope for MVP but the schema is designed to accommodate it.
