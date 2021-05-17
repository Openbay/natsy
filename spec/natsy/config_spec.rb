# frozen_string_literal: true

require "logger"

RSpec.describe Natsy::Config do
  describe "setting the logger" do
    before do
      described_class.reset!
    end

    it "sets the logger using keyword arguments" do # rubocop:disable RSpec/RepeatedExample
      expect(described_class.logger).to be_nil
      output = StringIO.new
      logger = Logger.new(output)
      described_class.set(logger: logger)
      expect(described_class.logger).to eq(logger)
    end

    it "sets the logger using a Hash" do # rubocop:disable RSpec/RepeatedExample
      expect(described_class.logger).to be_nil
      output = StringIO.new
      logger = Logger.new(output)
      described_class.set({ logger: logger })
      expect(described_class.logger).to eq(logger)
    end

    it "sets the logger using a block" do
      expect(described_class.logger).to be_nil
      output = StringIO.new
      logger = Logger.new(output)
      described_class.set do |options|
        options.logger = logger
      end
      expect(described_class.logger).to eq(logger)
    end

    it "logs to that logger" do
      output = StringIO.new
      logger = Logger.new(output)
      logger.level = Logger::DEBUG
      described_class.set(logger: logger)
      expect { Natsy::Client.send(:log, "yup it works") }.to change(output.string, :length)
      expect(output.string).to include("yup it works")
    end
  end

  describe "setting the default queue" do
    before do
      described_class.reset!
    end

    context "when given as a keyword argument" do
      it "sets the default queue to the string if given a string" do
        expect(described_class.default_queue).to be_nil
        described_class.set(default_queue: "some_queue")
        expect(described_class.default_queue).to eq("some_queue")
      end

      it "sets the default queue to the equivalent string if given a symbol" do
        expect(described_class.default_queue).to be_nil
        described_class.set(default_queue: :some_queue)
        expect(described_class.default_queue).to eq("some_queue")
      end

      it "sets the default queue to nil if given nil" do
        expect(described_class.default_queue).to be_nil
        described_class.set(default_queue: nil)
        expect(described_class.default_queue).to eq(nil)
      end

      it "sets the default queue to nil if given an empty string" do
        expect(described_class.default_queue).to be_nil
        described_class.set(default_queue: "")
        expect(described_class.default_queue).to eq(nil)
      end
    end

    context "when given as a block-set option" do
      it "sets the default queue to the string if given a string" do
        expect(described_class.default_queue).to be_nil
        described_class.set { |options| options.default_queue = "some_queue" }
        expect(described_class.default_queue).to eq("some_queue")
      end

      it "sets the default queue to the equivalent string if given a symbol" do
        expect(described_class.default_queue).to be_nil
        described_class.set { |options| options.default_queue = :some_queue }
        expect(described_class.default_queue).to eq("some_queue")
      end

      it "sets the default queue to nil if given nil" do
        expect(described_class.default_queue).to be_nil
        described_class.set { |options| options.default_queue = nil }
        expect(described_class.default_queue).to eq(nil)
      end

      it "sets the default queue to nil if given an empty string" do
        expect(described_class.default_queue).to be_nil
        described_class.set { |options| options.default_queue = "" }
        expect(described_class.default_queue).to eq(nil)
      end
    end
  end

  describe "::urls" do
    before do
      described_class.reset!
    end

    it "has a single URL (the default) if not set" do
      expect(described_class.urls.count).to eq(1)
      expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
    end

    context "when set via keyword argument" do
      it "can be set to a single URL with `url`" do
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        described_class.set(url: "nats://foo.bar:5000")
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq("nats://foo.bar:5000")
      end

      it "can be set to multiple URLs with `urls`" do
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        described_class.set(urls: ["nats://foo.bar:5000", "nats://foo.bar:5001"])
        expect(described_class.urls.count).to eq(2)
        expect(described_class.urls[0]).to eq("nats://foo.bar:5000")
        expect(described_class.urls[1]).to eq("nats://foo.bar:5001")
      end

      it "merges the URLs into one list when both `url` and `urls` are provided" do
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        described_class.set(
          url: "nats://foo.bar:5000",
          urls: ["nats://foo.bar:5001", "nats://foo.bar:5002"],
        )
        expect(described_class.urls.count).to eq(3)
        expect(described_class.urls[0]).to eq("nats://foo.bar:5000")
        expect(described_class.urls[1]).to eq("nats://foo.bar:5001")
        expect(described_class.urls[2]).to eq("nats://foo.bar:5002")
      end
    end

    context "when set via block assignment" do
      it "can be set to a single URL with `url`" do
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        described_class.set do |options|
          options.url = "nats://foo.bar:5000"
        end
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq("nats://foo.bar:5000")
      end

      it "can be set to multiple URLs with `urls`" do
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        described_class.set do |options|
          options.urls = ["nats://foo.bar:5000", "nats://foo.bar:5001"]
        end
        expect(described_class.urls.count).to eq(2)
        expect(described_class.urls[0]).to eq("nats://foo.bar:5000")
        expect(described_class.urls[1]).to eq("nats://foo.bar:5001")
      end

      it "merges the URLs into one list when both `url` and `urls` are provided" do
        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        described_class.set do |options|
          options.url = "nats://foo.bar:5000"
          options.urls = ["nats://foo.bar:5001", "nats://foo.bar:5002"]
        end
        expect(described_class.urls.count).to eq(3)
        expect(described_class.urls[0]).to eq("nats://foo.bar:5000")
        expect(described_class.urls[1]).to eq("nats://foo.bar:5001")
        expect(described_class.urls[2]).to eq("nats://foo.bar:5002")
      end
    end
  end

  describe "::reset!" do
    context "when set via keyword arguments" do
      it "resets all configuration options to default values" do
        url = "nats://foo.bar:5000"
        urls = ["nats://foo.bar:5001", "nats://foo.bar:5002"]
        default_queue = "foobar"
        output = StringIO.new
        logger = Logger.new(output)
        described_class.set(
          url: url,
          urls: urls,
          default_queue: default_queue,
          logger: logger,
        )

        expect(described_class.urls.count).to eq(3)
        expect(described_class.urls[0]).to eq(url)
        expect(described_class.urls[1]).to eq(urls[0])
        expect(described_class.urls[2]).to eq(urls[1])
        expect(described_class.default_queue).to eq(default_queue)
        expect(described_class.logger).to eq(logger)

        described_class.reset!

        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        expect(described_class.default_queue).to be_nil
        expect(described_class.logger).to be_nil
      end
    end

    context "when set via block assignment" do
      it "resets all configuration options to default values" do
        url = "nats://foo.bar:5000"
        urls = ["nats://foo.bar:5001", "nats://foo.bar:5002"]
        default_queue = "foobar"
        output = StringIO.new
        logger = Logger.new(output)
        described_class.set do |options|
          options.url = url
          options.urls = urls
          options.default_queue = default_queue
          options.logger = logger
        end

        expect(described_class.urls.count).to eq(3)
        expect(described_class.urls[0]).to eq(url)
        expect(described_class.urls[1]).to eq(urls[0])
        expect(described_class.urls[2]).to eq(urls[1])
        expect(described_class.default_queue).to eq(default_queue)
        expect(described_class.logger).to eq(logger)

        described_class.reset!

        expect(described_class.urls.count).to eq(1)
        expect(described_class.urls.first).to eq(Natsy::Config::DEFAULT_URL)
        expect(described_class.default_queue).to be_nil
        expect(described_class.logger).to be_nil
      end
    end
  end
end
