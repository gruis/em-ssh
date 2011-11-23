module EventMachine
  class Ssh
    # A simple mixin enabling your objects to allow other objects to register callbacks and fire events.
    # @example
    #     class Connection
    #       include Callbacks
    #       # ...
    #     end
    #
    #     connection = Connection.new(...)
    #     cb = connection.on(:data) do |data|
    #       @version << data
    #       if @version[-1] == "\n"
    #         @version.chomp!
    #         raise SshError.new("incompatible SSH version `#{@version}'") unless @version.match(/^SSH-(1\.99|2\.0)-/)
    #         connection.send_data("#{PROTO_VERSION}\r\n")
    #         cb.cancel
    #         connection.fire(:version_negotiated)
    #       end # @header[-1] == "\n"
    #     end #  |data|
    module Callbacks

      # @return [Hash] The registered callbacks
      def callbacks
        @clbks ||= {}
      end # callbacks


      # Signal that an event has occured.
      # Each callback will receive whatever args are passed to fire, or the object that the event was fired upon.
      # @param [Symbol] event
      # @param [Objects] arguments to pass to all callbacks registered for the given event
      # @param [Array] the results of each callback that was executed
      def fire(event, *args)
        #log.debug("#{self}.fire(#{event.inspect}, #{args})")
        args = self if args.empty?
        (callbacks[event] ||= []).clone.map { |cb| cb.call(*args) }
      end # fire(event)

      # Register a callback to be fired when a matching event occurs.
      # The callback will be fired when the event occurs until it returns true.
      # @param [Symbol] event
      def on(event, &blk)
        #log.debug("#{self}.on(#{event.inspect}, #{blk})")
        if block_given?
          raise "event (#{event.inspect}) must be a symbol when a block is given" unless event.is_a?(Symbol)
          return Callback.new(self, event, &blk).tap{|cb| (callbacks[event] ||= []).push(cb) }
        end # block_given?

        raise "event (#{event.inspect}) must be a Callback when a block is not given" unless event.is_a?(Callback)
        (callbacks[event] ||= []).push(event)
        return event
      end # on(event, &blk)

      # Registers a callback that will be canceled after the first time it is called.
      def on_next(event, &blk)
        cb = on(event) do |*args|
          cb.cancel
          blk.call(*args)
        end # |*args|
      end # on_next(event, &blk)


      class Callback
        # The object that keeps this callback
        attr_reader :obj
        # [Sybmol] the name of the event
        attr_reader :event
        # The block to call when the event is fired
        attr_reader :block

        def initialize(obj, event, &blk)
          raise ArgumentError.new("a block is required") unless block_given?
          @obj   = obj
          @event = event
          @block = blk
        end # initialize(obj, event, &blk)

        # Call the callback with optional arguments
        def call(*args)
          block.call(*args)
        end # call(*args)

        # Registers the callback with the object.
        # This is useful if you cancel the callback at one point and want to re-enable it later on.
        def register
          @obj.on(self)
        end # register

        def cancel
          raise "#{@obj} does not have any callbacks for #{@event.inspect}" unless @obj.respond_to?(:callbacks) && @obj.callbacks.respond_to?(:[]) && @obj.callbacks[@event].respond_to?(:delete)
          @obj.callbacks[@event].delete(self)
          self
        end # cancel
      end # class::Callback
    end # module::Callbacks
  end # class::Ssh
end # module::EventMachine
