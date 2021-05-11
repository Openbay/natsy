# frozen_string_literal: true

require_relative "ruby_nest_nats/version"
require "nats/client"

module RubyNestNats
  class Error < StandardError; end

  class Client
    class << self
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
        !!@started
      end

      def reply_to(raw_subject, with:)
        subject = raw_subject.to_s

        if started?
          raise StandardError, "NATS already started"
        elsif !with.respond_to?(:call)
          raise ArgumentError, "Option `:with` must be callable"
        elsif replies.any? { |reply| reply[:subject] == subject }
          raise ArgumentError, "Already registered a reply to #{subject}"
        end

        replies << { subject: subject, handler: with, queue: queue }
      end

      def start!
        @started = true

        fiber = Fiber.new do
          NATS.start do
            replies.each do |replier|
              NATS.subscribe(replier[:subject], queue: reply[:queue]) do |message, reply, _subject|
                response = replier[:handler].call(JSON.parse(message)["data"])
                NATS.publish(reply, response.to_json, queue: reply[:queue])
              end
            end
          end
        end

        fiber.resume
      end
    end
  end
end
