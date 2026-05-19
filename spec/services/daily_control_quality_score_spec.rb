# frozen_string_literal: true

require "rails_helper"

# These specs define the scientific contract for DailyControlQualityScore.
#
# Key scientific requirements:
#   1. Per-category scoring (not global) — antihistamines affect histamine, not FODMAP
#   2. Flags modify weight multiplicatively, not additively
#   3. Illness heavily discounts ALL categories
#   4. Medication flags discount only relevant categories
#   5. Menstrual phase flags discount histamine category specifically
#   6. Score is a weight (0.0-1.0) for statistical observation weighting
#   7. Default score for missing data is conservative (not optimistic)
#
RSpec.describe DailyControlQualityScore do
  let!(:histamine_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "histamine") { |c| c.name = "Histamine"; c.description = "test" }
  end
  let!(:fodmap_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "fodmap") { |c| c.name = "FODMAP"; c.description = "test" }
  end
  let!(:salicylate_cat) do
    FoodSensitivityCategory.find_or_create_by!(slug: "salicylate") { |c| c.name = "Salicylate"; c.description = "test" }
  end

  let(:user) { User.create!(name: "QS User", email: "qs@example.com") }

  def build_control(sleep_quality: nil, stress_level: nil, sleep_hours: nil, exercise: nil, flags: {})
    dc = DailyControl.create!(
      user: user, date: Date.today + rand(1000),
      sleep_quality: sleep_quality, stress_level: stress_level,
      sleep_hours: sleep_hours, exercise_intensity: exercise
    )
    flags.each do |flag_type, value|
      DailyControlFlag.create!(daily_control: dc, flag_type: flag_type.to_s, value: value.to_s)
    end
    dc
  end

  # ---------------------------------------------------------------------------
  # 1. BASELINE SCORING (no flags, no category context)
  # ---------------------------------------------------------------------------

  describe "baseline scoring" do
    it "returns 1.0 for optimal sleep and minimal stress" do
      dc = build_control(sleep_quality: 5, stress_level: 1, sleep_hours: 8.0)
      score = described_class.new(dc).call
      expect(score).to be_within(0.05).of(1.0)
    end

    it "returns a low score for poor sleep and high stress" do
      dc = build_control(sleep_quality: 1, stress_level: 5)
      score = described_class.new(dc).call
      expect(score).to be < 0.15
    end

    it "returns a moderate default when all fields are nil" do
      dc = build_control
      score = described_class.new(dc).call
      # Missing data should assume moderate, not optimal
      expect(score).to be_between(0.2, 0.5)
    end

    it "clamps to [0.0, 1.0] range" do
      dc_high = build_control(sleep_quality: 5, stress_level: 1, sleep_hours: 8.0)
      dc_low = build_control(sleep_quality: 1, stress_level: 5, sleep_hours: 2.0)

      expect(described_class.new(dc_high).call).to be <= 1.0
      expect(described_class.new(dc_low).call).to be >= 0.0
    end

    it "awards a bonus for optimal sleep hours (7-9h range)" do
      dc_optimal = build_control(sleep_quality: 4, stress_level: 2, sleep_hours: 8.0)
      dc_short = build_control(sleep_quality: 4, stress_level: 2, sleep_hours: 4.5)

      expect(described_class.new(dc_optimal).call).to be > described_class.new(dc_short).call
    end
  end

  # ---------------------------------------------------------------------------
  # 2. PER-CATEGORY SCORING
  # ---------------------------------------------------------------------------
  # The same day can have different quality scores depending on which
  # sensitivity category is being evaluated. This is the key scientific
  # requirement that distinguishes this from a naive global score.

  describe "per-category scoring" do
    it "accepts an optional category parameter" do
      dc = build_control(sleep_quality: 4, stress_level: 2)
      expect { described_class.new(dc, category: histamine_cat).call }.not_to raise_error
      expect { described_class.new(dc, category: nil).call }.not_to raise_error
    end

    it "returns different scores for different categories on antihistamine days" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { antihistamine: "cetirizine 10mg" })

      histamine_score = described_class.new(dc, category: histamine_cat).call
      fodmap_score = described_class.new(dc, category: fodmap_cat).call

      # Histamine should be zeroed or near-zero
      expect(histamine_score).to eq(0.0)
      # FODMAP should be unaffected by antihistamine
      expect(fodmap_score).to be > 0.5
    end

    it "returns same baseline score for categories with no relevant flags" do
      dc = build_control(sleep_quality: 4, stress_level: 2)

      histamine_score = described_class.new(dc, category: histamine_cat).call
      fodmap_score = described_class.new(dc, category: fodmap_cat).call

      expect(histamine_score).to eq(fodmap_score)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. ANTIHISTAMINE FLAG
  # ---------------------------------------------------------------------------
  # Antihistamines block H1/H2 receptors, masking histamine-mediated symptoms.
  # They do NOT affect FODMAP fermentation, oxalate crystal deposition,
  # lectin binding, glutamate receptor activation, or TRPV1 capsaicin signaling.

  describe "antihistamine flag" do
    let(:dc) { build_control(sleep_quality: 4, stress_level: 2, flags: { antihistamine: "cetirizine 10mg" }) }

    it "zeros histamine-category quality" do
      expect(described_class.new(dc, category: histamine_cat).call).to eq(0.0)
    end

    it "does not affect FODMAP-category quality" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      expect(described_class.new(dc, category: fodmap_cat).call)
        .to eq(described_class.new(unflagged, category: fodmap_cat).call)
    end

    it "does not affect salicylate-category quality" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      expect(described_class.new(dc, category: salicylate_cat).call)
        .to eq(described_class.new(unflagged, category: salicylate_cat).call)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. NSAID FLAG
  # ---------------------------------------------------------------------------
  # NSAIDs inhibit COX enzymes (they ARE salicylates) AND inhibit DAO.
  # They should discount both salicylate and histamine categories.

  describe "NSAID flag" do
    let(:dc) { build_control(sleep_quality: 4, stress_level: 2, flags: { nsaid: "ibuprofen" }) }

    it "heavily discounts salicylate-category quality" do
      score = described_class.new(dc, category: salicylate_cat).call
      expect(score).to be < 0.4
    end

    it "discounts histamine-category quality (NSAIDs inhibit DAO)" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      nsaid_score = described_class.new(dc, category: histamine_cat).call
      clean_score = described_class.new(unflagged, category: histamine_cat).call
      expect(nsaid_score).to be < clean_score
    end

    it "does not affect FODMAP-category quality" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      expect(described_class.new(dc, category: fodmap_cat).call)
        .to eq(described_class.new(unflagged, category: fodmap_cat).call)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. MAST CELL STABILIZER FLAG
  # ---------------------------------------------------------------------------
  # Stabilizers prevent degranulation, affecting histamine AND other mast cell
  # mediators (prostaglandins, leukotrienes). This masks both histamine and
  # salicylate-category signals (salicylate sensitivity works through the
  # arachidonic acid → leukotriene pathway, which is mast-cell-mediated).

  describe "mast cell stabilizer flag" do
    let(:dc) { build_control(sleep_quality: 4, stress_level: 2, flags: { mast_cell_stabilizer: "cromolyn" }) }

    it "discounts histamine-category quality" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      expect(described_class.new(dc, category: histamine_cat).call)
        .to be < described_class.new(unflagged, category: histamine_cat).call
    end

    it "discounts salicylate-category quality" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      expect(described_class.new(dc, category: salicylate_cat).call)
        .to be < described_class.new(unflagged, category: salicylate_cat).call
    end

    it "does not affect FODMAP-category quality" do
      unflagged = build_control(sleep_quality: 4, stress_level: 2)
      expect(described_class.new(dc, category: fodmap_cat).call)
        .to eq(described_class.new(unflagged, category: fodmap_cat).call)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. MENSTRUAL PHASE FLAGS
  # ---------------------------------------------------------------------------
  # Perimenstrual and menstrual phases: progesterone drops, losing its mast
  # cell stabilizing effect. Estrogen-mediated mast cell priming.
  # These phases inflate histamine-category symptoms independent of food.

  describe "menstrual phase flags" do
    it "discounts histamine quality during perimenstrual phase" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { menstrual_phase: "perimenstrual" })
      unflagged = build_control(sleep_quality: 4, stress_level: 2)

      expect(described_class.new(dc, category: histamine_cat).call)
        .to be < described_class.new(unflagged, category: histamine_cat).call
    end

    it "discounts histamine quality during menstrual phase" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { menstrual_phase: "menstrual" })
      unflagged = build_control(sleep_quality: 4, stress_level: 2)

      expect(described_class.new(dc, category: histamine_cat).call)
        .to be < described_class.new(unflagged, category: histamine_cat).call
    end

    it "does not discount histamine quality during luteal phase (high progesterone = stabilizing)" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { menstrual_phase: "luteal" })
      unflagged = build_control(sleep_quality: 4, stress_level: 2)

      expect(described_class.new(dc, category: histamine_cat).call)
        .to eq(described_class.new(unflagged, category: histamine_cat).call)
    end

    it "does not affect FODMAP quality during any menstrual phase" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { menstrual_phase: "perimenstrual" })
      unflagged = build_control(sleep_quality: 4, stress_level: 2)

      expect(described_class.new(dc, category: fodmap_cat).call)
        .to eq(described_class.new(unflagged, category: fodmap_cat).call)
    end
  end

  # ---------------------------------------------------------------------------
  # 7. ILLNESS FLAG
  # ---------------------------------------------------------------------------
  # Illness elevates baseline inflammation across ALL pathways.

  describe "illness flag" do
    let(:dc) { build_control(sleep_quality: 4, stress_level: 2, flags: { illness: "cold" }) }

    it "heavily discounts ALL categories" do
      [ histamine_cat, fodmap_cat, salicylate_cat ].each do |cat|
        score = described_class.new(dc, category: cat).call
        expect(score).to be < 0.35
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 8. ALCOHOL FLAG
  # ---------------------------------------------------------------------------
  # Alcohol: contains histamine, liberates histamine, blocks DAO, and
  # increases intestinal permeability (affecting all categories).

  describe "alcohol flag" do
    it "heavily discounts histamine quality" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { alcohol: "true" })
      unflagged = build_control(sleep_quality: 4, stress_level: 2)

      expect(described_class.new(dc, category: histamine_cat).call)
        .to be < described_class.new(unflagged, category: histamine_cat).call * 0.5
    end

    it "moderately discounts other categories via gut permeability effects" do
      dc = build_control(sleep_quality: 4, stress_level: 2, flags: { heavy_alcohol: "true" })
      unflagged = build_control(sleep_quality: 4, stress_level: 2)

      expect(described_class.new(dc, category: fodmap_cat).call)
        .to be < described_class.new(unflagged, category: fodmap_cat).call
    end
  end

  # ---------------------------------------------------------------------------
  # 9. INTENSE EXERCISE FLAG
  # ---------------------------------------------------------------------------
  # Intense exercise triggers mast cell degranulation and increases gut
  # permeability. Affects histamine more than other categories.

  describe "intense exercise" do
    it "discounts quality for all categories" do
      dc = build_control(sleep_quality: 4, stress_level: 2, exercise: "intense")
      unflagged = build_control(sleep_quality: 4, stress_level: 2, exercise: "none")

      [ histamine_cat, fodmap_cat, salicylate_cat ].each do |cat|
        expect(described_class.new(dc, category: cat).call)
          .to be < described_class.new(unflagged, category: cat).call
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 10. FLAG STACKING
  # ---------------------------------------------------------------------------
  # Multiple flags on the same day should compound multiplicatively.

  describe "flag stacking" do
    it "compounds multiple discounts" do
      dc_single = build_control(sleep_quality: 3, stress_level: 3, flags: { alcohol: "true" })
      dc_double = build_control(sleep_quality: 3, stress_level: 3, flags: { alcohol: "true", illness: "cold" })

      single_score = described_class.new(dc_single, category: histamine_cat).call
      double_score = described_class.new(dc_double, category: histamine_cat).call

      expect(double_score).to be < single_score
    end
  end
end
