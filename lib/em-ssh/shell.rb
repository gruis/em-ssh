require 'em-ssh'

module EventMachine
  class Ssh
    # EM::Ssh::Shell encapsulates interaction with a user shell on an SSH server.
    # @example Retrieve the output of ifconfig -a on a server
    #   EM.run{
    #     shell = EM::Ssh::Shell.new(host, user, password)
    #     shell.wait_for('@icaleb ~]$')
    #     interfaces = send_and_wait('/sbin/ifconfig -a', '@icaleb ~]$')
    #
    # Shells can be easily and quickly duplicated (#split) without the need to establish another connection.
    # Shells provide :closed, :childless, and :split callbacks.
    #
    # @example Start another shell using the same connection
    #   shell.on(:childless) do
    #     info("#{shell}'s children all closed")
    #     shell.disconnect
    #     EM.stop
    #   end
    #
    #   admin_shell = shell.split
    #   admin_shell.on(:closed) { warn("admin shell has closed") }
    #   admin_shell.send_and_wait('sudo su -', ']$')
    class Shell
      include Log
      include Callbacks

      # Global timeout for wait operations; can be overriden by :timeout option to new
      TIMEOUT = 15
      # @return [Net::SSH::Connection::Channel] The shell to which we can send_data
      attr_reader :shell
      # @return [Net::SSH::Connection]
      attr_reader :connection
      # @return [Hash] the options passed to initialize
      attr_reader :options
      # @return [Hash] the options to pass to connect automatically. They will be extracted from the opptions[:net_ssh] on initialization
      attr_reader :connect_opts

      # @return [String] the host to login to
      attr_reader :host
      # @return [String] The user to authenticate as
      attr_reader :user
      # @return [String] the password to authenticate with - can be nil
      attr_reader :pass
      # @return [Array] all shells that have been split off from this one.
      attr_reader :children
      # @return [Shell] the parent of this shell
      attr_reader :parent
      # @return [String] a string (\r\n) to append to every command
      def line_terminator
        @line_terminator ||= "\n"
      end
      # [String]
      attr_writer :line_terminator

      # Connect to an ssh server then start a user shell.
      # @param [String] address
      # @param [String] user
      # @param [String, nil] pass by default publickey and password auth will be attempted
      # @param [Hash] opts
      # @option opts [Hash] :net_ssh options to pass to Net::SSH; see Net::SSH.start
      # @option opts [Fixnum] :timeout (TIMEOUT) default timeout for all #wait_for and #send_wait calls
      # @option opts [Boolean] :reconnect when disconnected reconnect
      def initialize(address, user, pass, opts = {}, &blk)
        @timeout         = opts[:timeout].is_a?(Fixnum) ? opts[:timeout] : TIMEOUT
        @host            = address
        @user            = user
        @pass            = pass
        @options         = opts
        @connect_opts    = {:password => pass, :port => 22, :auth_methods => ['publickey', 'password']}.merge(opts[:net_ssh] || {})
        @connection      = opts[:connection]
        @parent          = opts[:parent]
        @children        = []
        @reconnect       = opts[:reconnect]
        @buffer          = ''

        if block_given?
          Fiber.new { open(&blk).tap{|r| raise r if r.is_a?(Exception) } }.resume
        else
          open.tap{|r| raise r if r.is_a?(Exception) }
        end # block_given?
      end

      # @return [Boolean] true if the connection should be automatically re-established; default: false
      def reconnect?
        @reconnect == true
      end

      # Close the connection to the server and all child shells.
      # Disconnected shells cannot be split.
      def disconnect
        close
        connection.close
      end

      # @return [Boolean] true if the connection is still alive
      def connected?
        connection && !connection.closed?
      end

      # Close this shell and all children.
      # Even when a shell is closed it is still connected to the server.
      # Fires :closed event.
      # @see Callbacks
      def close
        shell.close.tap{ debug("closing") } if shell.active?
        @closed = true
        children.each { |c| c.close }
        fire(:closed)
      end

      # @return [Boolean] Has this shell been closed.
      def closed?
        @closed == true
      end

      # Send a string to the server and wait for a response containing a specified String or Regex.
      # @param [String] send_str
      # @return [String] all data in the buffer including the wait_str if it was found
      def send_and_wait(send_str, wait_str = nil, opts = {})
        reconnect? ? open : raise(Disconnected) if !connected?
        raise ClosedChannel if closed?
        debug("send_and_wait(#{send_str.inspect}, #{wait_str.inspect}, #{opts})")
        send_data(send_str)
        return wait_for(wait_str, opts)
      end

      # Wait for the shell to send data containing the given string.
      # @param [String, Regexp] strregex a string or regex to match the console output against.
      # @param [Hash] opts
      # @option opts [Fixnum] :timeout (Session::TIMEOUT) the maximum number of seconds to wait
      # @return [String] the contents of the buffer or a TimeoutError
      # @raise Disconnected
      # @raise ClosedChannel
      # @raise TimeoutError
      def wait_for(strregex, opts = { })
        reconnect? ? open : raise(Disconnected) unless connected?
        raise ClosedChannel if closed?
        debug("wait_for(#{strregex.inspect}, #{opts})")
        opts      = { :timeout => @timeout }.merge(opts)
        found     = nil
        f         = Fiber.current
        trace     = caller
        timer     = nil
        matched   = false

        data_callback = on(:data) do
          if matched
            debug("data_callback invoked when already matched")
            next
          end
          matched = @buffer.match(strregex)
          if matched
            debug("data matched")
            timer.respond_to?(:cancel) && timer.cancel
            data_callback.cancel
            @buffer=matched.post_match
            f.resume(matched.pre_match + matched.to_s)
          end
        end

        # Check against current buffer
        EM::next_tick {
          data_callback.call() if @buffer.length>0
        }

        timeout = proc do
          data_callback.cancel
          f.resume(TimeoutError.new("#{host}: timeout while waiting for #{strregex.inspect}; received: #{@buffer.inspect}"))
        end

        timer = EM::Timer.new(opts[:timeout], &timeout)
        debug("set timer: #{timer} for #{opts[:timeout]}")
        res = Fiber.yield
        raise(res, res.message, Array(res.backtrace) + trace) if res.is_a?(Exception)
        yield(res) if block_given?
        res
      end


      # Open a shell on the server.
      # You generally don't need to call this.
      # @return [self, Exception]
      def open(&blk)
        debug("open(#{blk})")
        f      = Fiber.current
        trace  = caller

        conerr = nil
        unless connected?
          conerr = on(:error) do |e|
            error("#{e} (#{e.class})")
            e.set_backtrace(trace + Array(e.backtrace))
            debug(e.backtrace)
            conerr = e
            f.resume(e)
          end #  |e|
          connect
        end # connected?

        connection || raise(ConnectionError, "failed to create shell for #{host}: #{conerr} (#{conerr.class})")

        connection.open_channel do |channel|
          debug "**** channel open: #{channel}"
          channel.request_pty(options[:pty] || {}) do |pty,suc|
            debug "***** pty open: #{pty}; suc: #{suc}"
            pty.send_channel_request("shell") do |shell,success|
              unless success
                f.resume(ConnectionError.new("Failed to create shell").tap{|e| e.set_backtrace(caller) })
              end
              conerr && conerr.cancel
              debug "***** shell open: #{shell}"
              @closed = false
              @shell = shell
              @shell.on_data do |ch,data|
                debug("data: #{@buffer.dump}")
                @buffer += data
                fire(:data)
              end

              Fiber.new { yield(self) if block_given? }.resume
              f.resume(self)
            end # |shell,success|
          end # |pty,suc|
        end # |channel|

        return Fiber.yield
      end

      # Create a new shell using the same ssh connection.
      # A connection will be established if this shell is not connected.
      # If a block is provided the child will be closed after yielding.
      # @yield [Shell] child
      # @return [Shell] child
      def split
        connect unless connected?
        child = self.class.new(host, user, pass, {:connection => connection, :parent => self}.merge(options))
        child.line_terminator = line_terminator
        children.push(child)
        child.on(:closed) do
          children.delete(child)
          fire(:childless).tap{ info("fired :childless") } if children.empty?
        end
        fire(:split, child)
        block_given? ? yield(child).tap { child.close } : child
      end

      # Connect to the server.
      # Does not open the shell; use #open or #split
      # You generally won't need to call this on your own.
      def connect
        return if connected?
        trace = caller
        f = Fiber.current
        ::EM::Ssh.start(host, user, connect_opts) do |connection|
          connection.callback do |ssh|
            f.resume(@connection = ssh)
          end # ssh
          connection.errback do |e|
            e.set_backtrace(trace + Array(e.backtrace))
            fire(:error, e)
            f.resume(e)
          end # err
        end
        return Fiber.yield
      end


      # Send data to the ssh server shell.
      # You generally don't need to call this.
      # @see #send_and_wait
      # @param [String] d the data to send encoded as a string
      def send_data(d)
        shell.send_data("#{d}#{line_terminator}")
      end


      def debug(msg = nil, &blk)
        super("#{host} #{msg}", &blk)
      end

      def info(msg = nil, &blk)
        super("#{host} #{msg}", &blk)
      end

      def fatal(msg = nil, &blk)
        super("#{host} #{msg}", &blk)
      end

      def warn(msg = nil, &blk)
        super("#{host} #{msg}", &blk)
      end

      def error(msg = nil, &blk)
        super("#{host} #{msg}", &blk)
      end


    private
    # TODO move private stuff down to private
    #      e.g., #open, #connect,

    end # class::Shell
  end # class::Ssh
end # module::EventMachine
