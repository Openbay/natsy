# frozen_string_literal: true

require "nats/client"
require_relative "ruby_nest_nats/version"
require_relative "ruby_nest_nats/utils"
require_relative "ruby_nest_nats/client"
require_relative "ruby_nest_nats/controller"

# The `RubyNestNats` module provides the top-level namespace for the NATS client
# and controller machinery.
module RubyNestNats
  class Error < StandardError; end # :nodoc:

  class NewSubscriptionsError < RubyNestNats::Error; end # :nodoc:
end
