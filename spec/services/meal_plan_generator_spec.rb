require "rails_helper"

RSpec.describe MealPlanGenerator do
  let(:user) { User.create!(name: "Test User", email: "planner@example.com") }
  let!(:histamine) { FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" } }

  def create_food_with_ingredient(name, memberships = [])
    food = Food.find_or_create_by!(name: name)
    memberships.each do |cat, sev|
      FoodCategoryMembership.find_or_create_by!(food: food, food_sensitivity_category: cat) { |m| m.severity = sev }
    end
    ingredient = Ingredient.find_or_create_by!(canonical_name: name.downcase) { |i| i.name = name }
    IngredientFoodMapping.find_or_create_by!(ingredient: ingredient, food: food)
    food
  end

  before do
    # Create a small food pool so the generator has something to work with
    10.times { |i| create_food_with_ingredient("Test Food #{i}", [[histamine, :low]]) }
  end

  describe "#call" do
    it "creates a MealPlan spanning 7 days" do
      start_date = Date.today
      plan = described_class.new(user, start_date: start_date).call

      expect(plan).to be_a(MealPlan)
      expect(plan.starts_on).to eq(start_date)
      expect(plan.ends_on).to eq(start_date + 6.days)
    end

    it "creates 21 meal plan slots (7 days × 3 meal times)" do
      plan = described_class.new(user).call
      expect(plan.meal_plan_slots.count).to eq(21)
    end

    it "creates slots for all three meal times each day" do
      plan = described_class.new(user).call
      7.times do |offset|
        date = plan.starts_on + offset.days
        times = plan.meal_plan_slots.where(scheduled_for: date).pluck(:meal_time)
        expect(times).to match_array(MealPlanSlot::MEAL_TIMES)
      end
    end

    it "ensures suspected foods appear at least MIN_EXPOSURES times" do
      suspect_food = create_food_with_ingredient("Suspect Food", [[histamine, :high]])
      UserSuspectFood.create!(user: user, food: suspect_food, added_at: Time.current)

      plan = described_class.new(user).call

      ingredient = suspect_food.ingredients.first
      exposure_count = MealIngredient
        .joins(meal: :meal_plan_slots)
        .where(ingredient: ingredient, meals: { user_id: user.id })
        .where(meal_plan_slots: { meal_plan_id: plan.id })
        .count

      expect(exposure_count).to be >= MealPlanGenerator::MIN_EXPOSURES
    end

    it "creates washout windows for categories in the plan" do
      plan = described_class.new(user).call
      # At minimum the histamine category should get a washout window if any histamine food was assigned
      expect(plan.washout_windows).to be_present
    end

    it "is associated with the correct user" do
      plan = described_class.new(user).call
      expect(plan.user).to eq(user)
    end
  end
end
