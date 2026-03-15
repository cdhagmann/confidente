module Confidente
  module CLI
    module Screens
      # Week Plan tab — table view of the 7-day meal plan.
      # Columns: Day | Breakfast | Lunch | Dinner
      # Highlights days with active washout windows.
      class WeekPlanTab
        def initialize(tui, user)
          @tui = tui
          @user = user
          @cursor = 0
        end

        def render(frame, area)
          plan = active_plan
          unless plan
            frame.render_widget(
              @tui.paragraph(
                text: "No active meal plan.",
                block: @tui.block(title: "Week Plan", borders: [:all], border_type: :rounded)
              ),
              area
            )
            return
          end

          slots_by_date = plan.meal_plan_slots
            .includes(meal: :ingredients)
            .group_by(&:scheduled_for)
          washout_dates = washout_active_dates(plan)
          rows = build_rows(plan, slots_by_date, washout_dates)

          areas = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_fill(1),
              @tui.constraint_length(1)
            ]
          )

          frame.render_widget(
            @tui.table(
              rows: rows,
              selected_row: @cursor,
              block: @tui.block(
                title: "Week Plan — #{plan.starts_on.strftime("%b %-d")} to #{plan.ends_on.strftime("%b %-d")}",
                borders: [:all],
                border_type: :rounded
              )
            ),
            areas[0]
          )
          frame.render_widget(
            @tui.paragraph(text: "[↑↓] scroll   * = washout window active", alignment: :center),
            areas[1]
          )
        end

        def handle_event(event)
          case event
          in { type: :key, code: "up" }
            @cursor = [@cursor - 1, 0].max
          in { type: :key, code: "down" }
            @cursor = [@cursor + 1, 6].min
          else
            # no-op
          end
        end

        private

        def build_rows(plan, slots_by_date, washout_dates)
          (plan.starts_on..plan.ends_on).map do |date|
            day_slots = (slots_by_date[date] || []).index_by(&:meal_time)
            washout  = washout_dates.include?(date) ? " *" : ""
            today    = date == Date.today
            day_label = "#{today ? "►" : " "} #{date.strftime("%a %-d")}#{washout}"

            [day_label, meal_cell(day_slots["breakfast"]), meal_cell(day_slots["lunch"]), meal_cell(day_slots["dinner"])]
          end
        end

        def meal_cell(slot)
          return "(—)" unless slot&.meal
          ingredients = slot.meal.ingredients.limit(2).pluck(:name)
          ingredients.any? ? ingredients.join(", ") : "(planned)"
        end

        def washout_active_dates(plan)
          dates = Set.new
          plan.washout_windows.each { |w| (w.start_date..w.end_date).each { |d| dates.add(d) } }
          dates
        end

        def active_plan
          @user.meal_plans
            .includes(:meal_plan_slots, :washout_windows)
            .where("ends_on >= ?", Date.today)
            .order(:starts_on)
            .first
        end
      end
    end
  end
end
