require_relative "onboarding"
require_relative "today_tab"
require_relative "week_plan_tab"
require_relative "report_tab"

module Confidente
  module CLI
    module Screens
      # Home screen — tab-based navigation: Today | Week Plan | Report
      class Home
        TABS = ["Today", "Week Plan", "Report"].freeze

        def initialize(tui, user)
          @tui = tui
          @user = user
          @active_tab = 0
          @show_help = false
        end

        def run
          ensure_active_plan

          tabs = [
            TodayTab.new(@tui, @user),
            WeekPlanTab.new(@tui, @user),
            ReportTab.new(@tui, @user)
          ]

          loop do
            @tui.draw { |frame| render(frame, tabs) }

            event = @tui.poll_event(timeout: 0.05)
            break if handle_event(event, tabs) == :quit
          end
        end

        private

        def ensure_active_plan
          active = @user.meal_plans.where("ends_on >= ?", Date.today).first
          return if active

          MealPlanGenerator.new(@user, start_date: Date.today).call
        end

        def render(frame, tabs)
          if @show_help
            render_help(frame)
            return
          end

          areas = @tui.layout_split(
            frame.area,
            direction: :vertical,
            constraints: [
              @tui.constraint_length(3),
              @tui.constraint_fill(1),
              @tui.constraint_length(1)
            ]
          )

          tabs_widget = @tui.tabs(
            titles: TABS,
            selected_index: @active_tab,
            divider: " | ",
            block: @tui.block(title: "Confidente", borders: [:all], border_type: :rounded)
          )
          frame.render_widget(tabs_widget, areas[0])

          tabs[@active_tab].render(frame, areas[1])

          frame.render_widget(
            @tui.paragraph(text: "[Tab] switch  [r] redo setup  [q] quit  [?] help", alignment: :center),
            areas[2]
          )
        end

        def handle_event(event, tabs)
          if @show_help
            case event
            in { type: :key, code: "q" } | { type: :key, code: "?" } | { type: :key, code: "enter" } | { type: :key, code: "esc" }
              @show_help = false
            else
              # no-op
            end
            return
          end

          case event
          in { type: :key, code: "tab" }
            @active_tab = (@active_tab + 1) % TABS.size
          in { type: :key, code: "q" } | { type: :key, code: "c", modifiers: ["ctrl"] }
            return :quit
          in { type: :key, code: "?" }
            @show_help = true
          in { type: :key, code: "r" }
            Onboarding.new(@tui).redo_setup(@user)
          else
            tabs[@active_tab].handle_event(event)
          end
        end

        def render_help(frame)
          help_text = <<~HELP
            Confidente — Key Bindings

            [Tab]        Switch between Today / Week Plan / Report tabs
            [↑↓]         Navigate lists
            [Enter]      Confirm / log item
            [Space]      Toggle / select
            [m]          Go to Meals section
            [c]          Log daily check-in
            [s]          Log symptoms
            [e]          Mark meal as eaten
            [o]          Log off-plan meal
            [r]          Redo category & food setup
            [q]          Quit
            [?]          Show / hide this help

            Off-plan meals are just more data — not failures.
          HELP

          frame.render_widget(
            @tui.paragraph(
              text: help_text,
              block: @tui.block(title: "Help  [Enter/q/?] close", borders: [:all], border_type: :rounded)
            ),
            frame.area
          )
        end
      end
    end
  end
end
