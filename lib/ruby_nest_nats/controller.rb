require_relative "./utils"

module RubyNestNats
  class Controller
    NO_QUEUE_GIVEN = :ruby_nest_nats_super_special_no_op_queue_symbol_qwertyuiop_1234567890

    class << self
      # Default queue for the controller. Falls back to the client's default
      # queue if the controller's default queue is `nil`.
      #
      # - Call with no argument (`::default_queue`) to get the default queue.
      # - Call as a macro with an argument (`default_queue "something"`) to set
      #   the default queue.
      #
      # Example:
      #
      #     class FoobarNatsController < RubyNatsController
      #       default_queue "foobar"
      #
      #       # ...
      #     end
      #
      def default_queue(some_queue = NO_QUEUE_GIVEN)
        # `NO_QUEUE_GIVEN` is a special symbol (rather than `nil`) so that the
        # default queue can be "unset" to `nil` (given a non-`nil` global
        # default set with `RubyNestNats::Client::default_queue=`).
        if some_queue == NO_QUEUE_GIVEN
          @default_queue || Client.default_queue
        else
          @default_queue = Utils.presence(some_queue.to_s)
        end
      end

      def subject(subject_segment, queue: nil)
        subject_chain.push(subject_segment)
        old_queue = current_queue
        self.current_queue = queue if Utils.present?(queue)
        yield
        self.current_queue = old_queue
        subject_chain.pop
      end

      def response(queue: nil, &block)
        response_queue = Utils.presence(queue.to_s) || current_queue || default_queue
        Client.reply_to(current_subject, queue: response_queue, &block)
      end

      private

      def subject_chain
        @subject_chain ||= []
      end

      def current_subject
        subject_chain.join(".")
      end

      def current_queue
        @current_queue ||= nil
      end

      def current_queue=(some_queue)
        @current_queue = Utils.presence(some_queue)
      end
    end
  end
end
