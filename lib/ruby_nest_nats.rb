# frozen_string_literal: true

require "nats/client"
require_relative "ruby_nest_nats/version"
require_relative "ruby_nest_nats/utils"
require_relative "ruby_nest_nats/client"
require_relative "ruby_nest_nats/controller"

# The +RubyNestNats+ module provides the top-level namespace for the NATS client
# and controller machinery.
module RubyNestNats
  # Basic error
  class Error < StandardError; end

  # New subscription has been added at runtime
  class NewSubscriptionsError < RubyNestNats::Error; end
end
