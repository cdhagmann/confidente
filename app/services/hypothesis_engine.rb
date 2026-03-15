# Looks at a user's suspected foods, groups them by sensitivity category,
# and suggests additional high-severity foods in the same category to test.
#
# Rules:
#   - A category must have 2+ suspected foods to trigger a suggestion
#   - Only suggests foods not already suspected
#   - Only suggests foods in the high severity tier for that category
#   - Skips a category if there's an active washout window for it today
#   - Creates HypothesisSuggestion records (idempotent — find_or_create_by)
#
# Returns an array of newly created HypothesisSuggestion records.
#
class HypothesisEngine
  def initialize(user)
    @user = user
    @today = Date.today
  end

  def call
    suggestions = []

    categories_with_multiple_suspects.each do |category, suspect_foods|
      next if active_washout_for?(category)

      suspected_food_ids = suspect_foods.map(&:id)
      candidate_foods = high_severity_foods_for(category).reject { |f| suspected_food_ids.include?(f.id) }

      candidate_foods.each do |food|
        suggestion = HypothesisSuggestion.find_or_create_by!(
          user: @user,
          suggested_food: food,
          reason_category: category
        ) do |s|
          s.status = :pending
        end
        suggestions << suggestion if suggestion.previously_new_record?
      end
    end

    suggestions
  end

  private

  def categories_with_multiple_suspects
    # Group the user's suspected foods by category, keep categories with 2+
    suspect_foods = @user.suspect_foods.includes(:sensitivity_categories)
    category_map = Hash.new { |h, k| h[k] = [] }

    suspect_foods.each do |food|
      food.sensitivity_categories.each do |category|
        category_map[category] << food
      end
    end

    category_map.select { |_cat, foods| foods.size >= 2 }
  end

  def active_washout_for?(category)
    @user.meal_plans
      .joins(:washout_windows)
      .where(washout_windows: { food_sensitivity_category_id: category.id })
      .where("washout_windows.start_date <= ? AND washout_windows.end_date >= ?", @today, @today)
      .exists?
  end

  def high_severity_foods_for(category)
    Food.joins(:food_category_memberships)
      .where(food_category_memberships: {
        food_sensitivity_category_id: category.id,
        severity: FoodCategoryMembership.severities[:high]
      })
  end
end
