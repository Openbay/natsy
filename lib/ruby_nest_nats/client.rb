require "json"
require "nats/client"
require_relative "./utils"

module RubyNestNats
  class Client
    class << self
      def logger=(some_logger)
        log("Setting the logger to #{some_logger.inspect}")
        @logger = some_logger
      end

      def logger
        @logger
      end

      def default_queue=(some_queue)
        queue = Utils.presence(some_queue.to_s)
        log("Setting the default queue to #{queue || '(none)'}", level: :debug)
        @default_queue = queue
      end

      def default_queue
        @default_queue
      end

      def started?
        @started ||= false
      end

      def stopped?
        !started?
      end

      def reply_to(subject, queue: nil, &block)
        queue = Utils.presence(queue) || default_queue
        log("Registering a reply handler for subject '#{subject}'#{" in queue '#{queue}'" if queue}", level: :debug)
        register_reply!(subject: subject.to_s, handler: block, queue: queue.to_s)
      end

      def thread_queue
        @thread_queue ||= Queue.new
      end

      def current_thread
        @current_thread
      end

      def current_thread=(some_thread)
        @current_thread = some_thread
      end

      def listen
        NATS.start do
          replies.each do |replier|
            log("Subscribing to subject '#{replier[:subject]}'#{" in queue '#{replier[:queue]}'" if replier[:queue]}", level: :debug)

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

          # while thing = thread_queue.pop
          #   log("found queued thing: #{thing}")
          # end
        end
      end

      def stop!
        log("Stopping NATS", level: :debug)
        NATS.stop rescue nil
        stopped!
      end

      def restart!
        log("Restarting NATS", level: :warn)
        stop!
        start!
      end

      def start!
        log("Starting NATS", level: :debug)

        if started?
          log("NATS is already running", level: :debug)
          return
        end

        started!

        self.current_thread = Thread.new do
          Thread.handle_interrupt(StandardError => :never) do
            begin
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
      end

      private

      def log(text, level: :info, indent: 0)
        return unless logger

        timestamp = Time.now.to_s
        text_lines = text.split("\n")
        indentation = indent.is_a?(String) ? indent : (" " * indent)

        text_lines.each do |line|
          logger.send(level, "[#{timestamp}] RubyNestNats | #{indentation}#{line}")
        end
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
        # if started?
        #   thread_queue.push("subject: #{subject}, handler: #{handler}, queue: #{queue}")
        #   return
        # end
        # raise StandardError, "NATS already started" if started? # TODO: remove when runtime additions are implemented
        raise ArgumentError, "Subject must be a string" unless subject.is_a?(String)
        raise ArgumentError, "Must provide a message handler for #{subject}" unless handler.respond_to?(:call)
        raise ArgumentError, "Already registered a reply to #{subject}" if reply_registered?(subject)

        reply = {
          subject: subject,
          handler: handler,
          queue: Utils.presence(queue) || default_queue
        }

        replies << reply

        self.current_thread.raise(NewSubscriptionsError, "New reply registered") if started?
      end
    end
  end
end
