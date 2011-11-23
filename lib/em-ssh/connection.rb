require 'em-ssh/callbacks'
module EventMachine
  class Ssh
    # EventMachine::Ssh::Connection is a EventMachine::Connection that emulates the Net::SSH transport layer. It ties
    # itself into Net::SSH so that the EventMachine reactor loop can take the place of the Net::SSH event loop.
    # Most of the methods here are only for compatibility with Net::SSH
    class Connection < EventMachine::Connection
      include Log

      # Allows other objects to register callbacks with events that occur on a Ssh instance
      include Callbacks

      # maximum number of seconds to wait for a connection
      TIMEOUT = 20
      # @return [String] The host to connect to, as given to the constructor.
      attr_reader :host

      # @return [Fixnum] the port number (DEFAULT_PORT) to connect to, as given in the options to the constructor.
      attr_reader :port

      # @return [ServerVersion] The ServerVersion instance that encapsulates the negotiated protocol version.
      attr_reader :server_version

      # The Algorithms instance used to perform key exchanges.
      attr_reader :algorithms

      # The host-key verifier object used to verify host keys, to ensure that the connection is not being spoofed.
      attr_reader :host_key_verifier

      # The hash of options that were given to the object at initialization.
      attr_reader :options

      # @return [PacketStream] emulates a socket and ssh packetstream
      attr_reader :socket

      # @return [Boolean] true if the connection has been closed
      def closed?
        @closed == true
      end

      # Close the connection
      def close
        # #unbind will update @closed
        close_connection
      end

      # Send a packet to the server
      def send_message(message)
        @socket.send_packet(message)
      end
      alias :enqueue_message :send_message

      def next_message
        return @queue.shift if @queue.any? && algorithms.allow?(@queue.first)
        f = Fiber.current
        cb = on(:packet) do |packet|
          if @queue.any? && algorithms.allow?(@queue.first)
            cb.cancel
            f.resume(@queue.shift)
          end
        end # :packet
        return Fiber.yield
      end # next_message

      # Returns a new service_request packet for the given service name, ready
      # for sending to the server.
      def service_request(service)
        Net::SSH::Buffer.from(:byte, SERVICE_REQUEST, :string, service)
      end

      # Requests a rekey operation, and simulates a block until the operation completes.
      # If a rekey is already pending, this returns immediately, having no effect.
      def rekey!
        if !algorithms.pending?
          f = Fiber.current
          on_next(:algo_init) do
            f.resume
          end # :algo_init
          algorithms.rekey!
          return Fiber.yield
        end
      end

      # Returns immediately if a rekey is already in process. Otherwise, if a
      # rekey is needed (as indicated by the socket, see PacketStream#if_needs_rekey?)
      # one is performed, causing this method to block until it completes.
      def rekey_as_needed
        return if algorithms.pending?
        socket.if_needs_rekey? { rekey! }
      end



      ##
      # EventMachine callbacks
      ###
      def post_init
        @socket = PacketStream.new(self)
        @data         = @socket.input
      end # post_init

      # @return
      def unbind
        debug("#{self} is unbound")
        fire(:closed)
        @closed = true
      end

      def receive_data(data)
        debug("read #{data.length} bytes")
        @data.append(data)
        fire(:data, data)
      end

      def connection_completed
        @contimeout.cancel
        @nocon.cancel
      end # connection_completed

      def initialize(options = {})
        debug("#{self.class}.new(#{options})")
        @host           = options[:host]
        @port           = options[:port]
        @password       = options[:password]
        @queue          = []
        @options        = options
        @timeout        = options[:timeout] || TIMEOUT

        begin
          on(:connected, &options[:callback]) if options[:callback]
          @nocon          = on(:closed) { raise ConnectionFailed, @host }
          @contimeout     = EM::Timer.new(@timeout) { raise ConnectionTimeout, @host }

          @error_callback = lambda { |code| raise SshError.new(code) }

          @host_key_verifier = select_host_key_verifier(options[:paranoid])
          @server_version    = ServerVersion.new(self)
          on(:version_negotiated) do
            @data.consume!(@server_version.header.length)
            @algorithms = Net::SSH::Transport::Algorithms.new(self, options)

            register_data_handler

            on_next(:algo_init) do
              auth = AuthenticationSession.new(self, options)
              user = options.fetch(:user, user)
              Fiber.new do
                if auth.authenticate("ssh-connection", user, options[:password])
                  fire(:connected, Session.new(self, options))
                else
                  fire(:error, Net::SSH::AuthenticationFailed.new(user))
                  close_connection
                end # auth.authenticate("ssh-connection", user, options[:password])
              end.resume # Fiber
            end # :algo_init
          end # :version_negotiated

        rescue Exception => e
          log.fatal("caught an error during initialization: #{e}\n   #{e.backtrace.join("\n   ")}")
          Process.exit
        end # begin
        self
      end # initialize(options = {})


      ##
      # Helpers required for compatibility with Net::SSH
      ##

      # Returns the host (and possibly IP address) in a format compatible with
      # SSH known-host files.
      def host_as_string
        @host_as_string ||= "#{host}".tap do |string|
          string = "[#{string}]:#{port}" if port != DEFAULT_PORT
          _, ip = Socket.unpack_sockaddr_in(get_peername)
          if ip != host
            string << "," << (port != DEFAULT_PORT ? "[#{ip}]:#{port}" : ip)
          end # ip != host
        end #  |string|
      end # host_as_string

      alias :logger :log


      # Configure's the packet stream's client state with the given set of
      # options. This is typically used to define the cipher, compression, and
      # hmac algorithms to use when sending packets to the server.
      def configure_client(options={})
        @socket.client.set(options)
      end

      # Configure's the packet stream's server state with the given set of
      # options. This is typically used to define the cipher, compression, and
      # hmac algorithms to use when reading packets from the server.
      def configure_server(options={})
        @socket.server.set(options)
      end

      # Sets a new hint for the packet stream, which the packet stream may use
      # to change its behavior. (See PacketStream#hints).
      def hint(which, value=true)
        @socket.hints[which] = value
      end

      # Returns a new service_request packet for the given service name, ready
      # for sending to the server.
      def service_request(service)
        Net::SSH::Buffer.from(:byte, SERVICE_REQUEST, :string, service)
      end

      # Returns a hash of information about the peer (remote) side of the socket,
      # including :ip, :port, :host, and :canonized (see #host_as_string).
      def peer
        @peer ||= {}.tap do |p|
          _, ip = Socket.unpack_sockaddr_in(get_peername)
          p[:ip] = ip
          p[:port] = @port.to_i
          p[:host] = @host
          p[:canonized] = host_as_string
        end
      end

      private

      # Register the primary :data callback
      # @return [Callback] the callback that was registered
      def register_data_handler
        on(:data) do |data|
          while (packet = @socket.poll_next_packet)
            case packet.type
            when DISCONNECT
              close_connection
            when IGNORE
              debug("IGNORE packet received: #{packet[:data].inspect}")
            when UNIMPLEMENTED
              log.warn("UNIMPLEMENTED: #{packet[:number]}")
            when DEBUG
              log.send((packet[:always_display] ? :fatal : :debug), packet[:message])
            when KEXINIT
              Fiber.new do
                begin
                  algorithms.accept_kexinit(packet)
                  fire(:algo_init) if algorithms.initialized?
                rescue Exception => e
                  fire(:error, e)
                end # begin
              end.resume
            else
              @queue.push(packet)
              if algorithms.allow?(packet)
                fire(:packet, packet)
                fire(:session_packet, packet) if packet.type >= GLOBAL_REQUEST
              end # algorithms.allow?(packet)
              socket.consume!
            end # packet.type
          end # (packet = @socket.poll_next_packet)
        end #  |data|
      end # register_data_handler

      # Instantiates a new host-key verification class, based on the value of
      # the parameter. When true or nil, the default Lenient verifier is
      # returned. If it is false, the Null verifier is returned, and if it is
      # :very, the Strict verifier is returned. If the argument happens to
      # respond to :verify, it is returned directly. Otherwise, an exception
      # is raised.
      # Taken from Net::SSH::Session
      def select_host_key_verifier(paranoid)
        case paranoid
        when true, nil then
          Net::SSH::Verifiers::Lenient.new
        when false then
          Net::SSH::Verifiers::Null.new
        when :very then
          Net::SSH::Verifiers::Strict.new
        else
          paranoid.respond_to?(:verify) ? paranoid : (raise ArgumentError.new("argument to :paranoid is not valid: #{paranoid.inspect}"))
        end # paranoid
      end # select_host_key_verifier(paranoid)
    end # class::Connection < EventMachine::Connection
  end # module::Ssh
end # module::EventMachine
