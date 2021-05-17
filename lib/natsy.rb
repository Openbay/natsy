# frozen_string_literal: true

require "nats/client"
require_relative "natsy/version"
require_relative "natsy/utils"
require_relative "natsy/config"
require_relative "natsy/client"
require_relative "natsy/controller"

# The +Natsy+ module provides the top-level namespace for the NATS client
# and controller machinery.
module Natsy
  # Basic error
  class Error < StandardError; end

  # New subscription has been added at runtime
  class NewSubscriptionsError < Natsy::Error; end

  # Invalid options have been provided to +Natsy::Config+
  class InvalidConfigError < Natsy::Error; end
end
