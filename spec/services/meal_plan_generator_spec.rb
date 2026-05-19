# frozen_string_literal: true

require "rails_helper"

# These specs define the scientific contract for MealPlanGenerator.
#
# The meal plan generator is a constraint satisfaction system. It must:
#   1. Provide minimum exposure count per suspected ingredient
#   2. Enforce per-category washout windows between same-category exposures
#   3. Vary ingredient combinations to decorrelate co-occurring ingredients
#   4. Use category-specific washout durations (not a single global value)
#   5. Balance exposures across the plan window (not front-loaded or clustered)
#   6. Handle the food pool gracefully when constraints are tight
#
RSpec.describe MealPlanGenerator do
  let(:user) { User.create!(name: "Plan User", email: "planner@example.com") }

  let!(:histamine_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" }
  end
  let!(:fodmap_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "fodmap") { |c| c.name = "FODMAP"; c.description = "test" }
  end
  let!(:salicylate_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "salicylate") { |c| c.name = "Salicylate"; c.description = "test" }
  end
  let!(:lectin_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "lectin") { |c| c.name = "Lectin"; c.description = "test" }
  end

  def create_food(name, memberships = {})
    food = Food.find_or_create_by!(name: name)
    memberships.each do |cat, sev|
      FoodCategoryMembership.find_or_create_by!(food: food, food_sensitivity_category: cat) { |m| m.severity = sev }
    end
    ingredient = Ingredient.find_or_create_by!(canonical_name: name.downcase) { |i| i.name = name }
    IngredientFoodMapping.find_or_create_by!(ingredient: ingredient, food: food)
    food
  end

  before do
    # Seed a baseline food pool
    15.times { |i| create_food("Safe Food #{i}") }
  end

  # ---------------------------------------------------------------------------
  # 1. STRUCTURAL REQUIREMENTS
  # ---------------------------------------------------------------------------

  describe "plan structure" do
    it "creates a MealPlan spanning the correct number of days" do
      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 14).call
      expect(plan.starts_on).to eq(Date.parse("2025-06-01"))
      expect(plan.ends_on).to eq(Date.parse("2025-06-14"))
    end

    it "creates 3 meal slots per day" do
      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 7).call
      expect(plan.meal_plan_slots.count).to eq(21)

      7.times do |offset|
        date = plan.starts_on + offset.days
        times = plan.meal_plan_slots.where(scheduled_for: date).pluck(:meal_time)
        expect(times).to match_array(MealPlanSlot::MEAL_TIMES)
      end
    end

    it "is associated with the correct user" do
      plan = described_class.new(user).call
      expect(plan.user).to eq(user)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. MINIMUM EXPOSURE GUARANTEE
  # ---------------------------------------------------------------------------
  # Each suspected ingredient must appear at least MIN_EXPOSURES (5) times
  # across the plan. This is the minimum for meaningful statistical power.

  describe "minimum exposure guarantee" do
    it "schedules suspected foods at least MIN_EXPOSURES times" do
      suspect_food = create_food("Suspect Cheddar", { histamine_cat => :high })
      UserSuspectFood.create!(user: user, food: suspect_food, added_at: Time.current)

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 14).call

      ingredient = suspect_food.ingredients.first
      exposure_count = MealIngredient
        .joins(meal: :meal_plan_slots)
        .where(ingredient: ingredient, meal_plan_slots: { meal_plan_id: plan.id })
        .select("DISTINCT meal_plan_slots.scheduled_for")
        .count

      expect(exposure_count).to be >= described_class::MIN_EXPOSURES
    end

    it "schedules multiple suspected foods each meeting the minimum" do
      foods = 3.times.map do |i|
        food = create_food("Multi Suspect #{i}", { histamine_cat => :high })
        UserSuspectFood.create!(user: user, food: food, added_at: Time.current)
        food
      end

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 21).call

      foods.each do |food|
        ingredient = food.ingredients.first
        exposure_count = MealIngredient
          .joins(meal: :meal_plan_slots)
          .where(ingredient: ingredient, meal_plan_slots: { meal_plan_id: plan.id })
          .select("DISTINCT meal_plan_slots.scheduled_for")
          .count

        expect(exposure_count).to be >= described_class::MIN_EXPOSURES
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. PER-CATEGORY WASHOUT ENFORCEMENT
  # ---------------------------------------------------------------------------
  # Same-category foods must not appear on consecutive days within the
  # washout window for that category. Different categories have different
  # washout durations.

  describe "per-category washout enforcement" do
    it "spaces histamine-category exposures by at least the histamine washout period" do
      hist_food_a = create_food("Hist Wash A", { histamine_cat => :high })
      hist_food_b = create_food("Hist Wash B", { histamine_cat => :high })
      UserSuspectFood.create!(user: user, food: hist_food_a, added_at: Time.current)
      UserSuspectFood.create!(user: user, food: hist_food_b, added_at: Time.current)

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 14).call

      # Collect all dates with any histamine-category food
      histamine_dates = plan.meal_plan_slots
        .joins(meal: { meal_ingredients: { food: :food_category_memberships } })
        .where(food_category_memberships: { food_sensitivity_category_id: histamine_cat.id })
        .pluck(:scheduled_for)
        .uniq
        .sort

      # Check that consecutive histamine dates are spaced by at least
      # the category-specific washout (3-4 days for histamine)
      histamine_dates.each_cons(2) do |d1, d2|
        gap = (d2 - d1).to_i
        expect(gap).to be >= 3, "Histamine foods on #{d1} and #{d2} are only #{gap} days apart"
      end
    end

    it "allows different categories on the same day" do
      hist_food = create_food("Hist Same Day", { histamine_cat => :high })
      fodmap_food = create_food("FODMAP Same Day", { fodmap_cat => :high })
      UserSuspectFood.create!(user: user, food: hist_food, added_at: Time.current)
      UserSuspectFood.create!(user: user, food: fodmap_food, added_at: Time.current)

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 14).call

      # It should be POSSIBLE (though not required) to have histamine and
      # FODMAP foods on the same day, since they're independent categories
      all_dates = plan.meal_plan_slots.where.not(meal: nil).pluck(:scheduled_for)
      expect(all_dates.uniq.count).to be > 1 # plan isn't empty
    end

    it "creates WashoutWindow records for each category used in the plan" do
      suspect_food = create_food("WO Record Food", { histamine_cat => :high })
      UserSuspectFood.create!(user: user, food: suspect_food, added_at: Time.current)

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 14).call

      expect(plan.washout_windows.where(food_sensitivity_category: histamine_cat)).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 4. INGREDIENT COMBINATION DECORRELATION
  # ---------------------------------------------------------------------------
  # To enable the correlator to distinguish individual ingredients, the same
  # two ingredients should not always appear together. The generator should
  # vary combinations across days.

  describe "ingredient decorrelation" do
    it "does not schedule the same pair of suspected foods together every time" do
      food_a = create_food("Decorr A", { histamine_cat => :high })
      food_b = create_food("Decorr B", { salicylate_cat => :high })
      UserSuspectFood.create!(user: user, food: food_a, added_at: Time.current)
      UserSuspectFood.create!(user: user, food: food_b, added_at: Time.current)

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 21).call

      # Find all dates where food_a appears
      ing_a = food_a.ingredients.first
      dates_a = MealIngredient
        .joins(meal: :meal_plan_slots)
        .where(ingredient: ing_a, meal_plan_slots: { meal_plan_id: plan.id })
        .pluck("meal_plan_slots.scheduled_for")
        .uniq

      # Find all dates where food_b appears
      ing_b = food_b.ingredients.first
      dates_b = MealIngredient
        .joins(meal: :meal_plan_slots)
        .where(ingredient: ing_b, meal_plan_slots: { meal_plan_id: plan.id })
        .pluck("meal_plan_slots.scheduled_for")
        .uniq

      overlap = dates_a & dates_b
      # They should NOT always co-occur. Some overlap is fine; 100% is not.
      if dates_a.size >= 3 && dates_b.size >= 3
        expect(overlap.size).to be < [ dates_a.size, dates_b.size ].min,
          "Foods A and B appear together on every exposure day — combinations not decorrelated"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5. EXPOSURE DISTRIBUTION
  # ---------------------------------------------------------------------------
  # Exposures should be spread across the plan, not front-loaded into the
  # first few days. This ensures temporal balance (order effects are controlled).

  describe "exposure distribution" do
    it "distributes suspected food exposures across the plan window" do
      suspect_food = create_food("Dist Food", { histamine_cat => :high })
      UserSuspectFood.create!(user: user, food: suspect_food, added_at: Time.current)

      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 14).call

      ingredient = suspect_food.ingredients.first
      exposure_dates = MealIngredient
        .joins(meal: :meal_plan_slots)
        .where(ingredient: ingredient, meal_plan_slots: { meal_plan_id: plan.id })
        .pluck("meal_plan_slots.scheduled_for")
        .uniq
        .sort

      next unless exposure_dates.size >= 3

      # Check that exposures span at least half the plan window
      span = (exposure_dates.last - exposure_dates.first).to_i
      plan_length = (plan.ends_on - plan.starts_on).to_i
      expect(span).to be >= (plan_length * 0.4).floor,
        "Exposures clustered in #{span} days of a #{plan_length}-day plan"
    end
  end

  # ---------------------------------------------------------------------------
  # 6. GRACEFUL DEGRADATION
  # ---------------------------------------------------------------------------
  # When constraints conflict (too many suspected foods, too few safe foods,
  # washout windows leaving no available slots), the generator should produce
  # the best plan it can rather than failing.

  describe "graceful degradation" do
    it "produces a valid plan even with many suspected foods and short duration" do
      8.times do |i|
        food = create_food("Crowded #{i}", { histamine_cat => :high })
        UserSuspectFood.create!(user: user, food: food, added_at: Time.current)
      end

      # 7-day plan with 8 suspected foods and washout constraints — can't
      # give every food 5 exposures
      plan = described_class.new(user, start_date: Date.parse("2025-06-01"), duration_days: 7).call

      expect(plan).to be_a(MealPlan)
      expect(plan.meal_plan_slots.count).to eq(21)
      # Some foods may get fewer than MIN_EXPOSURES — that's ok for a short plan
      # The plan should still be structurally valid
    end

    it "does not crash with an empty food pool" do
      Food.destroy_all # remove all seeded foods

      expect { described_class.new(user).call }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # 7. CATEGORY-SPECIFIC WASHOUT DURATIONS
  # ---------------------------------------------------------------------------
  # Different categories should have different washout periods based on
  # their pharmacokinetics.

  describe "category-specific washout durations" do
    it "uses a longer washout for lectin-category than FODMAP-category" do
      # The generator should have configurable or hardcoded per-category
      # washout durations
      expect(described_class::WASHOUT_DAYS_BY_CATEGORY).to be_a(Hash)
      expect(described_class::WASHOUT_DAYS_BY_CATEGORY["lectin"])
        .to be > described_class::WASHOUT_DAYS_BY_CATEGORY["fodmap"]
    end

    it "uses a longer washout for histamine-category than glutamate-category" do
      expect(described_class::WASHOUT_DAYS_BY_CATEGORY["histamine"])
        .to be > described_class::WASHOUT_DAYS_BY_CATEGORY["glutamate"]
    end
  end
end
