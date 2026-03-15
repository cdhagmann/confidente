module Confidente
  module CLI
    module Screens
      # Onboarding screen — first run only.
      # Step 1: Collect name
      # Step 2: Pick sensitivity categories (histamine, FODMAP, etc.)
      # Step 3: Review / refine individual foods (pre-selected from chosen categories)
      # Step 4: Show hypothesis suggestions
      class Onboarding
        HEADER = "Welcome to Confidente".freeze

        def initialize(tui)
          @tui = tui
        end

        def run
          user = collect_name
          return nil unless user

          redo_setup(user)
          user
        end

        # Re-run category + food selection for an existing user (called from Home).
        # Clears previous suspect foods first so the user starts fresh.
        def redo_setup(user)
          user.user_suspect_foods.delete_all
          selected_category_ids = select_categories
          select_suspect_foods(user, selected_category_ids)
          show_hypothesis_suggestions(user)
        end

        private

        # --- Step 1: Name ---

        def collect_name
          input = ""
          error = nil

          loop do
            @tui.draw { |frame| render_name_screen(frame, input, error) }

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "enter" }
              name = input.strip
              if name.empty?
                error = "Name cannot be blank."
              else
                user = User.create(name: name, email: "#{name.downcase.gsub(/\s+/, ".")}@local.confidente")
                return user if user.persisted?
                error = user.errors.full_messages.join(", ")
              end
            in { type: :key, code: "backspace" }
              input = input[0...-1]
              error = nil
            in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
              return nil
            in { type: :key, code: code, modifiers: [] } if code.length == 1
              input += code
              error = nil
            else
              # no-op
            end
          end
        end

        def render_name_screen(frame, input, error)
          areas = @tui.layout_split(frame.area, direction: :vertical, constraints: [
            @tui.constraint_length(2),
            @tui.constraint_fill(1),
            @tui.constraint_length(1),
            @tui.constraint_length(1)
          ])

          frame.render_widget(header_widget("Step 1 of 3 — Who are you?"), areas[0])
          frame.render_widget(
            @tui.paragraph(
              text: "Your name: #{input}_#{error ? "\n\nError: #{error}" : ""}",
              block: @tui.block(title: "Name", borders: [:all], border_type: :rounded)
            ),
            areas[1]
          )
          frame.render_widget(@tui.paragraph(text: ""), areas[2])
          frame.render_widget(hint_widget("[Enter] confirm  [q] quit"), areas[3])
        end

        # --- Step 2: Category selection ---

        def select_categories
          categories = FoodSensitivityCategory.order(:name).to_a
          selected_ids = Set.new
          cursor = 0

          loop do
            @tui.draw { |frame| render_category_selection(frame, categories, selected_ids, cursor) }

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "enter" }
              break
            in { type: :key, code: "c", modifiers: ["ctrl"] }
              exit(0)
            in { type: :key, code: " " }
              cat = categories[cursor]
              if cat
                selected_ids.include?(cat.id) ? selected_ids.delete(cat.id) : selected_ids.add(cat.id)
              end
            in { type: :key, code: "up" }
              cursor = [cursor - 1, 0].max
            in { type: :key, code: "down" }
              cursor = [cursor + 1, categories.size - 1].min
            in { type: :key, code: "a" }
              # Select all / deselect all toggle
              if selected_ids.size == categories.size
                selected_ids.clear
              else
                categories.each { |c| selected_ids.add(c.id) }
              end
            else
              # no-op
            end
          end

          selected_ids
        end

        def render_category_selection(frame, categories, selected_ids, cursor)
          areas = @tui.layout_split(frame.area, direction: :vertical, constraints: [
            @tui.constraint_length(2),
            @tui.constraint_fill(1),
            @tui.constraint_length(1)
          ])

          frame.render_widget(header_widget("Step 2 of 3 — Which categories do you suspect?"), areas[0])

          items = categories.map do |cat|
            mark = selected_ids.include?(cat.id) ? "[x]" : "[ ]"
            "#{mark} #{cat.name.ljust(14)}  #{cat.description.to_s.truncate(50)}"
          end

          frame.render_widget(
            @tui.list(
              items: items,
              selected_index: cursor,
              highlight_symbol: "> ",
              block: @tui.block(
                title: "Sensitivity Categories (#{selected_ids.size} selected)",
                borders: [:all],
                border_type: :rounded
              )
            ),
            areas[1]
          )
          frame.render_widget(
            hint_widget("[↑↓] navigate  [Space] toggle  [a] select all  [Enter] next"),
            areas[2]
          )
        end

        # --- Step 3: Food review (pre-populated from categories) ---

        def select_suspect_foods(user, selected_category_ids)
          all_foods = Food.order(:name).to_a

          # Pre-select foods that belong to any of the chosen categories
          pre_selected = if selected_category_ids.any?
            Food.joins(:food_category_memberships)
              .where(food_category_memberships: { food_sensitivity_category_id: selected_category_ids.to_a })
              .pluck(:id).to_set
          else
            Set.new
          end

          selected_ids = pre_selected.dup
          search_query = ""
          cursor = 0

          loop do
            filtered = filter_foods(all_foods, search_query)
            cursor = cursor.clamp(0, [filtered.size - 1, 0].max)

            @tui.draw { |frame| render_food_selection(frame, filtered, selected_ids, pre_selected, cursor, search_query) }

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "enter" }
              break
            in { type: :key, code: "c", modifiers: ["ctrl"] }
              exit(0)
            in { type: :key, code: " " }
              food = filtered[cursor]
              if food
                selected_ids.include?(food.id) ? selected_ids.delete(food.id) : selected_ids.add(food.id)
              end
            in { type: :key, code: "up" }
              cursor = [cursor - 1, 0].max
            in { type: :key, code: "down" }
              cursor = [cursor + 1, filtered.size - 1].min
            in { type: :key, code: "backspace" }
              search_query = search_query[0...-1]
              cursor = 0
            in { type: :key, code: code, modifiers: [] } if code.length == 1
              search_query += code
              cursor = 0
            else
              # no-op
            end
          end

          selected_ids.each do |food_id|
            UserSuspectFood.find_or_create_by!(user: user, food_id: food_id) do |usf|
              usf.added_at = Time.current
            end
          end
        end

        def filter_foods(foods, query)
          return foods if query.empty?
          q = query.downcase
          foods.select { |f| f.name.downcase.include?(q) }
        end

        def render_food_selection(frame, foods, selected_ids, pre_selected, cursor, search_query)
          areas = @tui.layout_split(frame.area, direction: :vertical, constraints: [
            @tui.constraint_length(2),
            @tui.constraint_length(1),
            @tui.constraint_fill(1),
            @tui.constraint_length(1)
          ])

          frame.render_widget(header_widget("Step 3 of 3 — Review your suspect foods"), areas[0])
          frame.render_widget(
            @tui.paragraph(text: "Search: #{search_query}_  (pre-filled from your category choices)"),
            areas[1]
          )

          items = foods.map do |food|
            mark = selected_ids.include?(food.id) ? "[x]" : "[ ]"
            # Show a dot for category-pre-selected foods so user knows why they're checked
            origin = pre_selected.include?(food.id) ? "·" : " "
            "#{mark}#{origin} #{food.name}"
          end

          frame.render_widget(
            @tui.list(
              items: items,
              selected_index: cursor,
              highlight_symbol: "> ",
              block: @tui.block(
                title: "Foods (#{selected_ids.size} selected  · = from your categories)",
                borders: [:all],
                border_type: :rounded
              )
            ),
            areas[2]
          )
          frame.render_widget(
            hint_widget("[↑↓] navigate  [Space] toggle  [type] search  [Enter] done"),
            areas[3]
          )
        end

        # --- Step 4: Hypothesis suggestions ---

        def show_hypothesis_suggestions(user)
          suggestions = HypothesisEngine.new(user).call
          return if suggestions.empty?

          loop do
            @tui.draw { |frame| render_suggestions(frame, suggestions) }

            case @tui.poll_event(timeout: 0.05)
            in { type: :key, code: "enter" } | { type: :key, code: "q" } | { type: :key, code: "esc" }
              break
            else
              # no-op
            end
          end
        end

        def render_suggestions(frame, suggestions)
          areas = @tui.layout_split(frame.area, direction: :vertical, constraints: [
            @tui.constraint_length(2),
            @tui.constraint_fill(1),
            @tui.constraint_length(1)
          ])

          frame.render_widget(header_widget("Other foods worth watching"), areas[0])

          items = suggestions.map do |s|
            "#{s.suggested_food.name}  — shares #{s.reason_category.name} with your suspects"
          end

          frame.render_widget(
            @tui.list(
              items: items,
              block: @tui.block(title: "Suggestions (#{suggestions.size})", borders: [:all], border_type: :rounded)
            ),
            areas[1]
          )
          frame.render_widget(hint_widget("[Enter] start tracking"), areas[2])
        end

        # --- Shared ---

        def header_widget(subtitle)
          @tui.paragraph(
            text: "#{HEADER} — #{subtitle}",
            alignment: :center
          )
        end

        def hint_widget(text)
          @tui.paragraph(text: text, alignment: :center)
        end
      end
    end
  end
end
