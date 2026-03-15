# Correlates ingredients with symptom scores for a user over a date range.
#
# Returns a hash: { ingredient_id => { ingredient: Ingredient, score: Float, exposure_days: Integer } }
# sorted by score descending.
#
# Algorithm:
#   For each day in range:
#     1. Compute daily_control quality weight (0.0–1.0). Default 0.5 if no record.
#     2. Sum symptom scores for that day, weighted by quality.
#     3. For each ingredient logged in meals that day, accumulate weighted symptom contribution.
#   Final score for each ingredient = total_weighted_symptoms / total_weighted_exposure_days
#
class SymptomCorrelator
  def initialize(user, start_date: 14.days.ago.to_date, end_date: Date.today)
    @user = user
    @start_date = start_date
    @end_date = end_date
  end

  def call
    results = {}

    (@start_date..@end_date).each do |date|
      quality = quality_for(date)
      symptom_total = symptom_score_for(date)
      weighted_symptom = symptom_total * quality

      ingredient_ids_for(date).each do |ingredient_id|
        results[ingredient_id] ||= { weighted_symptom_sum: 0.0, weighted_exposure_sum: 0.0, exposure_days: 0 }
        results[ingredient_id][:weighted_symptom_sum] += weighted_symptom
        results[ingredient_id][:weighted_exposure_sum] += quality
        results[ingredient_id][:exposure_days] += 1
      end
    end

    build_output(results)
  end

  private

  def quality_for(date)
    dc = @user.daily_controls.find_by(date: date)
    return 0.5 unless dc
    DailyControlQualityScore.new(dc).call
  end

  def symptom_score_for(date)
    logs = @user.symptom_logs.in_range(date, date)
    return 0.0 if logs.empty?
    logs.sum(:score).to_f / logs.count
  end

  def ingredient_ids_for(date)
    meal_ids = @user.meals
      .where(eaten_at: date.beginning_of_day..date.end_of_day)
      .pluck(:id)
    return [] if meal_ids.empty?
    MealIngredient.where(meal_id: meal_ids).pluck(:ingredient_id).uniq
  end

  def build_output(results)
    ingredients = Ingredient.where(id: results.keys).index_by(&:id)

    output = results.filter_map do |ingredient_id, data|
      next unless ingredients[ingredient_id]
      exposure = data[:weighted_exposure_sum]
      score = exposure > 0 ? data[:weighted_symptom_sum] / exposure : 0.0

      [ingredient_id, {
        ingredient: ingredients[ingredient_id],
        score: score.round(4),
        exposure_days: data[:exposure_days]
      }]
    end.to_h

    output.sort_by { |_, v| -v[:score] }.to_h
  end
end
