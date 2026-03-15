require "rails_helper"

RSpec.describe HypothesisEngine do
  let(:user) { User.create!(name: "Test User", email: "hypothesis@example.com") }

  let!(:histamine) { FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" } }
  let!(:fodmap)    { FoodSensitivityCategory.find_or_create_by!(slug: "fodmap")    { |c| c.name = "FODMAP"; c.description = "test" } }

  def create_food(name, memberships)
    food = Food.find_or_create_by!(name: name)
    memberships.each do |cat, sev|
      FoodCategoryMembership.find_or_create_by!(food: food, food_sensitivity_category: cat) { |m| m.severity = sev }
    end
    food
  end

  def suspect!(food)
    UserSuspectFood.create!(user: user, food: food, added_at: Time.current)
  end

  describe "#call" do
    context "when fewer than 2 suspected foods share a category" do
      it "returns no suggestions" do
        food_a = create_food("Red Wine Test", [[histamine, :high]])
        suspect!(food_a)

        suggestions = described_class.new(user).call
        expect(suggestions).to be_empty
      end
    end

    context "when 2+ suspected foods share a category" do
      it "creates suggestions for other high-severity foods in that category" do
        food_a = create_food("Sardines Test", [[histamine, :high]])
        food_b = create_food("Sauerkraut Test", [[histamine, :high]])
        food_c = create_food("Aged Cheddar Test", [[histamine, :high]])  # not suspected — should be suggested

        suspect!(food_a)
        suspect!(food_b)

        suggestions = described_class.new(user).call
        suggested_foods = suggestions.map(&:suggested_food)
        expect(suggested_foods).to include(food_c)
      end

      it "does not suggest foods already suspected" do
        food_a = create_food("Kefir Test", [[histamine, :high]])
        food_b = create_food("Smoked Salmon Test", [[histamine, :high]])

        suspect!(food_a)
        suspect!(food_b)

        suggestions = described_class.new(user).call
        suggested_foods = suggestions.map(&:suggested_food)
        expect(suggested_foods).not_to include(food_a)
        expect(suggested_foods).not_to include(food_b)
      end

      it "only suggests high-severity foods" do
        food_a = create_food("High A", [[histamine, :high]])
        food_b = create_food("High B", [[histamine, :high]])
        food_low = create_food("Low Histamine Food", [[histamine, :low]])

        suspect!(food_a)
        suspect!(food_b)

        suggestions = described_class.new(user).call
        suggested_foods = suggestions.map(&:suggested_food)
        expect(suggested_foods).not_to include(food_low)
      end

      it "skips categories with an active washout window" do
        food_a = create_food("Garlic Test", [[fodmap, :high]])
        food_b = create_food("Onion Test", [[fodmap, :high]])
        food_c = create_food("Cauliflower Test", [[fodmap, :high]])

        suspect!(food_a)
        suspect!(food_b)

        meal_plan = MealPlan.create!(user: user, starts_on: Date.today - 1, ends_on: Date.today + 6)
        WashoutWindow.create!(
          meal_plan: meal_plan,
          food_sensitivity_category: fodmap,
          start_date: Date.today - 1,
          end_date: Date.today + 2
        )

        suggestions = described_class.new(user).call
        expect(suggestions).to be_empty
      end

      it "is idempotent — does not duplicate suggestions" do
        food_a = create_food("Idem A", [[histamine, :high]])
        food_b = create_food("Idem B", [[histamine, :high]])
        food_c = create_food("Idem C", [[histamine, :high]])

        suspect!(food_a)
        suspect!(food_b)

        described_class.new(user).call
        described_class.new(user).call

        count = HypothesisSuggestion.where(user: user, suggested_food: food_c).count
        expect(count).to eq(1)
      end
    end
  end
end
