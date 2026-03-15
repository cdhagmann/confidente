module Confidente
  module CLI
    module Screens
      # Report tab — bar chart of top 10 ingredients by correlation score
      # plus a plain-language summary.
      class ReportTab
        LOW_DATA_THRESHOLD_DAYS = 14

        def initialize(tui, user)
          @tui = tui
          @user = user
          @correlations = nil
          @loaded_at = nil
        end

        def render(frame, area)
          refresh_correlations if stale?

          areas = @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              @tui.constraint_percentage(55),
              @tui.constraint_fill(1)
            ]
          )
          render_chart(frame, areas[0])
          render_summary(frame, areas[1])
        end

        def handle_event(_event)
          # Report is read-only; no interaction needed
        end

        private

        def refresh_correlations
          @correlations = SymptomCorrelator.new(
            @user,
            start_date: 30.days.ago.to_date,
            end_date: Date.today
          ).call
          @loaded_at = Time.current
        end

        def stale?
          @correlations.nil? || @loaded_at.nil? || @loaded_at < 60.seconds.ago
        end

        def render_chart(frame, area)
          top10 = (@correlations || {}).first(10)

          if top10.empty?
            frame.render_widget(
              @tui.paragraph(
                text: "No data yet. Log some meals and symptoms to see your report.",
                block: @tui.block(title: "Correlation Chart", borders: [:all], border_type: :rounded)
              ),
              area
            )
            return
          end

          # BarChart expects a hash of label => value
          # Scale scores (0.0–5.0) to integers for display
          data = top10.each_with_object({}) do |(_id, entry), h|
            label = entry[:ingredient].name.truncate(12)
            h[label] = (entry[:score] * 100).round
          end

          frame.render_widget(
            @tui.bar_chart(
              data: data,
              direction: :vertical,
              bar_width: 5,
              bar_gap: 1,
              block: @tui.block(title: "Top Ingredients by Symptom Correlation", borders: [:all], border_type: :rounded)
            ),
            area
          )
        end

        def render_summary(frame, area)
          correlations = @correlations || {}
          days_with_data = days_logged

          lines = []

          if correlations.empty?
            lines << "Not enough data yet."
            lines << "Keep logging your meals and symptoms — patterns will emerge."
          else
            strong   = correlations.select { |_, v| v[:score] >= 3.0 }
            moderate = correlations.select { |_, v| v[:score] >= 1.5 && v[:score] < 3.0 }

            unless strong.empty?
              names = strong.first(3).map { |_, v| v[:ingredient].name }.join(", ")
              lines << "You seem to react strongly to: #{names}"
            end

            unless moderate.empty?
              names = moderate.first(3).map { |_, v| v[:ingredient].name }.join(", ")
              lines << "Moderate signal for: #{names}"
            end

            lines << "" << "Based on #{days_with_data} day(s) of logged data."

            if days_with_data < LOW_DATA_THRESHOLD_DAYS
              lines << ""
              lines << "Note: #{LOW_DATA_THRESHOLD_DAYS - days_with_data} more day(s) of logging will improve confidence."
            end
          end

          frame.render_widget(
            @tui.paragraph(
              text: lines.join("\n"),
              block: @tui.block(title: "Summary", borders: [:all], border_type: :rounded)
            ),
            area
          )
        end

        def days_logged
          @user.symptom_logs
            .where(logged_at: 30.days.ago.beginning_of_day..Time.current)
            .group("DATE(logged_at)")
            .count
            .size
        end
      end
    end
  end
end
