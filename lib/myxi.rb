require 'logger'
require 'myxi/server'
require 'myxi/railtie' if defined?(Rails)

module Myxi
  class << self

    class Error < StandardError; end

    #
    # Return a logger
    #
    def logger
      @logger ||= Logger.new(STDERR)
    end
    attr_writer :logger

    #
    # Return a bunny client instance which will be used by the web socket service.
    # This can be overriden if you already have a connection RabbitMQ available
    # if your application. By default, it will connect to localhost or use the
    # RABBITMQ_URL environment variable.
    #
    def bunny
      @bunny ||= begin
        require 'bunny'
        bunny = Bunny.new(ENV['RABBITMQ_URL'])
        bunny.start
        bunny
      end
    end
    attr_writer :bunny

    #
    # Return a channel which this process can always use
    #
    def channel
      @channel ||= bunny.create_channel
    end

    #
    # Store a bool of configured exchanges
    #
    def exchanges
      @exchanges ||= begin
        Myxi::Exchange::EXCHANGES.values.inject({}) do |hash, exch|
          hash[exch.exchange_name.to_sym] = exch.declare
          hash
        end
      end
    end

    #
    # Push data to a given
    #
    def push(exchange, routing_key, &block)
      if exch = exchanges[exchange.to_sym]
        block.call(exch)
      else
        raise Error, "Couldn't send message to '#{exchange}' as it isn't configured"
      end
    end

    #
    # Send an event to the given exchange
    #
    def push_event(exchange, routing_key, event, payload = {})
      push(exchange, routing_key) do |exch|
        exch.publish({:event => event, :payload => payload}.to_json, :routing_key => routing_key.to_s)
      end
      true
    end

  end
end
