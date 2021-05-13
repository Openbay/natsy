# frozen_string_literal: true

module RubyNestNats
  class Utils # :nodoc:
    class << self
      def blank?(value)
        value.respond_to?(:empty?) ? value.empty? : !value
      end

      def present?(value)
        !blank?(value)
      end

      def presence(value)
        present?(value) ? value : nil
      end
    end
  end
end
