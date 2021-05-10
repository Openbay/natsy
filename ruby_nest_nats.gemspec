# frozen_string_literal: true

require_relative "lib/ruby_nest_nats/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_nest_nats"
  spec.version = RubyNestNats::VERSION
  spec.authors = ["Keegan Leitz"]
  spec.email = ["keegan@openbay.com"]

  spec.summary = "Bridge between NestJS NATS and Ruby NATS"
  spec.description = "Write Ruby NATS handlers for NestJS NATS implementations"
  spec.homepage = "https://github.com/openbay/ruby_nest_nats"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/openbay/ruby_nest_nats"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.10"
  spec.add_development_dependency "rubocop-performance", "~> 1.9"
  spec.add_development_dependency "rubocop-rake", "~> 0.5"
  spec.add_development_dependency "rubocop-rspec", "~> 2.2"
  spec.add_development_dependency "solargraph"

  spec.add_runtime_dependency "nats", "~> 0.11"
end
