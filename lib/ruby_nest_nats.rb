# frozen_string_literal: true

require "nats/client"
require_relative "ruby_nest_nats/version"
require_relative "ruby_nest_nats/utils"
require_relative "ruby_nest_nats/client"
require_relative "ruby_nest_nats/controller"

module RubyNestNats
  class Error < StandardError; end
  class NewSubscriptionsError < StandardError; end
end
