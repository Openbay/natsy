# Natsy

The `natsy` gem allows you to listen for (and reply to) NATS messages asynchronously in a Ruby application.

## TODO

- [x] docs
- [x] tests
- [x] "controller"-style classes for reply organization
- [x] runtime subscription additions
- [x] multiple queues
- [x] config options for URL/host/port/etc.
- [ ] config for restart behavior (default is to restart listening on any `StandardError`)
- [ ] `on_error` handler so you can send a response (what's standard?)
- [ ] support lifecycle callbacks (like `on_connect`, `on_disconnect`, etc.) provided by the `nats` gem
- [ ] ability to _request_ (not just reply)

## Installation

### Locally (to your application)

Add the gem to your application's `Gemfile`:

```ruby
gem 'natsy'
```

...and then run:

```bash
bundle install
```

### Globally (to your system)

Alternatively, install it globally:

```bash
gem install natsy
```

### NATS server (important!)

This gem also requires a NATS server to be installed and running before use. See [the NATS documentation](https://docs.nats.io/nats-server/installation) for more details.

## Usage

<a id="starting-the-nats-server-section">

### Starting the NATS server

You'll need to start a NATS server before running your Ruby application. If you installed it via Docker, you might start it like so:

```bash
docker run -p 4222:4222 -p 8222:8222 -p 6222:6222 -ti nats:latest
```

> **NOTE:** You may need to run that command with `sudo` on some systems, depending on the permissions of your Docker installation.

> **NOTE:** For other methods of running a NATS server, see [the NATS documentation](https://docs.nats.io/nats-server/installation).

### Configuration

Use `Natsy::Config::set` to set configuration options. These options can either be set via a `Hash`/keyword arguments passed to the `::set` method, or set by invoking the method with a block and assigning your options to the yielded `Natsy::Config::Options` instance.

This README will use the following two syntaxes interchangably; remember that they do **exactly the same thing:**

```ruby
Natsy::Config.set(
  urls: ["nats://foo.bar:4567", "nats://foo.bar:5678"],
  default_queue: "foobar",
  logger: Rails.logger,
)
```

```ruby
Natsy::Config.set do |options|
  options.urls = ["nats://foo.bar:4567", "nats://foo.bar:5678"]
  options.default_queue = "foobar"
  options.logger = Rails.logger
end
```

The following options are available:

- `url`: A single URL string (including protocol, domain, and port) which points to the relevant NATS server (see [here](#setting-nats-server-url-section) for more info)
- `urls`: An array of URL strings in case you need to listen to multiple NATS servers (see [here](#setting-nats-server-url-section) for more info)
- `logger`: A logger where `natsy` can write helpful information (see [here](#logging-section) for more info)
- `default_queue`: The default queue that your application should fall back to if none is given in a more specific context (see [here](#default-queue-section) for more info)

<a id="setting-nats-server-url-section"></a>

### Setting the NATS server URL(s)

Set the URL/URLs at which your NATS server mediates messages.

```ruby
Natsy::Config.set do |options|
  options.url = "nats://foo.bar:4567"
end
```

```ruby
Natsy::Config.set do |options|
  options.urls = ["nats://foo.bar:4567", "nats://foo.bar:5678"]
end
```

> **NOTE:** If no `url`/`urls` option is specified, `natsy` will fall back on the default NATS server URL, which is `nats://localhost:4222`.

<a id="logging-section"></a>

### Logging

#### Attaching a logger

Attach a logger to have `natsy` write out logs for messages received, responses sent, errors raised, lifecycle events, etc.

```ruby
require 'natsy'
require 'logger'

Natsy::Config.set do |options|
  nats_logger = Logger.new(STDOUT)
  nats_logger.level = Logger::INFO
  options.logger = nats_logger
end
```

In a Rails application, you might do this instead:

```ruby
Natsy::Config.set(logger: Rails.logger)
```

#### Log levels

The following will be logged at the specified log levels

- `DEBUG`: Lifecycle events (starting NATS listeners, stopping NATS, reply registration, etc.), as well as everything under `INFO`, `WARN`, and `ERROR`
- `INFO`: Message activity over NATS (received a message, replied with a message, etc.), as well as everything under `WARN` and `ERROR`
- `WARN`: Error handled gracefully (listening restarted due to some exception, etc.), as well as everything under `ERROR`
- `ERROR`: Some exception was raised in-thread (error in handler, error in subscription, etc.)

<a id="default-queue-section"></a>

### Setting a default queue

Set a default queue for subscriptions.

```ruby
Natsy::Config.set(default_queue: "foobar")
```

Leave the `default_queue` blank (or assign `nil`) to use no default queue.

```ruby
Natsy::Config.set(default_queue: nil)
```

<a id="reply-to-section"></a>

### Registering message handlers

Register a message handler with the `Natsy::Client::reply_to` method. Pass a subject string as the first argument (either a static subject string or a pattern to match more than one subject). Specify a queue (or don't) with the `queue:` option. If you don't provide the `queue:` option, it will be set to the value of `default_queue`, or to `nil` (no queue) if a default queue hasn't been set.

The result of the given block will be published in reply to the message. The block is passed two arguments when a message matching the subject is received: `data` and `subject`. The `data` argument is the payload of the message (JSON objects/arrays will be parsed into string-keyed `Hash` objects/`Array` objects, respectively). The `subject` argument is the subject of the message received (mostly only useful if a _pattern_ was specified instead of a static subject string).

```ruby
Natsy::Client.reply_to("some.subject", queue: "foobar") { |data| "Got it! #{data.inspect}" }

Natsy::Client.reply_to("some.*.pattern") { |data, subject| "Got #{data} on #{subject}" }

Natsy::Client.reply_to("other.subject") do |data|
  if data["foo"] == "bar"
    { is_bar: "Yep!" }
  else
    { is_bar: "No way!" }
  end
end

Natsy::Client.reply_to("subject.in.queue", queue: "barbaz") do
  "My turn!"
end
```

### Starting the listeners

Start listening for messages with the `Natsy::Client::start!` method. This will spin up a non-blocking thread that subscribes to subjects (as specified by invocation(s) of `::reply_to`) and waits for messages to come in. When a message is received, the appropriate `::reply_to` block will be used to compute a response, and that response will be published.

```ruby
Natsy::Client.start!
```

> **NOTE:** If an error is raised in one of the handlers, `Natsy::Client` will restart automatically.

> **NOTE:** You _can_ invoke `::reply_to` to create additional message subscriptions after `Natsy::Client.start!`, but be aware that this forces the client to restart. You may see (benign, already-handled) errors in the logs generated when this restart happens. It will force the client to restart and re-subscribe after _each additional `::reply_to` invoked after `::start!`._ So, if you have a lot of additional `::reply_to` invocations, you may want to consider refactoring so that your call to `Natsy::Client.start!` occurs _after_ those additions.

> **NOTE:** The `::start!` method can be safely called multiple times; only the first will be honored, and any subsequent calls to `::start!` after the client is already started will do nothing (except write a _"NATS is already running"_ log to the logger at the `DEBUG` level).

### Basic full working example (in vanilla Ruby)

The following should be enough to start a `natsy` setup in your Ruby application, using what we've learned so far.

> **NOTE:** For a more organized structure and implementation in a larger app (like a Rails project), see the ["controller" section below](#controller-section).

```ruby
require 'natsy'
require 'logger'

Natsy::Config.set do |options|
  nats_logger = Logger.new(STDOUT)
  nats_logger.level = Logger::DEBUG

  options.logger = nats_logger
  options.urls = ["nats://foo.bar:4567", "nats://foo.bar:5678"]
  options.default_queue = "foobar"
end

Natsy::Client.reply_to("some.subject") do |data|
  "Got it! #{data.inspect}"
end

Natsy::Client.reply_to("some.*.pattern") do |data, subject|
  "Got #{data} on #{subject}"
end

Natsy::Client.reply_to("subject.in.queue", queue: "barbaz") do
  {
    msg: "My turn!",
    turn: 5,
  }
end

Natsy::Client.start!
```

<a id="controller-section"></a>

### Creating "controller"-style classes for listener organization

Create controller classes which inherit from `Natsy::Controller` in order to give your message listeners some structure.

Use the `::default_queue` macro to set a default queue string. If omitted, the controller will fall back on the global default queue assigned to `Natsy::Config::default_queue` (as described [here](#default-queue-section)). If no default queue is set in either the controller or globally, then the default queue will be blank. Set the default queue to `nil` in a controller to fall back to the global default queue.

Use the `::subject` macro to create a block for listening to that subject segment. Nested calls to `::subject` will append each subsequent subject/pattern string to the last (joined by a periods). There is no limit to the level of nesting.

You can register a response for the built-up subject/pattern string using the `::response` macro. Pass a block to `::response` which optionally takes two arguments ([the same arguments supplied to the block of `Natsy::Client::reply_to`](#reply-to-section)). The result of that block will be sent as a response to the message received.

```ruby
class HelloController < Natsy::Controller
  default_queue "foobar"

  subject "hello" do
    subject "jerk" do
      response do |data|
        # The subject at this point is "hello.jerk"
        "Hey #{data['name']}... that's not cool, man."
      end
    end

    subject "and" do
      subject "wassup" do
        response do |data|
          # The subject at this point is "hello.and.wassup"
          "Hey, how ya doin', #{data['name']}?"
        end
      end

      subject "goodbye" do
        response do |data|
          # The subject at this point is "hello.and.goodbye"
          "Hi #{data['name']}! But also GOODBYE."
        end
      end
    end
  end

  subject "hows" do
    # The queue at this point is "foobar"
    subject "*", queue: "barbaz" do # Override the default queue at any point
      # The queue at this point is "barbaz" (!)
      subject "doing" do
        # The queue at this point is "barbaz"
        response queue: "bazbam" do |data, subject|
          # The queue at this point is "bazbam" (!)
          # The subject at this point is "hows.<wildcard>.doing" (i.e., the
          # subjects "hows.jack.doing" and "hows.jill.doing" will both match)
          sender_name = data["name"]
          other_person_name = subject.split(".")[1]
          desc = rand < 0.5 ? "terribly" : "great"
          "Well, #{sender_name}, #{other_person_name} is actually doing #{desc}."
        end
      end
    end
  end
end
```

> **NOTE:** If you implement controllers like this and you are using code-autoloading machinery (like Zeitwerk in Rails), you will need to make sure these paths are eager-loaded when your app starts. **If you don't, `natsy` will not register the listeners,** and will not respond to messages for the specified subjects.
>
> For example: in a Rails project (assuming you have your NATS controllers in a directory called `app/nats/`), you may want to put something like the following in an initializer (such as `config/initializers/nats.rb`):
>
> ```ruby
> Natsy::Config.set(logger: Rails.logger, default_queue: "foobar")
>
> # ...
>
> Rails.application.config.after_initialize do
>   nats_controller_paths = Dir[Rails.root.join("app", "nats", "**", "*_controller.rb")]
>   nats_controller_paths.each { |file_path| require_dependency(file_path) }
>
>   Natsy::Client.start!
> end
> ```

## Development

### Install dependencies

To install the Ruby dependencies, run:

```bash
bin/setup
```

This gem also requires a NATS server to be installed and running. See [the NATS documentation](https://docs.nats.io/nats-server/installation) for more details.
<!-- sudo docker run -p 4222:4222 -p 8222:8222 -p 6222:6222 -ti nats:latest -->
<!-- nats-tail -s nats://localhost:4222 ">" -->
<!-- curl --data '{"name":"Keegan"}' --header 'Content-Type: application/json' http://localhost:3000/hello -->

### Open a console

To open a REPL with the gem's code loaded, run:

```bash
bin/console
```

### Run the tests

To run the RSpec test suites, first [start the NATS server](#starting-the-nats-server-section). Then, run the tests:

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

...or (if your Ruby setup has good defaults) just this:

```bash
rubocop
```

### Create a release

Bump the `Natsy::VERSION` value in `lib/natsy/version.rb`, commit, and then run:

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
1. push it to [rubygems.org](https://rubygems.org/gems/natsy).

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Openbay/natsy.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
