# frozen_string_literal: true

require "logger"
require "nats/client"
require "timeout"

# rubocop:disable RSpec/VariableDefinition
def define_test_nats_controller_class(default_queue_type: :omit)
  valid_queue_types = %i[omit string nil]

  unless valid_queue_types.include?(default_queue_type)
    raise ArgumentError, ":default_queue_type must be one of #{valid_queue_types}"
  end

  case default_queue_type
  when :omit
    Class.new(Natsy::Controller) do
      subject "foo" do
        subject "bar" do
          response do |data, subject|
            "foobar | #{data} | #{subject}"
          end
        end
      end
    end
  when :nil
    Class.new(Natsy::Controller) do
      default_queue nil

      subject "foo" do
        subject "bar" do
          response do |data, subject|
            "foobar | #{data} | #{subject}"
          end
        end
      end
    end
  when :string
    Class.new(Natsy::Controller) do
      default_queue "string"

      subject "foo" do
        subject "bar" do
          response do |data, subject|
            "foobar | #{data} | #{subject}"
          end
        end
      end
    end
  else
    raise StandardError, "How'd that happen?"
  end
end
# rubocop:enable RSpec/VariableDefinition

RSpec.describe Natsy::Controller do
  # rubocop:disable RSpec/MultipleSubjects, RSpec/VariableDefinition, RSpec/VariableName, Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration
  before do
    Natsy::Config.reset!
    Natsy::Client.reset!
    Object.send(:remove_const, :TestNatsController2) if Object.constants.include?(:TestNatsController2)

    class TestNatsController2 < Natsy::Controller
      default_queue "queue_2"

      subject "hello" do
        subject "jerk" do
          response do |data|
            "Hey #{data['name']}... that's not cool, man."
          end
        end

        subject "and" do
          subject "wassup" do
            response do |data|
              "Hey, how ya doin', #{data['name']}?"
            end
          end

          subject "goodbye" do
            response do |data|
              "Hi #{data['name']}! But also GOODBYE."
            end
          end
        end
      end

      subject "hello.there.friend" do
        response do |_data|
          "I'm not your friend, pal"
        end
      end

      subject "hey.*.whats.up" do
        response queue: "qwerty" do |data, subject|
          mistaken_identity = subject.split(".")[1]
          "Sorry, #{data}, you must have me confused with someone else; I'm not #{mistaken_identity}!"
        end
      end

      subject "hows" do
        subject "*", queue: "barbaz" do
          subject "doing" do
            response do |data, subject|
              sender_name = data["name"]
              other_person_name = subject.split(".")[1]
              desc = rand < 0.5 ? "terribly" : "great"
              "Well, #{sender_name}, #{other_person_name} is actually doing #{desc}."
            end
          end
        end
      end

      subject "whats", queue: "a" do
        subject "the", queue: "b" do
          subject "hap", queue: "c" do
            response queue: "d" do |data|
              "idk #{data['name']}, irdk."
            end
          end
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleSubjects, RSpec/VariableDefinition, RSpec/VariableName, Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration

  after do
    Natsy::Config.reset!
    Natsy::Client.reset!
    Object.send(:remove_const, :TestNatsController2) if Object.constants.include?(:TestNatsController2)
  end

  describe "::default_queue" do
    it "is blank if one is specified neither globally nor in the controller" do
      klass = define_test_nats_controller_class(default_queue_type: :omit)
      expect(klass.default_queue).to be_nil
    end

    it "is the global default queue if one is specified globally but not in the controller" do
      Natsy::Config.set(default_queue: "something")
      klass = define_test_nats_controller_class(default_queue_type: :omit)
      expect(klass.default_queue).to eq("something")
    end

    it "is the global default queue if one is specified globally but explicitly set to `nil` in the controller" do
      Natsy::Config.set(default_queue: "something")
      klass = define_test_nats_controller_class(default_queue_type: :nil)
      expect(klass.default_queue).to eq("something")
    end

    it "is the controller's default queue if one is not specified globally but is specified in the controller" do
      klass = define_test_nats_controller_class(default_queue_type: :string)
      expect(klass.default_queue).to eq("string")
    end

    it "is the controller's default queue if one is specified both globally and in the controller" do
      Natsy::Config.set(default_queue: "something")
      klass = define_test_nats_controller_class(default_queue_type: :string)
      expect(klass.default_queue).to eq("string")
    end
  end

  describe "::subject" do
    it "creates a subject used to register a `Natsy::Client::reply_to` listener" do
      replies = Natsy::Client.send(:replies)
      hello_there_friend = replies.detect { |reply| reply[:subject] == "hello.there.friend" }
      expect(hello_there_friend).not_to be_nil
    end

    it "creates a subject chain joined with '.' characters when nested" do
      replies = Natsy::Client.send(:replies)
      hello_and_goodbye = replies.detect { |reply| reply[:subject] == "hello.and.goodbye" }
      expect(hello_and_goodbye).not_to be_nil
    end

    it "uses the default queue for listeners, if not overridden by one supplied to `::subject` or `::response`" do
      replies = Natsy::Client.send(:replies)
      hello_and_goodbye = replies.detect { |reply| reply[:subject] == "hello.and.goodbye" }
      expect(hello_and_goodbye).not_to be_nil
      expect(hello_and_goodbye).to have_key(:queue)
      expect(hello_and_goodbye[:queue]).to eq("queue_2")
    end

    it "can override the default queue for listeners at any point in the chain" do
      replies = Natsy::Client.send(:replies)
      hows_wildcard_doing = replies.detect { |reply| reply[:subject] == "hows.*.doing" }
      expect(hows_wildcard_doing).not_to be_nil
      expect(hows_wildcard_doing).to have_key(:queue)
      expect(hows_wildcard_doing[:queue]).to eq("barbaz")
    end
  end

  describe "::response" do
    it "registers a `Natsy::Client::reply_to` listener for its subject nesting" do
      replies = Natsy::Client.send(:replies)
      hello_jerk = replies.detect { |reply| reply[:subject] == "hello.jerk" }
      expect(hello_jerk).not_to be_nil
    end

    it "uses the default queue when registering a listener, if not overridden" do
      replies = Natsy::Client.send(:replies)
      hello_jerk = replies.detect { |reply| reply[:subject] == "hello.jerk" }
      expect(hello_jerk).not_to be_nil
      expect(hello_jerk).to have_key(:queue)
      expect(hello_jerk[:queue]).to eq("queue_2")
    end

    it "can override the default queue" do
      replies = Natsy::Client.send(:replies)
      hey_wildcard_whats_up = replies.detect { |reply| reply[:subject] == "hey.*.whats.up" }
      expect(hey_wildcard_whats_up).not_to be_nil
      expect(hey_wildcard_whats_up).to have_key(:queue)
      expect(hey_wildcard_whats_up[:queue]).to eq("qwerty")
    end

    it "can override a previous queue override by one of its parent subject blocks" do
      replies = Natsy::Client.send(:replies)
      whats_the_hap = replies.detect { |reply| reply[:subject] == "whats.the.hap" }
      expect(whats_the_hap).not_to be_nil
      expect(whats_the_hap).to have_key(:queue)
      expect(whats_the_hap[:queue]).to eq("d")
    end

    it "receives message data as the first argument to its block, and responds appropriately" do
      output = StringIO.new
      logger = Logger.new(output)
      logger.level = Logger::DEBUG

      Natsy::Config.set(logger: logger)
      Natsy::Client.start!

      sleep 2 # TODO: figure out how to do this without sleeps

      Timeout.timeout(5) do
        NATS.start do
          NATS.request("whats.the.hap", { name: "Bob" }.to_json, queue: "d") do |msg|
            Natsy::Client.send(:log, "The reply was '#{msg}'")
            NATS.drain
          end
        end
      end

      sleep 2 # TODO: figure out how to do this without sleeps

      expect(output.string).to include("The reply was '\"idk Bob, irdk.\"'")
    end

    it "receives the fully-resolved subject (not the pattern) as the second argument to its block" do
      output = StringIO.new
      logger = Logger.new(output)
      logger.level = Logger::DEBUG

      Natsy::Config.set(logger: logger)
      Natsy::Client.start!

      sleep 2 # TODO: figure out how to do this without sleeps

      Timeout.timeout(5) do
        NATS.start do
          NATS.request("hey.Bob.whats.up", "Fred", queue: "qwerty") do |msg|
            Natsy::Client.send(:log, "The reply was '#{msg}'")
            NATS.drain
          end
        end
      end

      sleep 2 # TODO: figure out how to do this without sleeps

      expected_response = "Sorry, Fred, you must have me confused with someone else; I'm not Bob!"
      expect(output.string).to include("The reply was '#{expected_response.inspect}'")
    end
  end
end
