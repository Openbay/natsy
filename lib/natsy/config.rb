# frozen_string_literal: true

require "ostruct"
require_relative "./utils"

module Natsy
  # Represents the configuration options for +Natsy+. Configuration options are
  # set using the `Natsy::Config::set` method, either as arguments or by using
  # the appropriate setters on the object passed to the block.
  class Config
    # A +Natsy::Config::Options+ object is passed as a single argument to the
    # block (if provided) for the +Natsy::Config::set+ method. This class should
    # probably *NOT* be instantiated directly; instead, set the relevant options
    # using +Natsy::Config.set(some_option: "...", some_other_option: "...")+.
    # If you find yourself instantiating this class directly, there's probably a
    # better way to do what you're trying to do.
    class Options
      # Specify a NATS server URL (or multiple URLs)
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # @example
      #   Natsy::Config.set(url: "nats://foo.bar:4567"))
      #
      # @example
      #   Natsy::Config.set do |options|
      #     options.url = "nats://foo.bar:4567"
      #   end
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # @example
      #   Natsy::Config.set(urls: ["nats://foo.bar:4567", "nats://foo.bar:5678"])
      #
      # @example
      #   Natsy::Config.set do |options|
      #     options.urls = ["nats://foo.bar:4567", "nats://foo.bar:5678"]
      #   end
      #
      # If left blank/omitted, +natsy+ will fall back on the default URL, which
      # is +nats://localhost:4222+.
      #
      attr_accessor :url, :urls

      # Attach a logger to have +natsy+ write out logs for messages
      # received, responses sent, errors raised, lifecycle events, etc.
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # @example
      #   require 'natsy'
      #   require 'logger'
      #
      #   nats_logger = Logger.new(STDOUT)
      #   nats_logger.level = Logger::INFO
      #
      #   Natsy::Config.set(logger: nats_logger)
      #
      # @example
      #   require 'natsy'
      #   require 'logger'
      #
      #   Natsy::Config.set do |options|
      #     nats_logger = Logger.new(STDOUT)
      #     nats_logger.level = Logger::INFO
      #
      #     options.logger = nats_logger
      #   end
      #
      #
      # In a Rails application, you might do this instead:
      #
      # @example
      #   Natsy::Config.set(logger: Rails.logger)
      #
      def logger=(new_logger)
        @logger = new_logger
        Utils.log(@logger, "Set the logger to #{@logger.inspect}", level: :debug)
      end

      # Optional logger for lifecycle events, messages received, etc.
      #
      # @see Natsy::Config::Options#logger=
      #
      attr_reader :logger

      # Set a default queue for subscriptions.
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # @example
      #   Natsy::Config.set(default_queue: "foobar")
      #
      # @example
      #   Natsy::Config.set do |options|
      #     options.default_queue = "foobar"
      #   end
      #
      # Leave the +::default_queue+ blank (or assign +nil+) to use no default
      # queue.
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # @example
      #   Natsy::Config.set(default_queue: nil)
      #
      # @example
      #   Natsy::Config.set do |options|
      #     options.default_queue = nil
      #   end
      #
      def default_queue=(new_queue)
        @default_queue = Utils.presence(new_queue.to_s)
        Utils.log(logger, "Setting the default queue to #{@default_queue || '(none)'}", level: :debug)
      end

      # Optional default queue for message subscription and replies.
      #
      # @see Natsy::Config::Options#default_queue=
      #
      attr_reader :default_queue

      # Returns ONLY the config options THAT HAVE BEEN SET as a +Hash+. Will not
      # have keys for properties that are unassigned, but will have keys for
      # properties assigned +nil+.
      def to_h
        hash = {}
        hash[:url] = url if defined?(@url)
        hash[:urls] = urls if defined?(@urls)
        hash[:logger] = logger if defined?(@logger)
        hash[:default_queue] = default_queue if defined?(@default_queue)
        hash
      end
    end

    # Valid option keys that can be given to +Natsy::Config::set+, either in a
    # +Hash+ passed to the method, keyword arguments passed to the method, or by
    # using setters on the +Natsy::Config::Options+ object passed to the block.
    VALID_OPTIONS = %i[
      url
      urls
      logger
      default_queue
    ].freeze

    # The default NATS server URL (used if none is configured)
    DEFAULT_URL = "nats://localhost:4222"

    class << self
      # Specify configuration options, either by providing them as keyword
      # arguments or by using a block. Should you choose to set options using
      # a block, it will be passed a single argument (an instance of
      # +Natsy::Config::Options+). You can set any options on the instance that
      # you see fit.
      #
      # **NOTE:** The following two examples do exactly the same thing.
      #
      # @example
      #   Natsy::Config.set(
      #     urls: ["nats://foo.bar:4567", "nats://foo.bar:5678"],
      #     default_queue: "foobar",
      #     logger: Rails.logger,
      #   )
      #
      # @example
      #   Natsy::Config.set do |options|
      #     options.urls = ["nats://foo.bar:4567", "nats://foo.bar:5678"]
      #     options.default_queue = "foobar"
      #     options.logger = Rails.logger
      #   end
      #
      def set(keyword_options = {})
        new_hash_options = (keyword_options || {}).transform_keys(&:to_sym)

        invalid_config = lambda do |detail, keys|
          raise InvalidConfigError, "Invalid options provided #{detail}: #{keys.join(', ')}"
        end

        invalid_keys = invalid_option_keys(new_hash_options)
        invalid_config.call("as arguments", invalid_keys) if invalid_keys.any?

        # Want to take advantage of the setters on +Natsy::Config::Options+...
        new_hash_options_object = new_hash_options.each_with_object(Options.new) do |(key, value), options|
          options.send(:"#{key}=", value)
        end

        given_options.merge!(new_hash_options_object.to_h)

        new_block_options_object = Options.new
        yield(new_block_options_object) if block_given?

        invalid_keys = invalid_option_keys(new_block_options_object)
        invalid_config.call("in block", invalid_keys) if invalid_keys.any?

        given_options.merge!(new_block_options_object.to_h)
      end

      # The NATS server URLs that +natsy+ should listen on.
      #
      # See also: {Natsy::Config::Options#urls=}
      #
      def urls
        given_url_list = [given_options[:url]].flatten
        given_urls_list = [given_options[:urls]].flatten
        all_given_urls = [*given_url_list, *given_urls_list].compact.uniq
        Utils.presence(all_given_urls) || [DEFAULT_URL]
      end

      # The logger that +natsy+ should use to write out logs for messages
      # received, responses sent, errors raised, lifecycle events, etc.
      #
      # See also: {Natsy::Config::Options#logger=}
      #
      def logger
        Utils.presence(given_options[:logger])
      end

      # The default queue that +natsy+ should use for subscriptions.
      #
      # See also: {Natsy::Config::Options#default_queue=}
      #
      def default_queue
        Utils.presence(given_options[:default_queue])
      end

      # Returns all config options as a +Hash+.
      def to_h
        {
          urls: urls,
          logger: logger,
          default_queue: default_queue,
        }
      end

      # Alias for {Natsy::Config::to_h}.
      def as_json(*_args)
        to_h
      end

      # Serialize the configuration into a JSON object string.
      def to_json(*_args)
        to_h.to_json
      end

      # Reset the configuration to default values.
      def reset!
        @given_options = nil
      end

      private

      def given_options
        @given_options ||= {}
      end

      def invalid_option_keys(options)
        options.to_h.keys - VALID_OPTIONS
      end
    end
  end
end
