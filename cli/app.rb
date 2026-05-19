require_relative "screens/onboarding"
require_relative "screens/home"

module Confidente
  module CLI
    class App
      def run
        RatatuiRuby.run do |tui|
          user = if first_run?
            Screens::Onboarding.new(tui).run
          else
            User.first
          end

          next unless user  # user quit during onboarding

          Screens::Home.new(tui, user).run
        end
      end

      private

      def first_run?
        User.none?
      end
    end
  end
end
