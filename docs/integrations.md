# External Integrations

## Food Data

### Open Food Facts
- **Purpose:** Barcode scanning → ingredient lookup
- **Cost:** Free, open license (ODbL)
- **Endpoint:** `GET world.openfoodfacts.org/api/v2/product/{barcode}`
- **Returns:** Product name, ingredient list, allergens, normalized ingredients
- **Rate limit:** Per-user for mobile apps — scales fine
- **Limitation:** Community-contributed data; coverage better for packaged goods than fresh items. Manual entry fallback required.
- **Notes:** Ingredient normalization needed on ingest — OFF returns inconsistent naming

### Spoonacular / Edamam
- **Purpose:** Recipe pool for meal plan generation
- **Cost:** Free tiers available; ~$10-50/mo at scale
- **Use:** Filter recipes by allowed ingredients → feed into meal plan scheduler
- **Notes:** Neither API supports elimination diet experimental design. Recipe sourcing only — the scheduling and sequencing logic is built in-app.

## Meal Plan Generation

Meal plan scheduling (Latin square-inspired design, washout window enforcement, ingredient exposure balancing) is **built in-app**. This is core IP and is not outsourced.

## Health & Biometrics

### Apple HealthKit
- **Purpose:** Sleep duration, sleep quality, resting heart rate, HRV, exercise sessions → auto-populate `daily_controls`
- **Access:** Requires iOS app — HealthKit is not available via web
- **Implication:** Prioritize Hotwire Native for iOS sooner than originally planned if HealthKit data is a priority
- **Status:** Planned

### Google Health Connect
- **Purpose:** Same as HealthKit for Android
- **Access:** Android SDK; limited REST API in some contexts
- **Status:** Planned

### Clue API
- **Purpose:** Menstrual cycle phase tracking → significant histamine interaction (estrogen upregulates histamine)
- **Status:** Planned

## Symptom & Cycle Tracking

### Cronometer (potential)
- **Purpose:** Import existing meal logs for users who already track food
- **Notes:** Popular with the food sensitivity crowd; good ingredient data
- **Status:** Under investigation

## Integration Architecture

All integrations write into the same `daily_controls` and `meals` tables as manual entry — they're just another write path. The `connected_integrations` table tracks OAuth tokens, scopes, and sync state per provider.

Background jobs handle polling and webhook processing. Solid Queue (already in the stack) handles this.

```
External sources          App tables
─────────────────         ──────────────────
Apple Health        →     daily_controls (sleep, activity)
Google Health       →     daily_controls (sleep, activity)
Open Food Facts     →     ingredients, foods
Spoonacular/Edamam  →     meal_plan_slots (recipe pool)
Clue                →     daily_control_flags (menstrual_phase)
Cronometer          →     meals, meal_ingredients
```

## Future: Lab Integration

At-home biomarker testing (DAO enzyme, IgG food antibodies, oxalate markers, calprotectin) via companies like Vibrant America or Genova.

Lab results feed into `lab_result_markers` with a `sensitivity_category_id` join — directly influencing hypothesis engine confidence.

Requires: HIPAA compliance, HL7/FHIR data standards, lab partner agreements. **Explicitly out of scope for MVP.**
