# frozen_string_literal: true

require_relative "./utils"

module RubyNestNats
  # Create controller classes which inherit from `RubyNestNats::Controller` in
  # order to give your message listeners some structure.
  class Controller
    NO_QUEUE_GIVEN = :ruby_nest_nats_super_special_no_op_queue_symbol_qwertyuiop1234567890

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
      # If omitted, the controller will fall back on the global default queue
      # assigned with `RubyNestNats::Client::default_queue=`. If no default
      # queue is set in either the controller or globally, then the default
      # queue will be blank. Set the default queue to `nil` in a controller to
      # override the global default queue and explicitly make the default queue
      # blank for that controller.
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

      # Use the `::subject` macro to create a block for listening to that
      # subject segment. Nested calls to `::subject` will append each subsequent
      # subject/pattern string to the last (joined by a periods). There is no
      # limit to the level of nesting.
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # Example:
      #
      #     class FoobarNatsController < RubyNatsController
      #       # ...
      #
      #       subject "hello.wassup" do
      #         response do |data, subject|
      #           # The subject at this point is "hello.wassup"
      #           # ...
      #         end
      #       end
      #
      #       subject "hello.howdy" do
      #         response do |data, subject|
      #           # The subject at this point is "hello.howdy"
      #           # ...
      #         end
      #       end
      #     end
      #
      # Example:
      #
      #     class FoobarNatsController < RubyNatsController
      #       # ...
      #
      #       subject "hello" do
      #         subject "wassup" do
      #           response do |data, subject|
      #             # The subject at this point is "hello.wassup"
      #             # ...
      #           end
      #         end
      #
      #         subject "howdy" do
      #           response do |data, subject|
      #             # The subject at this point is "hello.howdy"
      #             # ...
      #           end
      #         end
      #       end
      #     end
      #
      def subject(subject_segment, queue: nil)
        subject_chain.push(subject_segment)
        old_queue = current_queue
        self.current_queue = queue if Utils.present?(queue)
        yield
        self.current_queue = old_queue
        subject_chain.pop
      end

      # You can register a response for the built-up subject/pattern string
      # using the `::response` macro. Pass a block to `::response` which
      # optionally takes two arguments (the same arguments supplied to the block
      # of `RubyNestNats::Client::reply_to`). The result of that block will be
      # sent as a response to the message received.
      #
      # Example:
      #
      #     class FoobarNatsController < RubyNatsController
      #       # ...
      #
      #       subject "hello" do
      #         subject "wassup" do
      #           response do |data, subject|
      #             # The subject at this point is "hello.wassup".
      #             # Assume the message sent a JSON payload of {"name":"Bob"}
      #             # in this example.
      #             # We'll reply with a string response:
      #             "I'm all right, #{data['name']}"
      #           end
      #         end
      #
      #         subject "howdy" do
      #           response do |data, subject|
      #             # The subject at this point is "hello.howdy".
      #             # Assume the message sent a JSON payload of {"name":"Bob"}
      #             # in this example.
      #             # We'll reply with a JSON response (a Ruby `Hash`):
      #             { message: "I'm okay, #{data['name']}. Thanks for asking!" }
      #           end
      #         end
      #       end
      #     end
      #
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
