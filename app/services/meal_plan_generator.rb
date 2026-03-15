# Generates a 7-day meal plan for a user using Latin square-inspired scheduling.
#
# Goals:
#   - Each suspected food/ingredient appears at minimum 3 times across the plan
#   - Washout windows are enforced between exposures to the same sensitivity category
#     (default: 2-day gap between consecutive meals containing the same category)
#   - Meals are drawn from seeded foods (POC — no external recipe API)
#
# Output: a MealPlan with 21 MealPlanSlots (7 days × 3 meals) and associated Meal/MealIngredient records.
#
class MealPlanGenerator
  MEAL_TIMES = %w[breakfast lunch dinner].freeze
  WASHOUT_DAYS = 2
  MIN_EXPOSURES = 3

  def initialize(user, start_date: Date.today)
    @user = user
    @start_date = start_date
    @end_date = start_date + 6.days
  end

  def call
    meal_plan = MealPlan.create!(user: @user, starts_on: @start_date, ends_on: @end_date)

    schedule = build_schedule
    create_slots(meal_plan, schedule)
    create_washout_windows(meal_plan, schedule)

    meal_plan
  end

  private

  # Returns a 7×3 array: schedule[day_index][meal_time_index] = [Food, ...]
  def build_schedule
    food_pool = available_foods
    suspect_foods = @user.suspect_foods.to_a
    schedule = Array.new(7) { Array.new(3) { [] } }

    # Assign suspect foods first, ensuring MIN_EXPOSURES appearances each
    suspect_foods.each do |food|
      slots_for_food = pick_slots_for(food, schedule, min: MIN_EXPOSURES)
      slots_for_food.each { |(day, meal)| schedule[day][meal] << food }
    end

    # Fill remaining empty slots from the general food pool using a Latin-square rotation
    # so that each category is spaced out across days
    food_pool_cycle = food_pool.reject { |f| suspect_foods.include?(f) }.cycle
    category_last_day = Hash.new(-WASHOUT_DAYS - 1)

    7.times do |day|
      3.times do |meal|
        next if schedule[day][meal].any?

        # Pick next food that respects washout for all its categories
        candidate = find_candidate(food_pool_cycle, category_last_day, day)
        next unless candidate

        schedule[day][meal] << candidate
        candidate.sensitivity_categories.each do |cat|
          category_last_day[cat.id] = day
        end
      end
    end

    schedule
  end

  def find_candidate(pool_cycle, category_last_day, day)
    # Try up to 50 candidates before giving up on this slot
    50.times do
      food = pool_cycle.next
      categories = food.sensitivity_categories
      ok = categories.all? { |cat| day - category_last_day[cat.id] > WASHOUT_DAYS }
      return food if ok
    end
    nil
  rescue StopIteration
    nil
  end

  # Pick slot positions for a food, spread across the week
  def pick_slots_for(food, schedule, min:)
    chosen = []
    days = (0..6).to_a.shuffle
    meals = (0..2).to_a

    days.each do |day|
      meals.each do |meal|
        next if schedule[day][meal].include?(food)
        chosen << [day, meal]
        break if chosen.size >= min
      end
      break if chosen.size >= min
    end

    chosen
  end

  def create_slots(meal_plan, schedule)
    7.times do |day_offset|
      date = @start_date + day_offset.days
      MEAL_TIMES.each_with_index do |meal_time, meal_index|
        foods = schedule[day_offset][meal_index]
        meal = nil

        if foods.any?
          meal = Meal.create!(user: @user, eaten_at: meal_datetime(date, meal_time), planned: true)
          foods.each do |food|
            ingredient = food.ingredients.first || Ingredient.find_by(canonical_name: food.name.downcase)
            next unless ingredient
            MealIngredient.create!(meal: meal, ingredient: ingredient, food: food)
          end
        end

        MealPlanSlot.create!(
          meal_plan: meal_plan,
          scheduled_for: date,
          meal_time: meal_time,
          meal: meal
        )
      end
    end
  end

  def create_washout_windows(meal_plan, schedule)
    # For each category used in the plan, create a washout window around the final exposure
    category_last_day = {}

    7.times do |day|
      3.times do |meal|
        schedule[day][meal].each do |food|
          food.sensitivity_categories.each do |cat|
            category_last_day[cat.id] = { category: cat, day: day }
          end
        end
      end
    end

    category_last_day.each_value do |entry|
      last_exposure_date = @start_date + entry[:day].days
      WashoutWindow.create!(
        meal_plan: meal_plan,
        food_sensitivity_category: entry[:category],
        start_date: last_exposure_date,
        end_date: last_exposure_date + WASHOUT_DAYS.days
      )
    end
  end

  def available_foods
    Food.includes(:sensitivity_categories, :ingredients).to_a.shuffle
  end

  def meal_datetime(date, meal_time)
    hour = case meal_time
           when "breakfast" then 8
           when "lunch" then 12
           when "dinner" then 18
           end
    date.to_time.change(hour: hour)
  end
end
