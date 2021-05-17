# frozen_string_literal: true

module Natsy
  # Some internal utility methods
  class Utils
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

      def log(logger, text, level: :info, indent: 0)
        return unless logger

        timestamp = Time.now.to_s
        text_lines = text.split("\n")
        indentation = indent.is_a?(String) ? indent : (" " * indent)

        text_lines.each do |line|
          logger.send(level, "[#{timestamp}] Natsy | #{indentation}#{line}")
        end

        nil
      end
    end
  end
end
