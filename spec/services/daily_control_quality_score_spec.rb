require "rails_helper"

RSpec.describe DailyControlQualityScore do
  def build_control(sleep_quality: nil, stress_level: nil, sleep_hours: nil)
    instance_double(DailyControl,
      sleep_quality: sleep_quality,
      stress_level: stress_level,
      sleep_hours: sleep_hours)
  end

  describe "#call" do
    it "returns 0.5 * 0.5 = 0.25 when all fields are nil" do
      dc = build_control
      score = described_class.new(dc).call
      expect(score).to be_within(0.01).of(0.25)
    end

    it "returns 1.0 for perfect sleep_quality=5, stress_level=1, optimal sleep hours" do
      dc = build_control(sleep_quality: 5, stress_level: 1, sleep_hours: 8.0)
      score = described_class.new(dc).call
      expect(score).to be_within(0.01).of(1.0)
    end

    it "returns a low score for poor sleep and high stress" do
      dc = build_control(sleep_quality: 1, stress_level: 5)
      score = described_class.new(dc).call
      expect(score).to be < 0.1
    end

    it "awards a sleep_hours bonus for hours in 7–9 range" do
      dc_with = build_control(sleep_quality: 4, stress_level: 2, sleep_hours: 8.0)
      dc_without = build_control(sleep_quality: 4, stress_level: 2, sleep_hours: 5.0)
      score_with = described_class.new(dc_with).call
      score_without = described_class.new(dc_without).call
      expect(score_with).to be > score_without
    end

    it "clamps result to 1.0 maximum" do
      dc = build_control(sleep_quality: 5, stress_level: 1, sleep_hours: 8.0)
      expect(described_class.new(dc).call).to be <= 1.0
    end

    it "clamps result to 0.0 minimum" do
      dc = build_control(sleep_quality: 1, stress_level: 5)
      expect(described_class.new(dc).call).to be >= 0.0
    end
  end
end
