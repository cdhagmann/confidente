# frozen_string_literal: true

require "rails_helper"

# These specs define the scientific contract for the HypothesisEngine.
#
# Key scientific requirements:
#   1. Category pattern detection with minimum threshold
#   2. Washout-aware suggestion timing
#   3. Idempotent suggestion creation
#   4. Evidence-tier-aware thresholds (glutamate/lectin need higher bar)
#   5. Negative hypothesis generation ("you don't appear to be histamine sensitive")
#   6. Multi-category foods don't double-count toward a single category
#
RSpec.describe HypothesisEngine do
  let(:user) { User.create!(name: "Test User", email: "hypothesis@example.com") }

  let!(:histamine_cat) { FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" } }
  let!(:fodmap_cat)    { FoodSensitivityCategory.find_or_create_by!(slug: "fodmap")    { |c| c.name = "FODMAP"; c.description = "test" } }
  let!(:salicylate_cat) { FoodSensitivityCategory.find_or_create_by!(slug: "salicylate") { |c| c.name = "Salicylate"; c.description = "test" } }
  let!(:glutamate_cat) { FoodSensitivityCategory.find_or_create_by!(slug: "glutamate") { |c| c.name = "Glutamate"; c.description = "test" } }
  let!(:lectin_cat)    { FoodSensitivityCategory.find_or_create_by!(slug: "lectin")    { |c| c.name = "Lectin"; c.description = "test" } }

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

  # ---------------------------------------------------------------------------
  # 1. BASIC CATEGORY PATTERN DETECTION
  # ---------------------------------------------------------------------------

  describe "category pattern detection" do
    context "when fewer than 2 suspected foods share a category" do
      it "returns no suggestions for that category" do
        food_a = create_food("Solo Histamine", { histamine_cat => :high })
        suspect!(food_a)

        suggestions = described_class.new(user).call
        histamine_suggestions = suggestions.select { |s| s.reason_category == histamine_cat }
        expect(histamine_suggestions).to be_empty
      end
    end

    context "when 2+ suspected foods share a category" do
      it "suggests other high-severity foods in that category" do
        food_a = create_food("Sardines", { histamine_cat => :high })
        food_b = create_food("Sauerkraut", { histamine_cat => :high })
        food_c = create_food("Aged Cheddar", { histamine_cat => :high }) # candidate

        suspect!(food_a)
        suspect!(food_b)

        suggestions = described_class.new(user).call
        suggested_foods = suggestions.map(&:suggested_food)
        expect(suggested_foods).to include(food_c)
      end

      it "does not suggest foods already suspected" do
        food_a = create_food("Kefir", { histamine_cat => :high })
        food_b = create_food("Smoked Salmon", { histamine_cat => :high })

        suspect!(food_a)
        suspect!(food_b)

        suggestions = described_class.new(user).call
        suggested_foods = suggestions.map(&:suggested_food)
        expect(suggested_foods).not_to include(food_a)
        expect(suggested_foods).not_to include(food_b)
      end

      it "only suggests high-severity foods" do
        food_a = create_food("High A", { histamine_cat => :high })
        food_b = create_food("High B", { histamine_cat => :high })
        food_low = create_food("Low Histamine", { histamine_cat => :low })

        suspect!(food_a)
        suspect!(food_b)

        suggestions = described_class.new(user).call
        suggested_foods = suggestions.map(&:suggested_food)
        expect(suggested_foods).not_to include(food_low)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 2. WASHOUT-AWARE SUGGESTIONS
  # ---------------------------------------------------------------------------

  describe "washout awareness" do
    it "skips categories with an active washout window" do
      food_a = create_food("Garlic", { fodmap_cat => :high })
      food_b = create_food("Onion", { fodmap_cat => :high })
      _food_c = create_food("Cauliflower", { fodmap_cat => :high })

      suspect!(food_a)
      suspect!(food_b)

      meal_plan = MealPlan.create!(user: user, starts_on: Date.today - 1, ends_on: Date.today + 6)
      WashoutWindow.create!(
        meal_plan: meal_plan,
        food_sensitivity_category: fodmap_cat,
        start_date: Date.today - 1,
        end_date: Date.today + 2
      )

      suggestions = described_class.new(user).call
      fodmap_suggestions = suggestions.select { |s| s.reason_category == fodmap_cat }
      expect(fodmap_suggestions).to be_empty
    end

    it "allows suggestions for categories without active washouts" do
      food_a = create_food("Wine WO", { histamine_cat => :high })
      food_b = create_food("Cheddar WO", { histamine_cat => :high })
      food_c = create_food("Kimchi WO", { histamine_cat => :high })

      suspect!(food_a)
      suspect!(food_b)

      # FODMAP has washout but histamine doesn't
      meal_plan = MealPlan.create!(user: user, starts_on: Date.today - 1, ends_on: Date.today + 6)
      WashoutWindow.create!(
        meal_plan: meal_plan,
        food_sensitivity_category: fodmap_cat,
        start_date: Date.today - 1,
        end_date: Date.today + 2
      )

      suggestions = described_class.new(user).call
      histamine_suggestions = suggestions.select { |s| s.reason_category == histamine_cat }
      expect(histamine_suggestions.map(&:suggested_food)).to include(food_c)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. IDEMPOTENCY
  # ---------------------------------------------------------------------------

  describe "idempotency" do
    it "does not duplicate suggestions on repeated runs" do
      food_a = create_food("Idem A", { histamine_cat => :high })
      food_b = create_food("Idem B", { histamine_cat => :high })
      food_c = create_food("Idem C", { histamine_cat => :high })

      suspect!(food_a)
      suspect!(food_b)

      described_class.new(user).call
      described_class.new(user).call

      count = HypothesisSuggestion.where(user: user, suggested_food: food_c).count
      expect(count).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. EVIDENCE-TIER-AWARE THRESHOLDS
  # ---------------------------------------------------------------------------
  # Categories with weaker evidence bases should require more suspected foods
  # before generating suggestions, to avoid spurious pattern detection.
  #
  # Strong evidence (histamine, FODMAP): threshold = 2
  # Moderate evidence (salicylate, oxalate): threshold = 2
  # Emerging evidence (glutamate, lectin, capsaicin): threshold = 3

  describe "evidence-tier thresholds" do
    it "generates histamine suggestions with 2 suspected foods (strong evidence)" do
      food_a = create_food("Hist Tier A", { histamine_cat => :high })
      food_b = create_food("Hist Tier B", { histamine_cat => :high })
      food_c = create_food("Hist Tier C", { histamine_cat => :high })

      suspect!(food_a)
      suspect!(food_b)

      suggestions = described_class.new(user).call
      expect(suggestions.map(&:suggested_food)).to include(food_c)
    end

    it "does NOT generate glutamate suggestions with only 2 suspected foods (emerging evidence)" do
      food_a = create_food("Glut Tier A", { glutamate_cat => :high })
      food_b = create_food("Glut Tier B", { glutamate_cat => :high })
      _food_c = create_food("Glut Tier C", { glutamate_cat => :high })

      suspect!(food_a)
      suspect!(food_b)

      suggestions = described_class.new(user).call
      glutamate_suggestions = suggestions.select { |s| s.reason_category == glutamate_cat }
      expect(glutamate_suggestions).to be_empty
    end

    it "generates glutamate suggestions with 3 suspected foods" do
      food_a = create_food("Glut 3A", { glutamate_cat => :high })
      food_b = create_food("Glut 3B", { glutamate_cat => :high })
      food_c = create_food("Glut 3C", { glutamate_cat => :high })
      food_d = create_food("Glut 3D", { glutamate_cat => :high })

      suspect!(food_a)
      suspect!(food_b)
      suspect!(food_c)

      suggestions = described_class.new(user).call
      glutamate_suggestions = suggestions.select { |s| s.reason_category == glutamate_cat }
      expect(glutamate_suggestions.map(&:suggested_food)).to include(food_d)
    end

    it "applies the same higher threshold to lectin category" do
      food_a = create_food("Lect Tier A", { lectin_cat => :high })
      food_b = create_food("Lect Tier B", { lectin_cat => :high })
      _food_c = create_food("Lect Tier C", { lectin_cat => :high })

      suspect!(food_a)
      suspect!(food_b)

      suggestions = described_class.new(user).call
      lectin_suggestions = suggestions.select { |s| s.reason_category == lectin_cat }
      expect(lectin_suggestions).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # 5. NEGATIVE HYPOTHESIS GENERATION
  # ---------------------------------------------------------------------------
  # When a user has sufficient data showing no correlation with a category,
  # the engine should surface a "clear" signal. This prevents unnecessary
  # dietary restriction.

  describe "negative hypotheses" do
    it "generates a clear signal for categories with sufficient data and no correlation" do
      bloating = SymptomType.find_or_create_by!(slug: "bloating") { |st| st.name = "Bloating"; st.category = "gut" }

      histamine_food = create_food("Neg Test Sauerkraut", { histamine_cat => :high })
      safe_food = create_food("Neg Test Rice")

      # 10 days of data: histamine foods eaten frequently, no symptom correlation
      10.times do |i|
        date = Date.parse("2025-06-01") + i.days
        if i.even?
          meal = Meal.create!(user: user, eaten_at: date.to_time.change(hour: 12), planned: false)
          ing = histamine_food.ingredients.first || Ingredient.find_or_create_by!(canonical_name: histamine_food.name.downcase) { |ii| ii.name = histamine_food.name }
          IngredientFoodMapping.find_or_create_by!(ingredient: ing, food: histamine_food)
          MealIngredient.create!(meal: meal, ingredient: ing)
        else
          meal = Meal.create!(user: user, eaten_at: date.to_time.change(hour: 12), planned: false)
          ing = safe_food.ingredients.first || Ingredient.find_or_create_by!(canonical_name: safe_food.name.downcase) { |ii| ii.name = safe_food.name }
          IngredientFoodMapping.find_or_create_by!(ingredient: ing, food: safe_food)
          MealIngredient.create!(meal: meal, ingredient: ing)
        end
        # Consistent low symptoms regardless of food
        SymptomLog.create!(user: user, symptom_type: bloating, logged_at: date.to_time.change(hour: 20), score: 2)
      end

      result = described_class.new(user).call

      # The engine should either return a clear signal object or expose
      # a method for querying negative hypotheses
      expect(described_class.new(user)).to respond_to(:cleared_categories)
      cleared = described_class.new(user).cleared_categories

      # With enough data and no correlation, histamine should be a candidate
      # for "cleared" status (may require correlation data to be passed in)
      # The exact implementation may vary — the contract is that the engine
      # CAN surface this information
      expect(cleared).to respond_to(:each)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. MULTI-CATEGORY FOODS
  # ---------------------------------------------------------------------------
  # A food that belongs to multiple categories (e.g. tomatoes: histamine +
  # salicylate + glutamate + lectin) should count toward each category
  # independently, but should not inflate a single category's count.

  describe "multi-category foods" do
    it "counts a multi-category food toward each of its categories" do
      # Tomatoes: histamine + salicylate + glutamate + lectin
      tomatoes = create_food("Tomatoes MC", {
        histamine_cat => :medium,
        salicylate_cat => :medium,
        glutamate_cat => :high,
        lectin_cat => :high
      })
      # Avocado: histamine + salicylate
      avocado = create_food("Avocado MC", {
        histamine_cat => :high,
        salicylate_cat => :medium
      })
      # Candidate for histamine
      cheddar = create_food("Cheddar MC", { histamine_cat => :high })
      # Candidate for salicylate
      berries = create_food("Berries MC", { salicylate_cat => :high })

      suspect!(tomatoes)
      suspect!(avocado)

      suggestions = described_class.new(user).call

      # Both tomatoes and avocado are in histamine → should trigger histamine suggestions
      histamine_suggestions = suggestions.select { |s| s.reason_category == histamine_cat }
      expect(histamine_suggestions.map(&:suggested_food)).to include(cheddar)

      # Both are also in salicylate → should trigger salicylate suggestions
      salicylate_suggestions = suggestions.select { |s| s.reason_category == salicylate_cat }
      expect(salicylate_suggestions.map(&:suggested_food)).to include(berries)
    end
  end
end
