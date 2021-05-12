# frozen_string_literal: true

require_relative "ruby_nest_nats/version"
require "nats/client"

module RubyNestNats
  class Error < StandardError; end

  class Client
    class << self
      def logger=(some_logger)
        @logger = some_logger
      end

      def logger
        @logger
      end

      def log(text, level: :info)
        logger.send(level, "[#{Time.now}] RubyNestNats | #{text}") if logger
      end

      def default_queue=(some_queue)
        @default_queue = some_queue.to_s
      end

      def default_queue
        @default_queue
      end

      def replies
        @replies ||= []
      end

      def started?
        @started ||= false
      end

      def reply_to(raw_subject, queue: self.default_queue, &block)
        subject = raw_subject.to_s
        already_registered = replies.any? { |reply| reply[:subject] == subject }

        raise ArgumentError, "Already registered a reply to #{subject}" if already_registered
        raise StandardError, "NATS already started" if started?
        raise ArgumentError, "Response block must be provided" if !block_given?

        log("Registering a reply handler for subject '#{subject}'#{" in queue '#{queue}'" if queue}")
        replies << { subject: subject, handler: block, queue: queue }
      end

      def listen
        NATS.start do
          replies.each do |replier|
            NATS.subscribe(replier[:subject], queue: replier[:queue]) do |message, inbox, subject|
              parsed_message = JSON.parse(message)
              id, data = parsed_message.values_at("id", "data")

              log("Received a message!")
              log("  subject: #{subject}")
              log("  data:    #{data.to_json}")
              log("  id:      #{id}")
              log("  inbox:   #{inbox}")

              response_data = replier[:handler].call(data)

              log("Responding with '#{response_data}'")

              NATS.publish(inbox, response_data.to_json, queue: replier[:queue])
            end
          end
        end
      end

      def stop!
        log("Stopping NATS")

        NATS.stop rescue nil
        @started = false
      end

      def restart!
        stop!
        start!
      end

      def start!
        log("Starting NATS")

        return log("NATS is already running") if started?

        @started = true

        Thread.new do
          Thread.handle_interrupt(StandardError => :never) do
            begin
              Thread.handle_interrupt(StandardError => :immediate) { listen }
            rescue => e
              log("Encountered an error: #{e.message} (#{e.class})", level: :error)
              e.backtrace.each { |line| log("  #{line}", level: :error) }

              restart!
              raise e
            end
          end
        end
      end
    end
  end
end
