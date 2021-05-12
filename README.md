# RubyNestNats

The `ruby_nest_nats` gem allows you to listen for (and reply to) NATS messages asynchronously in a Ruby application.

## TODO

- [x] docs
- [ ] tests
- [ ] "controller"-style classes for reply organization
- [x] multiple queues
- [ ] `on_error` handler so you can send a response (what's standard?)
- [ ] config options for URL/host/port/etc.
- [ ] config for restart behavior (default is to restart listening on any `StandardError`)

## Installation

### Locally (to your application)

Add the gem to your application's `Gemfile`:

```ruby
gem 'ruby_nest_nats'
```

...and then run:

```bash
bundle install
```

### Globally (to your system)

Alternatively, install it globally:

```bash
gem install ruby_nest_nats
```

## Usage

### Logging

#### Attaching a logger

Attach a logger to have `ruby_nest_nats` write out logs for messages received, responses sent, errors raised, lifecycle events, etc.

```rb
require 'logger'

nats_logger = Logger.new(STDOUT)
nats_logger.level = Logger::INFO

RubyNestNats::Client.logger = nats_logger
```

In a Rails application, you might do this instead:

```rb
RubyNestNats::Client.logger = Rails.logger
```

#### Log levels

The following will be logged at the specified log levels

- `DEBUG`: Lifecycle events (starting NATS listeners, stopping NATS, reply registration, setting the default queue, etc.), as well as everything under `INFO`, `WARN`, and `ERROR`
- `INFO`: Message activity over NATS (received a message, replied with a message, etc.), as well as everything under `WARN` and `ERROR`
- `WARN`: Error handled gracefully (listening restarted due to some exception, etc.), as well as everything under `ERROR`
- `ERROR`: Some exception was raised in-thread (error in handler, error in subscription, etc.)

### Setting a default queue

Set a default queue for subscriptions.

```rb
RubyNestNats::Client.default_queue = "foobar"
```

Leave the `::default_queue` blank (or assign `nil`) to use no default queue.

```rb
RubyNestNats::Client.default_queue = nil
```

### Registering message handlers

Register a message handler with the `RubyNestNats::Client::reply_to` method. Pass a subject string as the first argument (either a static subject string or a pattern to match more than one subject). Specify a queue (or don't) with the `queue:` option. If you don't provide the `queue:` option, it will be set to the value of `default_queue`, or to `nil` (no queue) if a default queue hasn't been set.

The result of the given block will be published in reply to the message. The block is passed two arguments when a message matching the subject is received: `data` and `subject`. The `data` argument is the payload of the message (JSON objects/arrays will be parsed into string-keyed `Hash` objects/`Array` objects, respectively). The `subject` argument is the subject of the message received (mostly only useful if a _pattern_ was specified instead of a static subject string).

```rb
RubyNestNats::Client.reply_to("some.subject", queue: "foobar") { |data| "Got it! #{data.inspect}" }

RubyNestNats::Client.reply_to("some.*.pattern") { |data, subject| "Got #{data} on #{subject}" }

RubyNestNats::Client.reply_to("other.subject") do |data|
  if data["foo"] == "bar"
    { is_bar: "Yep!" }
  else
    { is_bar: "No way!" }
  end
end

RubyNestNats::Client.reply_to("subject.in.queue", queue: "barbaz") do
  "My turn!"
end
```

### Starting the listeners

Start listening for messages with the `RubyNestNats::Client::start!` method. This will spin up a non-blocking thread that subscribes to subjects (as specified by invocation(s) of `::reply_to`) and waits for messages to come in. When a message is received, the appropriate `::reply_to` block will be used to compute a response, and that response will be published.

> **NOTE:** If an error is raised in one of the handlers, `RubyNestNats::Client` will restart automatically.

```rb
RubyNestNats::Client.start!
```

### Full example

```rb
RubyNestNats::Client.logger = Rails.logger
RubyNestNats::Client.default_queue = "foobar"

RubyNestNats::Client.reply_to("some.subject") { |data| "Got it! #{data.inspect}" }
RubyNestNats::Client.reply_to("some.*.pattern") { |data, subject| "Got #{data} on #{subject}" }
RubyNestNats::Client.reply_to("subject.in.queue", queue: "barbaz") { { msg: "My turn!", turn: 5 } }

RubyNestNats::Client.start!
```

## Development

### Install dependencies

To install the Ruby dependencies, run:

```bash
bin/setup
```

This gem also requires a NATS server to be running. See [the NATS documentation](https://docs.nats.io/nats-server/installation) for more details.

### Open a console

To open a REPL with the gem's code loaded, run:

```bash
bin/console
```

### Run the tests

To run the RSpec test suites, run:

```bash
bundle exec rake spec
```

...or (if your Ruby setup has good defaults) just this:

```bash
rake spec
```

### Run the linter

```bash
bundle exec rubocop
```

### Create a release

Bump the `RubyNestNats::VERSION` value in `lib/ruby_nest_nats/version.rb`, commit, and then run:

```bash
bundle exec rake release
```

...or (if your Ruby setup has good defaults) just this:

```bash
rake release
```

This will:

1. create a git tag for the new version,
1. push the commits,
1. build the gem, and
1. push it to [rubygems.org](https://rubygems.org/gems/ruby_nest_nats).

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Openbay/ruby_nest_nats.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
