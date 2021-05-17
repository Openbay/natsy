# frozen_string_literal: true

require "logger"
require "nats/client"

RSpec.describe Natsy::Client do
  describe "::logger=" do
    before do
      described_class.logger = nil
    end

    it "sets the logger" do
      output = StringIO.new
      logger = Logger.new(output)
      described_class.logger = logger
      expect(described_class.logger).to eq(logger)
    end

    it "logs to that logger" do
      output = StringIO.new
      logger = Logger.new(output)
      described_class.logger = logger
      expect do
        described_class.send(:log, "yup it works")
      end.to change(output.string, :length)
      expect(output.string).to include("yup it works")
    end
  end

  describe "::default_queue=" do
    before do
      described_class.default_queue = nil
    end

    it "sets the default queue to the string if given a string" do
      described_class.default_queue = "some_queue"
      expect(described_class.default_queue).to eq("some_queue")
    end

    it "sets the default queue to the equivalent string if given a symbol" do
      described_class.default_queue = :some_queue
      expect(described_class.default_queue).to eq("some_queue")
    end

    it "sets the default queue to nil if given nil" do
      described_class.default_queue = nil
      expect(described_class.default_queue).to eq(nil)
    end

    it "sets the default queue to nil if given an empty string" do
      described_class.default_queue = ""
      expect(described_class.default_queue).to eq(nil)
    end
  end

  describe "::reply_to=" do
    before do
      described_class.logger = nil
      described_class.default_queue = nil
      described_class.instance_variable_set(:@replies, [])
    end

    it "adds a valid replier hash to the list of subscribed replies" do
      described_class.reply_to("some_subject") { "foo" }
      replies = described_class.send(:replies)
      expect(replies).not_to be_empty
      first_reply = replies.first
      expect(first_reply).to be_a(Hash)
      expect(first_reply[:subject]).to eq("some_subject")
      expect(first_reply[:queue]).to be_nil
      expect(first_reply[:handler]).to be_a(Proc)
      expect(first_reply[:handler].call).to eq("foo")
    end

    it "requires a block" do
      expect do
        described_class.reply_to("some_subject")
      end.to raise_error(ArgumentError)
    end

    it "falls back on the default queue if none is specified" do
      described_class.default_queue = "some_queue"
      described_class.reply_to("some_subject") { "foo" }
      replies = described_class.send(:replies)
      expect(replies).not_to be_empty
      first_reply = replies.first
      expect(first_reply).to be_a(Hash)
      expect(first_reply[:queue]).to eq("some_queue")
    end

    it "can take its own queue" do
      described_class.reply_to("some_subject", queue: "own_queue") { "foo" }
      replies = described_class.send(:replies)
      expect(replies).not_to be_empty
      first_reply = replies.first
      expect(first_reply).to be_a(Hash)
      expect(first_reply[:queue]).to eq("own_queue")
    end

    it "will use its own queue even if there's a default" do
      described_class.default_queue = "some_queue"
      described_class.reply_to("some_subject", queue: "own_queue") { "foo" }
      replies = described_class.send(:replies)
      expect(replies).not_to be_empty
      first_reply = replies.first
      expect(first_reply).to be_a(Hash)
      expect(first_reply[:queue]).to eq("own_queue")
    end
  end

  describe "::start!" do
    before do
      described_class.send(:stop!)
      described_class.send(:kill!)
      described_class.logger = nil
      described_class.default_queue = nil
      described_class.instance_variable_set(:@replies, [])
    end

    it "starts listening for NATS messages" do
      described_class.start!
      expect(described_class.send(:current_thread)).to be_alive
    end

    it "starts listening for subscribed messages" do
      dumb = nil
      logger = Logger.new(STDOUT)
      logger.level = Logger::DEBUG
      described_class.logger = logger
      described_class.default_queue = "whatever"
      described_class.reply_to("some_subject") { described_class.send(:log, "I GOT IT!"); dumb = "foo" }
      described_class.start!
      sleep 0.5
      received = nil
      puts "HEY RIGHT BEFORE"
      # binding.pry
      NATS.start do
        # described_class.send(:log, "HEY RIGHT BEFORE AGAIN")
        # NATS.request("some_subject", 123) do |msg|
        #   received = msg
        #   described_class.send(:log, "HEY RIGHT HERE")
        #   # NATS.stop
        # end
        NATS.subscribe("some_subject", queue: "whatever") do |msg|
          received = msg
          described_class.send(:log, "HEY RIGHT HERE AGAIN")
          # NATS.stop
        end
        NATS.publish("some_subject", 123, queue: "whatever") do |msg|
          received = msg
          described_class.send(:log, "HEY RIGHT HERE")
          # NATS.stop
        end
      end
      sleep 0.5
      expect(dumb).to eq("foo")
      expect(received).to eq("foo")
    end
  end
end
