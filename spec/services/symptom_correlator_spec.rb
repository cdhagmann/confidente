# frozen_string_literal: true

require "rails_helper"

# These specs define the scientific contract for the SymptomCorrelator.
# The correlator is the core statistical engine: given a user's meals,
# symptoms, and daily controls over a date range, it produces per-ingredient
# correlation scores that reflect how strongly each ingredient is associated
# with symptom outcomes.
#
# Key scientific requirements:
#   1. 24-hour trailing attribution window (not day-boundary)
#   2. Time-decay weighting within the window
#   3. Per-category quality weighting (not global)
#   4. Benjamini-Hochberg FDR correction for multiple comparisons
#   5. Minimum exposure threshold before reporting results
#   6. Weighted correlation (quality weights observations, not scores)
#
RSpec.describe SymptomCorrelator do
  let(:user) { User.create!(name: "Test User", email: "correlator@example.com") }

  let!(:histamine_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" }
  end
  let!(:fodmap_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "fodmap") { |c| c.name = "FODMAP"; c.description = "test" }
  end
  let!(:salicylate_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "salicylate") { |c| c.name = "Salicylate"; c.description = "test" }
  end

  let(:bloating) { SymptomType.find_or_create_by!(slug: "bloating") { |st| st.name = "Bloating"; st.category = "gut" } }
  let(:headache) { SymptomType.find_or_create_by!(slug: "headache") { |st| st.name = "Headache"; st.category = "systemic" } }

  def create_food(name, category_memberships = {})
    food = Food.find_or_create_by!(name: name)
    category_memberships.each do |cat, severity|
      FoodCategoryMembership.find_or_create_by!(food: food, food_sensitivity_category: cat) { |m| m.severity = severity }
    end
    ingredient = Ingredient.find_or_create_by!(canonical_name: name.downcase) { |i| i.name = name }
    IngredientFoodMapping.find_or_create_by!(ingredient: ingredient, food: food)
    food
  end

  def log_meal(time, *foods)
    meal = Meal.create!(user: user, eaten_at: time, planned: false)
    foods.each do |food|
      ingredient = food.ingredients.first
      MealIngredient.create!(meal: meal, ingredient: ingredient, food: food)
    end
    meal
  end

  def log_symptom(time, symptom_type, score)
    SymptomLog.create!(user: user, symptom_type: symptom_type, logged_at: time, score: score)
  end

  def log_control(date, sleep_quality: nil, stress_level: nil, sleep_hours: nil, flags: {})
    dc = DailyControl.create!(
      user: user, date: date,
      sleep_quality: sleep_quality, stress_level: stress_level, sleep_hours: sleep_hours
    )
    flags.each do |flag_type, value|
      DailyControlFlag.create!(daily_control: dc, flag_type: flag_type.to_s, value: value.to_s)
    end
    dc
  end

  # ---------------------------------------------------------------------------
  # 1. TRAILING 24-HOUR ATTRIBUTION WINDOW
  # ---------------------------------------------------------------------------
  # When a symptom is logged, every meal eaten in the preceding 24 hours is
  # a potential contributor. This replaces day-boundary correlation.

  describe "24-hour trailing attribution window" do
    it "attributes a morning symptom to the previous evening's dinner" do
      dinner_food = create_food("Aged Cheddar", { histamine_cat => :high })
      safe_food = create_food("Plain Rice")

      # Day 1: dinner at 7pm with aged cheddar
      log_meal(Time.zone.parse("2025-06-01 19:00"), dinner_food)
      # Day 2: breakfast at 8am with plain rice, symptom at 9am
      log_meal(Time.zone.parse("2025-06-02 08:00"), safe_food)
      log_symptom(Time.zone.parse("2025-06-02 09:00"), bloating, 4)

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-02")
      ).call

      # Aged cheddar was eaten 14 hours before the symptom — within the 24h window
      cheddar_result = result.find { |r| r[:ingredient].canonical_name == "aged cheddar" }
      rice_result = result.find { |r| r[:ingredient].canonical_name == "plain rice" }

      expect(cheddar_result).to be_present
      expect(rice_result).to be_present
      # Both should be attributed, but cheddar should not be excluded just
      # because it was eaten on a different calendar day
    end

    it "does NOT attribute a symptom to a meal eaten more than 24 hours ago" do
      old_food = create_food("Old Sauerkraut", { histamine_cat => :high })

      # Day 1 lunch at noon
      log_meal(Time.zone.parse("2025-06-01 12:00"), old_food)
      # Day 2 symptom at 2pm — 26 hours later
      log_symptom(Time.zone.parse("2025-06-02 14:00"), bloating, 5)

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-02")
      ).call

      old_result = result.find { |r| r[:ingredient].canonical_name == "old sauerkraut" }
      # The meal is outside the 24h window for this symptom
      expect(old_result).to be_nil
    end

    it "attributes a symptom to multiple meals within the 24h window" do
      food_a = create_food("Kefir", { histamine_cat => :high })
      food_b = create_food("Strawberries", { histamine_cat => :medium, salicylate_cat => :high })

      # Lunch
      log_meal(Time.zone.parse("2025-06-01 12:00"), food_a)
      # Dinner
      log_meal(Time.zone.parse("2025-06-01 19:00"), food_b)
      # Symptom next morning
      log_symptom(Time.zone.parse("2025-06-02 08:00"), bloating, 4)

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-02")
      ).call

      kefir_result = result.find { |r| r[:ingredient].canonical_name == "kefir" }
      strawberry_result = result.find { |r| r[:ingredient].canonical_name == "strawberries" }

      expect(kefir_result).to be_present
      expect(strawberry_result).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 2. TIME-DECAY WEIGHTING
  # ---------------------------------------------------------------------------
  # Meals eaten closer to the symptom should contribute more to the correlation
  # than meals eaten 20 hours ago. This reflects the pharmacokinetic reality
  # that most food reactions have a peak window.

  describe "time-decay weighting" do
    it "weights a meal eaten 1 hour before a symptom more heavily than one eaten 20 hours before" do
      recent_food = create_food("Recent Wine", { histamine_cat => :high })
      old_food = create_food("Old Wine", { histamine_cat => :high })

      # Old wine: eaten 20 hours before symptom
      log_meal(Time.zone.parse("2025-06-01 12:00"), old_food)
      # Recent wine: eaten 1 hour before symptom
      log_meal(Time.zone.parse("2025-06-02 07:00"), recent_food)
      # Symptom
      log_symptom(Time.zone.parse("2025-06-02 08:00"), bloating, 5)

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-02")
      ).call

      recent_result = result.find { |r| r[:ingredient].canonical_name == "recent wine" }
      old_result = result.find { |r| r[:ingredient].canonical_name == "old wine" }

      # Both are within 24h, but recent should get a stronger attribution
      expect(recent_result[:score]).to be > old_result[:score]
    end
  end

  # ---------------------------------------------------------------------------
  # 3. QUALITY SCORE WEIGHTS OBSERVATIONS, NOT SYMPTOM SCORES
  # ---------------------------------------------------------------------------
  # The quality score determines how much INFLUENCE an observation has on the
  # correlation — it does NOT modify the symptom score itself. A high-symptom
  # day with poor sleep should still record the full symptom magnitude; the
  # quality score reduces that day's statistical weight.

  describe "quality score as observation weight" do
    it "does not modify the raw symptom score in the output" do
      food = create_food("Test Food A")

      date = Date.parse("2025-06-01")
      log_control(date, sleep_quality: 1, stress_level: 5) # very poor quality
      log_meal(date.to_time.change(hour: 12), food)
      log_symptom(date.to_time.change(hour: 20), bloating, 5)

      result = described_class.new(user, start_date: date, end_date: date).call
      entry = result.find { |r| r[:ingredient].canonical_name == "test food a" }

      # The symptom score of 5 should be preserved in the data, not reduced
      # The quality score affects weighting, not the score itself
      expect(entry[:raw_symptom_scores]).to include(5)
    end

    it "gives less statistical weight to low-quality days" do
      food = create_food("Consistent Food")
      # Day 1: high quality, high symptom
      d1 = Date.parse("2025-06-01")
      log_control(d1, sleep_quality: 5, stress_level: 1, sleep_hours: 8)
      log_meal(d1.to_time.change(hour: 12), food)
      log_symptom(d1.to_time.change(hour: 20), bloating, 4)

      # Day 2: low quality, high symptom
      d2 = Date.parse("2025-06-02")
      log_control(d2, sleep_quality: 1, stress_level: 5)
      log_meal(d2.to_time.change(hour: 12), food)
      log_symptom(d2.to_time.change(hour: 20), bloating, 4)

      result = described_class.new(user, start_date: d1, end_date: d2).call
      entry = result.find { |r| r[:ingredient].canonical_name == "consistent food" }

      # The observation weights should differ even though symptoms are identical
      expect(entry[:observation_weights].first).to be > entry[:observation_weights].last
    end
  end

  # ---------------------------------------------------------------------------
  # 4. PER-CATEGORY QUALITY SCORING
  # ---------------------------------------------------------------------------
  # Antihistamines zero out histamine-category correlations but should NOT
  # affect FODMAP or salicylate correlations from the same day.

  describe "per-category quality modifiers" do
    it "excludes antihistamine days from histamine-category analysis only" do
      histamine_food = create_food("Sauerkraut Test", { histamine_cat => :high })
      fodmap_food = create_food("Garlic Test", { fodmap_cat => :high })

      date = Date.parse("2025-06-01")
      log_control(date, sleep_quality: 4, stress_level: 2, flags: { antihistamine: "cetirizine 10mg" })
      log_meal(date.to_time.change(hour: 12), histamine_food)
      log_meal(date.to_time.change(hour: 18), fodmap_food)
      log_symptom(date.to_time.change(hour: 20), bloating, 4)

      result = described_class.new(user, start_date: date, end_date: date).call

      histamine_entry = result.find { |r| r[:ingredient].canonical_name == "sauerkraut test" }
      fodmap_entry = result.find { |r| r[:ingredient].canonical_name == "garlic test" }

      # Histamine food should be excluded (quality=0 for histamine category)
      expect(histamine_entry).to be_nil
      # FODMAP food should still be present — antihistamines don't affect FODMAP
      expect(fodmap_entry).to be_present
    end

    it "discounts NSAID days for salicylate-category analysis" do
      salicylate_food = create_food("Blueberry Test", { salicylate_cat => :high })

      date = Date.parse("2025-06-01")
      log_control(date, sleep_quality: 4, stress_level: 2, flags: { nsaid: "ibuprofen" })
      log_meal(date.to_time.change(hour: 12), salicylate_food)
      log_symptom(date.to_time.change(hour: 20), headache, 4)

      result = described_class.new(user, start_date: date, end_date: date).call
      entry = result.find { |r| r[:ingredient].canonical_name == "blueberry test" }

      # The observation should be heavily discounted (NSAIDs ARE salicylates),
      # though not necessarily fully excluded
      # We verify by checking the weight is below the non-flagged baseline
      expect(entry[:observation_weights].first).to be < 0.5
    end

    it "discounts perimenstrual days for histamine-category analysis" do
      histamine_food = create_food("Red Wine Test", { histamine_cat => :high })

      date = Date.parse("2025-06-01")
      log_control(date, sleep_quality: 4, stress_level: 2, flags: { menstrual_phase: "perimenstrual" })
      log_meal(date.to_time.change(hour: 19), histamine_food)
      log_symptom(date.to_time.change(hour: 22), bloating, 4)

      result = described_class.new(user, start_date: date, end_date: date).call
      entry = result.find { |r| r[:ingredient].canonical_name == "red wine test" }

      expect(entry[:observation_weights].first).to be < 0.7
    end
  end

  # ---------------------------------------------------------------------------
  # 5. MINIMUM EXPOSURE THRESHOLD
  # ---------------------------------------------------------------------------
  # An ingredient must be observed a minimum number of times before the
  # correlator reports a result. With fewer observations, the correlation
  # is statistically meaningless.

  describe "minimum exposure threshold" do
    it "does not report results for ingredients with fewer than MIN_EXPOSURES observations" do
      rare_food = create_food("Rare Food")

      # Only 2 exposures
      2.times do |i|
        date = Date.parse("2025-06-01") + i.days
        log_meal(date.to_time.change(hour: 12), rare_food)
        log_symptom(date.to_time.change(hour: 20), bloating, 4)
      end

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-10")
      ).call

      entry = result.find { |r| r[:ingredient].canonical_name == "rare food" }
      # With < MIN_EXPOSURES, this ingredient should either be absent or
      # explicitly flagged as insufficient data
      expect(entry).to satisfy { |e| e.nil? || e[:confidence] == :insufficient_data }
    end

    it "reports results for ingredients meeting the minimum exposure threshold" do
      common_food = create_food("Common Food")

      # 5+ exposures
      6.times do |i|
        date = Date.parse("2025-06-01") + i.days
        log_meal(date.to_time.change(hour: 12), common_food)
        log_symptom(date.to_time.change(hour: 20), bloating, 3)
      end

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-10")
      ).call

      entry = result.find { |r| r[:ingredient].canonical_name == "common food" }
      expect(entry).to be_present
      expect(entry[:exposure_count]).to be >= 5
    end
  end

  # ---------------------------------------------------------------------------
  # 6. FALSE DISCOVERY RATE CORRECTION
  # ---------------------------------------------------------------------------
  # With 7 categories × 12 symptom types = 84 potential correlations,
  # multiple comparisons correction is mandatory to control false positives.

  describe "Benjamini-Hochberg FDR correction" do
    it "marks results as significant only after FDR correction" do
      # Create many foods across different categories to generate multiple
      # parallel correlations
      foods = 10.times.map { |i| create_food("FDR Food #{i}") }

      # Log enough data for correlations to be computed
      20.times do |i|
        date = Date.parse("2025-06-01") + i.days
        # Eat 3 random foods per day
        foods.sample(3).each { |f| log_meal(date.to_time.change(hour: 12), f) }
        # Random symptom scores
        log_symptom(date.to_time.change(hour: 20), bloating, rand(1..5))
      end

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-20")
      ).call

      # Results should include FDR-adjusted p-values or significance flags
      result.each do |entry|
        next if entry[:confidence] == :insufficient_data
        expect(entry).to have_key(:p_value)
        expect(entry).to have_key(:fdr_significant)
      end
    end

    it "controls false discovery rate at the target level" do
      # With purely random data (no real associations), the proportion of
      # results marked as significant should not systematically exceed the
      # target FDR (default 0.10)
      #
      # NOTE: This is a statistical property test — it may occasionally fail
      # by chance (~10% of the time at FDR=0.10). Mark as :aggregate if
      # running in CI and tolerate occasional failures.

      foods = 15.times.map { |i| create_food("Null Food #{i}") }

      30.times do |i|
        date = Date.parse("2025-06-01") + i.days
        foods.sample(4).each { |f| log_meal(date.to_time.change(hour: 12), f) }
        log_symptom(date.to_time.change(hour: 20), bloating, rand(1..5))
      end

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-30"),
        target_fdr: 0.10
      ).call

      significant = result.count { |r| r[:fdr_significant] == true }
      total_tested = result.count { |r| r[:confidence] != :insufficient_data }

      # With null data, we expect few or no significant results
      # Allow up to 20% as a generous bound for stochastic testing
      expect(significant).to be <= (total_tested * 0.20).ceil
    end
  end

  # ---------------------------------------------------------------------------
  # 7. SYMPTOM-INGREDIENT DIRECTIONALITY
  # ---------------------------------------------------------------------------
  # The correlator should detect both positive (ingredient → more symptoms)
  # and null (ingredient → no change) associations. Only positive associations
  # should be flagged.

  describe "directionality" do
    it "produces a positive score for ingredients consistently eaten before high-symptom periods" do
      trigger_food = create_food("Trigger Food", { histamine_cat => :high })
      safe_food = create_food("Safe Food")

      10.times do |i|
        date = Date.parse("2025-06-01") + i.days
        if i.even?
          log_meal(date.to_time.change(hour: 12), trigger_food)
          log_symptom(date.to_time.change(hour: 20), bloating, 5)
        else
          log_meal(date.to_time.change(hour: 12), safe_food)
          log_symptom(date.to_time.change(hour: 20), bloating, 1)
        end
      end

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-10")
      ).call

      trigger_entry = result.find { |r| r[:ingredient].canonical_name == "trigger food" }
      safe_entry = result.find { |r| r[:ingredient].canonical_name == "safe food" }

      expect(trigger_entry[:score]).to be > 0
      expect(trigger_entry[:score]).to be > safe_entry[:score]
    end

    it "produces a near-zero score for ingredients with no symptom association" do
      neutral_food = create_food("Neutral Food")

      10.times do |i|
        date = Date.parse("2025-06-01") + i.days
        log_meal(date.to_time.change(hour: 12), neutral_food)
        # Random symptoms regardless of food
        log_symptom(date.to_time.change(hour: 20), bloating, rand(2..4))
      end

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-10")
      ).call

      entry = result.find { |r| r[:ingredient].canonical_name == "neutral food" }
      # Score should be close to neutral — not strongly positive or negative
      expect(entry[:score].abs).to be < 2.0
    end
  end

  # ---------------------------------------------------------------------------
  # 8. EMPTY AND EDGE CASES
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    it "returns empty results when there are no meals" do
      result = described_class.new(user, start_date: 7.days.ago.to_date, end_date: Date.today).call
      expect(result).to be_empty
    end

    it "returns empty results when there are no symptom logs" do
      food = create_food("Orphan Food")
      log_meal(Time.zone.parse("2025-06-01 12:00"), food)

      result = described_class.new(user,
        start_date: Date.parse("2025-06-01"),
        end_date: Date.parse("2025-06-01")
      ).call

      expect(result).to be_empty
    end

    it "handles multiple symptom types independently" do
      food = create_food("Multi Symptom Food")

      date = Date.parse("2025-06-01")
      log_meal(date.to_time.change(hour: 12), food)
      log_symptom(date.to_time.change(hour: 20), bloating, 5)
      log_symptom(date.to_time.change(hour: 20), headache, 1)

      result = described_class.new(user, start_date: date, end_date: date).call

      entry = result.find { |r| r[:ingredient].canonical_name == "multi symptom food" }
      # Should have separate scores per symptom type or a composite that
      # doesn't flatten the distinction
      expect(entry[:symptom_scores]).to be_a(Hash)
      expect(entry[:symptom_scores][bloating.id]).not_to eq(entry[:symptom_scores][headache.id])
    end
  end
end
