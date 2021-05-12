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

      def log(text)
        logger.info("RubyNestNats | #{text}") if logger
      end

      def queue=(some_queue)
        @queue = some_queue.to_s
      end

      def queue
        @queue
      end

      def replies
        @replies ||= []
      end

      def started?
        @started ||= false
      end

      def reply_to(raw_subject, &block)
        subject = raw_subject.to_s

        if started?
          raise StandardError, "NATS already started"
        elsif !block_given?
          raise ArgumentError, "Response block must be provided"
        elsif replies.any? { |reply| reply[:subject] == subject }
          raise ArgumentError, "Already registered a reply to #{subject}"
        end

        log("Registering a reply handler for subject '#{subject}'#{" in queue '#{queue}'" if queue}")
        replies << { subject: subject, handler: block, queue: queue }
      end

      def listen
        NATS.start do
          replies.each do |replier|
            NATS.subscribe(replier[:subject], queue: replier[:queue]) do |message, inbox, subject|
              log("Received the message '#{message}' for subject '#{subject}' with reply inbox '#{inbox}'")
              response = replier[:handler].call(JSON.parse(message)["data"])
              log("Responding with '#{response}'")
              NATS.publish(inbox, response.to_json, queue: replier[:queue])
            end
          end
        end
      end

      def stop!
        log("Stopping NATS")
        NATS.stop
        @started = false
      end

      def restart!
        log("Restarting NATS...")
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
            ensure
              restart!
            end
          end
        end
      end
    end
  end
end
