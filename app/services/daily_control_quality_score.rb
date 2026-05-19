# Converts a DailyControl record into a reliability weight for that day's symptom data.
# Returns a float 0.0–1.0. Higher = more reliable signal.
#
# Formula:
#   sleep_score   = sleep_quality / 5.0  (missing → 0.5 assumed)
#   stress_score  = 1 - (stress_level - 1) / 4.0  (missing → 0.5 assumed)
#   sleep_bonus   = small boost when sleep_hours is in the 7–9 h optimal range
#   composite     = sleep_score * stress_score * (1 + sleep_bonus)
#
class DailyControlQualityScore
  OPTIMAL_SLEEP_MIN = 7.0
  OPTIMAL_SLEEP_MAX = 9.0
  SLEEP_BONUS = 0.1

  def initialize(daily_control)
    @dc = daily_control
  end

  def call
    score = sleep_score * stress_score
    score *= (1 + sleep_hours_bonus)
    score.clamp(0.0, 1.0)
  end

  private

  def sleep_score
    return 0.5 if @dc.sleep_quality.nil?
    @dc.sleep_quality / 5.0
  end

  def stress_score
    return 0.5 if @dc.stress_level.nil?
    1.0 - (@dc.stress_level - 1) / 4.0
  end

  def sleep_hours_bonus
    return 0.0 if @dc.sleep_hours.nil?
    hours = @dc.sleep_hours.to_f
    (hours >= OPTIMAL_SLEEP_MIN && hours <= OPTIMAL_SLEEP_MAX) ? SLEEP_BONUS : 0.0
  end
end
