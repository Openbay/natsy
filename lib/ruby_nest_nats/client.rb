# frozen_string_literal: true

require "json"
require "nats/client"
require_relative "./utils"

module RubyNestNats
  # The +RubyNestNats::Client+ class provides a basic interface for subscribing
  # to messages by subject & queue, and replying to those messages. It also logs
  # most functionality if desired.
  class Client
    class << self
      # Optional logger for lifecycle events, messages received, etc.
      attr_reader :logger

      # Optional default queue for message subscription and replies.
      attr_reader :default_queue

      # Attach a logger to have +ruby_nest_nats+ write out logs for messages
      # received, responses sent, errors raised, lifecycle events, etc.
      #
      # @example
      #   require 'ruby_nest_nats'
      #   require 'logger'
      #
      #   nats_logger = Logger.new(STDOUT)
      #   nats_logger.level = Logger::INFO
      #
      #   RubyNestNats::Client.logger = nats_logger
      #
      # In a Rails application, you might do this instead:
      #
      # @example
      #   RubyNestNats::Client.logger = Rails.logger
      #
      def logger=(some_logger)
        @logger = some_logger
        log("Set the logger to #{@logger.inspect}")
      end

      # Set a default queue for subscriptions.
      #
      # @example
      #   RubyNestNats::Client.default_queue = "foobar"
      #
      # Leave the +::default_queue+ blank (or assign +nil+) to use no default
      # queue.
      #
      # @example
      #   RubyNestNats::Client.default_queue = nil
      #
      def default_queue=(some_queue)
        @default_queue = Utils.presence(some_queue.to_s)
        log("Setting the default queue to #{@default_queue || '(none)'}", level: :debug)
      end

      # Returns +true+ if +::start!+ has already been called (meaning the client
      # is listening to NATS messages). Returns +false+ if it has not yet been
      # called, or if it has been stopped.
      def started?
        @started ||= false
      end

      # Opposite of +::started?+: returns +false+ if +::start!+ has already been
      # called (meaning the client is listening to NATS messages). Returns
      # +true+ if it has not yet been called, or if it has been stopped.
      def stopped?
        !started?
      end

      # Register a message handler with the +RubyNestNats::Client::reply_to+
      # method. Pass a subject string as the first argument (either a static
      # subject string or a pattern to match more than one subject). Specify a
      # queue (or don't) with the +queue:+ option. If you don't provide the
      # +queue:+ option, it will be set to the value of +default_queue+, or to
      # +nil+ (no queue) if a default queue hasn't been set.
      #
      # The result of the given block will be published in reply to the message.
      # The block is passed two arguments when a message matching the subject is
      # received: +data+ and +subject+. The +data+ argument is the payload of
      # the message (JSON objects/arrays will be parsed into string-keyed +Hash+
      # objects/+Array+ objects, respectively). The +subject+ argument is the
      # subject of the message received (mostly only useful if a _pattern_ was
      # specified instead of a static subject string).
      #
      # @example
      #   RubyNestNats::Client.reply_to("some.subject", queue: "foobar") { |data| "Got it! #{data.inspect}" }
      #
      #   RubyNestNats::Client.reply_to("some.*.pattern") { |data, subject| "Got #{data} on #{subject}" }
      #
      #   RubyNestNats::Client.reply_to("other.subject") do |data|
      #     if data["foo"] == "bar"
      #       { is_bar: "Yep!" }
      #     else
      #       { is_bar: "No way!" }
      #     end
      #   end
      #
      #   RubyNestNats::Client.reply_to("subject.in.queue", queue: "barbaz") do
      #     "My turn!"
      #   end
      #
      def reply_to(subject, queue: nil, &block)
        queue = Utils.presence(queue) || default_queue
        queue_desc = " in queue '#{queue}'" if queue
        log("Registering a reply handler for subject '#{subject}'#{queue_desc}", level: :debug)
        register_reply!(subject: subject.to_s, handler: block, queue: queue.to_s)
      end

      # Start listening for messages with the +RubyNestNats::Client::start!+
      # method. This will spin up a non-blocking thread that subscribes to
      # subjects (as specified by invocation(s) of +::reply_to+) and waits for
      # messages to come in. When a message is received, the appropriate
      # +::reply_to+ block will be used to compute a response, and that response
      # will be published.
      #
      # @example
      #   RubyNestNats::Client.start!
      #
      # **NOTE:** If an error is raised in one of the handlers,
      # +RubyNestNats::Client+ will restart automatically.
      #
      # **NOTE:** You _can_ invoke +::reply_to+ to create additional message
      # subscriptions after +RubyNestNats::Client.start!+, but be aware that
      # this forces the client to restart. You may see (benign, already-handled)
      # errors in the logs generated when this restart happens. It will force
      # the client to restart and re-subscribe after _each additional
      # +::reply_to+ invoked after +::start!+._ So, if you have a lot of
      # additional +::reply_to+ invocations, you may want to consider
      # refactoring so that your call to +RubyNestNats::Client.start!+ occurs
      # _after_ those additions.
      #
      # **NOTE:** The +::start!+ method can be safely called multiple times;
      # only the first will be honored, and any subsequent calls to +::start!+
      # after the client is already started will do nothing (except write a
      # _"NATS is already running"_ log to the logger at the +DEBUG+ level).
      #
      def start!
        log("Starting NATS", level: :debug)

        if started?
          log("NATS is already running", level: :debug)
          return
        end

        started!

        self.current_thread = Thread.new do
          Thread.handle_interrupt(StandardError => :never) do
            Thread.handle_interrupt(StandardError => :immediate) { listen }
          rescue NATS::ConnectError => e
            log("Could not connect to NATS server:", level: :error)
            log(e.full_message, level: :error, indent: 2)
            Thread.current.exit
          rescue NewSubscriptionsError => e
            log("New subscriptions! Restarting...", level: :info)
            restart!
            raise e # TODO: there has to be a better way
          rescue StandardError => e
            log("Encountered an error:", level: :error)
            log(e.full_message, level: :error, indent: 2)
            restart!
            raise e
          end
        end
      end

      private

      attr_accessor :current_thread

      def log(text, level: :info, indent: 0)
        return unless logger

        timestamp = Time.now.to_s
        text_lines = text.split("\n")
        indentation = indent.is_a?(String) ? indent : (" " * indent)

        text_lines.each do |line|
          logger.send(level, "[#{timestamp}] RubyNestNats | #{indentation}#{line}")
        end
      end

      def kill!
        current_thread.kill if current_thread && current_thread.alive?
      end

      def stop!
        log("Stopping NATS", level: :debug)

        begin
          NATS.stop
        rescue StandardError
          nil
        end

        stopped!
      end

      def restart!
        log("Restarting NATS", level: :warn)
        stop!
        start!
      end

      def started!
        @started = true
      end

      def stopped!
        @started = false
      end

      def replies
        @replies ||= []
      end

      def reply_registered?(raw_subject)
        subject = raw_subject.to_s
        replies.any? { |reply| reply[:subject] == subject }
      end

      def register_reply!(subject:, handler:, queue: nil)
        raise ArgumentError, "Subject must be a string" unless subject.is_a?(String)
        raise ArgumentError, "Must provide a message handler for #{subject}" unless handler.respond_to?(:call)
        raise ArgumentError, "Already registered a reply to #{subject}" if reply_registered?(subject)

        reply = {
          subject: subject,
          handler: handler,
          queue: Utils.presence(queue) || default_queue,
        }

        replies << reply

        current_thread.raise(NewSubscriptionsError, "New reply registered") if started?
      end

      def listen
        NATS.start do
          replies.each do |replier|
            queue_desc = " in queue '#{replier[:queue]}'" if replier[:queue]
            log("Subscribing to subject '#{replier[:subject]}'#{queue_desc}", level: :debug)

            NATS.subscribe(replier[:subject], queue: replier[:queue]) do |message, inbox, subject|
              parsed_message = JSON.parse(message)
              id, data, pattern = parsed_message.values_at("id", "data", "pattern")

              log("Received a message!")
              message_desc = <<~LOG_MESSAGE
                id:      #{id || '(none)'}
                pattern: #{pattern || '(none)'}
                subject: #{subject || '(none)'}
                data:    #{data.to_json}
                inbox:   #{inbox || '(none)'}
              LOG_MESSAGE
              log(message_desc, indent: 2)

              response_data = replier[:handler].call(data)

              log("Responding with '#{response_data}'")

              NATS.publish(inbox, response_data.to_json, queue: replier[:queue])
            end
          end
        end
      end
    end
  end
end
