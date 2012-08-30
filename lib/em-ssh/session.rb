module EventMachine
  class Ssh
    class Session < Net::SSH::Connection::Session
      include Log

      def initialize(transport, options={})
        # I don't like overriding #initialize, but we need to keep a
        # reference to the anonymous nil channel so that we can later
        # properly close it.
        self.logger = transport.logger

        @transport = transport
        @options = options

        @channel_id_counter = -1
        @channels = Hash.new(@anon_nil_channel = NilChannel.new(self))
        $stderr.puts @channels.values.map{|c| c.class }
        @listeners = { transport.socket => nil }
        @pending_requests = []
        @channel_open_handlers = {}
        @on_global_request = {}
        @properties = (options[:properties] || {}).dup
        register_callbacks
      end

      # Override the default, blocking behavior of Net::SSH.
      # Callers to loop will still wait, but not block the loop.
      def loop(wait=nil, &block)
        f = Fiber.current
        l = proc do
          block.call ? EM.next_tick(&l) : f.resume
        end
        EM.next_tick(&l)
        return Fiber.yield
      end

      # Override the default, blocking behavior of Net::SSH
      def process(wait=nil, &block)
        return true
      end

      def send_message(msg)
        transport.send_message(msg)
      end

      # Override Net::SSH::Connection::Session#close to remove dangling references to
      # EM::Ssh::Connections and EM::Ssh::Sessions. Also directly close local channels
      # if the connection is already closed.
      def close
        @anon_nil_channel.instance_variable_set(:@session, nil)
        remove_instance_variable(:@anon_nil_channel)

        # Net::SSH::Connection::Session#close doesn't check if the transport is
        # closed. If it is then calling Channel#close will will not close the
        # channel localy and the connection will just spin.
        if transport.closed?
          channels.each do |id, c|
            c.instance_variable_set(:@connection, nil)
          end
          channels.clear
        else
          channels.each { |id, channel| channel.close }
          loop { channels.any? && !transport.closed?  }
        end
        # remove the reference to the connection to facilitate Garbage Collection
        transport, @transport = @transport, nil
        @listeners.clear
        remove_instance_variable(:@logger)
        transport.close
      end

    private


      def register_callbacks
        transport.on(:packet) do |packet|
          unless MAP.key?(packet.type)
            transport.fire(:error, SshError.new("unexpected response #{packet.type} (#{packet.inspect})"))
            return
          end
          send(MAP[packet.type], packet)
        end #  |packet|

        chan_timer = EM.add_periodic_timer(0.01) do
          # we need to check the channel for any data to send and tell it to process any input
          # at some point we should override Channel#enqueue_pending_output, etc.,.
          channels.each { |id, channel| channel.process unless channel.closing? }
        end
      end # register_callbacks

      def channel_close(packet)
        channel = channels[packet[:local_id]]
        super(packet).tap do
          # remove the connection reference to facilitate Garbage Collection
          channel.instance_variable_set(:@connection, nil)
        end
      end

      def channel_open_failure(packet)
        channel = channels[packet[:local_id]]
        super(packet).tap do
          # remove the connection reference to facilitate Garbage Collection
          channel.instance_variable_set(:@connection, nil)
        end
      end

    end # class::Session
  end # class::Ssh
end # module::EventMachine
