module Confidente
  module CLI
    module Screens
      # Today tab — shows today's planned meals and the daily check-in form.
      class TodayTab
        def initialize(tui, user)
          @tui = tui
          @user = user
          @section = :meals
          @cursor = 0
        end

        # Called by Home to render into a sub-area of the frame
        def render(frame, area)
          areas = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(8),   # meals: 3 slots + borders + hint
              @tui.constraint_length(7),   # check-in: 4 lines + borders
              @tui.constraint_fill(1)      # symptoms: all remaining space
            ]
          )
          render_meals(frame, areas[0])
          render_checkin(frame, areas[1])
          render_symptoms(frame, areas[2])
        end

        # Called by Home with the already-polled event
        def handle_event(event)
          case event
          in { type: :key, code: "up" }
            @cursor = [@cursor - 1, 0].max
          in { type: :key, code: "down" }
            @cursor += 1
          in { type: :key, code: "m" }
            @section = :meals
            @cursor = 0
          in { type: :key, code: "c" }
            run_checkin_form
          in { type: :key, code: "s" }
            @section = :symptoms
            @cursor = 0
          in { type: :key, code: "enter" }
            handle_enter
          in { type: :key, code: "e" }
            mark_eaten if @section == :meals
          in { type: :key, code: "o" }
            run_offplan_form if @section == :meals
          else
            # no-op
          end
        end

        private

        def render_meals(frame, area)
          slots = today_slots
          items = slots.map do |slot|
            meal_name = slot.meal ? meal_summary(slot.meal) : "(not yet planned)"
            "#{slot.meal_time.capitalize.ljust(10)} #{meal_name}"
          end
          items << "" << "  [e] Mark eaten   [o] Log off-plan"

          frame.render_widget(
            @tui.list(
              items: items,
              selected_index: @section == :meals ? @cursor : nil,
              highlight_symbol: "> ",
              block: @tui.block(
                title: "Today's Meals — #{Date.today.strftime("%A, %B %-d")}",
                borders: [:all],
                border_type: :rounded
              )
            ),
            area
          )
        end

        def render_checkin(frame, area)
          dc = daily_control_today
          lines = [
            "Sleep: #{dc&.sleep_hours || "??"}h  Quality: #{rating_bar(dc&.sleep_quality)}",
            "Stress: #{rating_bar(dc&.stress_level)}  Exercise: #{dc&.exercise_intensity || "not logged"}",
            "",
            "  [c] Log / update check-in"
          ]

          frame.render_widget(
            @tui.paragraph(
              text: lines.join("\n"),
              block: @tui.block(title: "Daily Check-In", borders: [:all], border_type: :rounded)
            ),
            area
          )
        end

        def render_symptoms(frame, area)
          symptom_types = SymptomType.order(:category, :name).to_a
          items = symptom_types.map do |st|
            score = logged_symptom_score(st)
            score_display = score ? rating_bar(score) : "not logged"
            "#{st.name.ljust(20)} #{score_display}"
          end
          items << "" << "  [s] select  [Enter] log score"

          frame.render_widget(
            @tui.list(
              items: items,
              selected_index: @section == :symptoms ? @cursor : nil,
              highlight_symbol: "> ",
              block: @tui.block(title: "Symptoms", borders: [:all], border_type: :rounded)
            ),
            area
          )
        end

        def handle_enter
          case @section
          when :checkin then run_checkin_form
          when :symptoms then run_symptom_form
          end
        end

        def mark_eaten
          slot = today_slots[@cursor]
          return unless slot&.meal
          slot.meal.update!(eaten_at: Time.current)
        end

        # --- Nested modal forms (have their own draw loops) ---

        def run_checkin_form
          fields = { sleep_hours: "", sleep_quality: "", stress_level: "", exercise_intensity: "" }
          field_order = fields.keys
          cursor = 0

          loop do
            @tui.draw { |frame| render_checkin_form(frame, fields, cursor, field_order) }

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "tab" }
              cursor = (cursor + 1) % field_order.size
            in { type: :key, code: "enter" }
              save_checkin(fields)
              break
            in { type: :key, code: "esc" }
              break
            in { type: :key, code: "backspace" }
              key = field_order[cursor]
              fields[key] = fields[key][0...-1]
            in { type: :key, code: code, modifiers: [] } if code.length == 1
              fields[field_order[cursor]] += code
            else
              # no-op
            end
          end
        end

        def render_checkin_form(frame, fields, cursor, field_order)
          labels = {
            sleep_hours:        "Sleep hours (e.g. 7.5):              ",
            sleep_quality:      "Sleep quality 1-5:                   ",
            stress_level:       "Stress level 1-5:                    ",
            exercise_intensity: "Exercise (none/light/moderate/intense):"
          }
          lines = field_order.map.with_index do |key, i|
            prefix = i == cursor ? "> " : "  "
            "#{prefix}#{labels[key]} #{fields[key]}#{"_" if i == cursor}"
          end
          lines << "" << "  [Tab] next field   [Enter] save   [Esc] cancel"

          frame.render_widget(
            @tui.paragraph(
              text: lines.join("\n"),
              block: @tui.block(title: "Daily Check-In", borders: [:all], border_type: :rounded)
            ),
            frame.area
          )
        end

        def save_checkin(fields)
          dc = DailyControl.find_or_initialize_by(user: @user, date: Date.today)
          dc.sleep_hours     = fields[:sleep_hours].to_f.positive? ? fields[:sleep_hours].to_f : nil
          dc.sleep_quality   = clamp_int(fields[:sleep_quality], 1, 5)
          dc.stress_level    = clamp_int(fields[:stress_level], 1, 5)
          intensity = fields[:exercise_intensity].strip.downcase
          dc.exercise_intensity = DailyControl.exercise_intensities.value?(intensity) ? intensity : nil
          dc.save
        end

        def run_symptom_form
          symptom_types = SymptomType.order(:category, :name).to_a
          st = symptom_types[@cursor]
          return unless st

          score_input = ""
          loop do
            @tui.draw do |frame|
              frame.render_widget(
                @tui.paragraph(
                  text: "Score for #{st.name} (1=mild … 5=severe): #{score_input}_\n\n  [Enter] save   [Esc] cancel",
                  block: @tui.block(title: "Log Symptom", borders: [:all], border_type: :rounded)
                ),
                frame.area
              )
            end

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "enter" }
              score = score_input.to_i
              if (1..5).include?(score)
                SymptomLog.create!(
                  user: @user, symptom_type: st,
                  logged_at: Time.current, score: score
                )
              end
              break
            in { type: :key, code: "esc" }
              break
            in { type: :key, code: "backspace" }
              score_input = score_input[0...-1]
            in { type: :key, code: code, modifiers: [] } if code.length == 1
              score_input += code
            else
              # no-op
            end
          end
        end

        def run_offplan_form
          input = ""
          loop do
            @tui.draw do |frame|
              frame.render_widget(
                @tui.paragraph(
                  text: "What did you eat? (ingredient name): #{input}_\n\n  [Enter] save   [Esc] cancel",
                  block: @tui.block(title: "Log Off-Plan Meal", borders: [:all], border_type: :rounded)
                ),
                frame.area
              )
            end

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "enter" }
              name = input.strip
              unless name.empty?
                ingredient = Ingredient.find_or_create_by!(canonical_name: name.downcase) { |i| i.name = name }
                meal = Meal.create!(user: @user, eaten_at: Time.current, planned: false, notes: "Off-plan")
                MealIngredient.create!(meal: meal, ingredient: ingredient)
              end
              break
            in { type: :key, code: "esc" }
              break
            in { type: :key, code: "backspace" }
              input = input[0...-1]
            in { type: :key, code: code, modifiers: [] } if code.length == 1
              input += code
            else
              # no-op
            end
          end
        end

        # --- Helpers ---

        def today_slots
          @today_slots ||= begin
            plan = @user.meal_plans.where("ends_on >= ?", Date.today).order(:starts_on).first
            return [] unless plan
            plan.meal_plan_slots
              .where(scheduled_for: Date.today)
              .includes(:meal)
              .order(Arel.sql("CASE meal_time WHEN 'breakfast' THEN 0 WHEN 'lunch' THEN 1 WHEN 'dinner' THEN 2 END"))
          end
        end

        def daily_control_today
          @user.daily_controls.find_by(date: Date.today)
        end

        def logged_symptom_score(symptom_type)
          @user.symptom_logs
            .where(symptom_type: symptom_type)
            .where(logged_at: Date.today.beginning_of_day..Date.today.end_of_day)
            .order(logged_at: :desc)
            .first&.score
        end

        def meal_summary(meal)
          ingredients = meal.ingredients.limit(3).pluck(:name)
          ingredients.any? ? ingredients.join(", ") : "(no ingredients)"
        end

        def rating_bar(score)
          return "—" unless score
          "#{("█" * score)}#{("░" * (5 - score))} #{score}/5"
        end

        def clamp_int(str, min, max)
          val = str.to_i
          val.between?(min, max) ? val : nil
        end
      end
    end
  end
end
