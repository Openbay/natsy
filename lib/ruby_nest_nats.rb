# frozen_string_literal: true

require_relative "ruby_nest_nats/version"
require "nats/client"

module RubyNestNats
  class Error < StandardError; end

  class Client
    class << self
      # def init
      #   NATS.start do
      #     NATS.subscribe("foo.bar") { |msg| puts "Msg received : '#{msg}'" }
      #     NATS.publish("foo.bar", 'Foolo Barld!')
      #   end
      # end

      def publish(subject, data)
        NATS.start do
          # NATS.subscribe(subject) { |msg| puts "Response received: '#{msg}'" }
          NATS.publish(subject, data)
          # NATS.stop
        end
      end

      def subscribe(subject)
        NATS.start do
          NATS.subscribe(subject) { |*msg| puts "Message received: '#{msg}'" }
          # NATS.stop
        end
      end

      def request(subject, data)
        NATS.start do
          NATS.subscribe(subject, queue: "whatever") { |msg, reply| puts "Response from subscription received: msg: '#{msg}', reply: '#{reply}'" }
          NATS.request(subject, data) { |response| puts "Response from request received: '#{response}'" }
        end
      end
    end
  end
end
