require "rails_helper"

RSpec.describe SymptomCorrelator do
  let(:user) { User.create!(name: "Test User", email: "correlator@example.com") }
  let(:histamine) { FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" } }
  let(:symptom_type) { SymptomType.find_or_create_by!(slug: "bloating") { |st| st.name = "Bloating"; st.category = "gut" } }
  let(:ingredient_a) { Ingredient.create!(name: "Avocado", canonical_name: "avocado") }
  let(:ingredient_b) { Ingredient.create!(name: "Spinach", canonical_name: "spinach") }

  def log_meal_on(date, *ingredients)
    meal = Meal.create!(user: user, eaten_at: date.to_time.change(hour: 12), planned: false)
    ingredients.each do |ing|
      MealIngredient.create!(meal: meal, ingredient: ing)
    end
    meal
  end

  def log_symptom_on(date, score)
    SymptomLog.create!(user: user, symptom_type: symptom_type, logged_at: date.to_time.change(hour: 20), score: score)
  end

  describe "#call" do
    it "returns an empty hash when there are no meals" do
      result = described_class.new(user, start_date: 7.days.ago.to_date, end_date: Date.today).call
      expect(result).to be_empty
    end

    it "returns ingredient scores sorted by correlation descending" do
      today = Date.today
      yesterday = today - 1

      # ingredient_a appears on a high-symptom day
      log_meal_on(today, ingredient_a)
      log_symptom_on(today, 5)

      # ingredient_b appears on a low-symptom day
      log_meal_on(yesterday, ingredient_b)
      log_symptom_on(yesterday, 1)

      result = described_class.new(user, start_date: yesterday, end_date: today).call
      expect(result.keys.first).to eq(ingredient_a.id)
      expect(result[ingredient_a.id][:score]).to be > result[ingredient_b.id][:score]
    end

    it "tracks exposure_days count per ingredient" do
      today = Date.today
      yesterday = today - 1
      log_meal_on(today, ingredient_a)
      log_meal_on(yesterday, ingredient_a)
      log_symptom_on(today, 3)
      log_symptom_on(yesterday, 3)

      result = described_class.new(user, start_date: yesterday, end_date: today).call
      expect(result[ingredient_a.id][:exposure_days]).to eq(2)
    end

    it "uses a default quality weight of 0.5 when no daily_control exists" do
      today = Date.today
      log_meal_on(today, ingredient_a)
      log_symptom_on(today, 4)

      result = described_class.new(user, start_date: today, end_date: today).call
      # score should equal symptom_avg (4.0) since quality is 0.5 / 0.5 = 1.0 ratio
      expect(result[ingredient_a.id][:score]).to be_within(0.01).of(4.0)
    end
  end
end
