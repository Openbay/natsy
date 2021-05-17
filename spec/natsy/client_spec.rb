# frozen_string_literal: true

require "logger"
require "nats/client"
require "timeout"

RSpec.describe Natsy::Client do
  describe "::reply_to=" do
    before do
      Natsy::Config.reset!
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
      Natsy::Config.set(default_queue: "some_queue")
      puts "yeah queue: #{Natsy::Config.default_queue}"
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
      Natsy::Config.set(default_queue: "some_queue")
      described_class.reply_to("some_subject", queue: "own_queue") { "foo" }
      replies = described_class.send(:replies)
      expect(replies).not_to be_empty
      first_reply = replies.first
      expect(first_reply).to be_a(Hash)
      expect(first_reply[:queue]).to eq("own_queue")
    end
  end

  describe "::start!" do
    after do
      described_class.send(:stop!)
      described_class.send(:kill!)
      Natsy::Config.reset!
      described_class.instance_variable_set(:@replies, [])
    end

    it "starts listening for NATS messages" do
      described_class.start!
      expect(described_class.send(:current_thread)).to be_alive
    end

    it "starts listening for subscribed messages" do
      output = StringIO.new
      logger = Logger.new(output)
      logger.level = Logger::DEBUG

      Natsy::Config.set(
        logger: logger,
        default_queue: "whatever",
      )

      described_class.reply_to("some_subject") do
        described_class.send(:log, "I GOT IT!")
        "Here it is!"
      end

      described_class.start!

      sleep 2 # TODO: figure out how to do this without sleeps

      Timeout.timeout(5) do
        NATS.start do
          NATS.request("some_subject", 123, queue: "whatever") do |msg|
            described_class.send(:log, "The reply was '#{msg}'")
            NATS.drain
          end
        end
      end

      sleep 2 # TODO: figure out how to do this without sleeps

      expect(output.string).to include("I GOT IT!")
      expect(output.string).to include("The reply was 'Here it is!'")
    end
  end
end
