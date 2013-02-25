require 'em-ssh'
require 'em-ssh/connection/channel/interactive'

module EventMachine
  class Ssh
    # EM::Ssh::Shell encapsulates interaction with a user shell on an SSH server.
    # @example Retrieve the output of ifconfig -a on a server
    #   EM.run{
    #     shell = EM::Ssh::Shell.new(host, user, password)
    #     shell.expect('~]$ ')
    #     interfaces = expect('~]$ ', '/sbin/ifconfig -a')
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
    #   admin_shell.expect(']$', 'sudo su -')
    class Shell
      include Log
      include Callbacks
      include EM::Deferrable

      # Global timeout for wait operations; can be overriden by :timeout option to new
      TIMEOUT = 15
      # @return [Net::SSH::Connection::Channel] The shell to which we can send_data
      attr_reader :shell
      # @return [EM::Ssh::Session]
      attr_reader :session
      # @return [EM::Ssh::Connection]
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
        shell ? shell.line_terminator : "\n"
      end

      # @param[String] lt a string (\r\n) to append to every command
      def line_terminator=(lt)
        @line_terminator = lt
        shell.line_terminator = lt if shell
      end

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
        @session         = opts[:session]
        @parent          = opts[:parent]
        @children        = []
        @reconnect       = opts[:reconnect]

        # TODO make all methods other than #callback and #errback inaccessible until connected? == true
        yield self if block_given?
        Fiber.new {
          open rescue fail($!)
          succeed(self) if connected? && !closed?
        }.resume
      end

      # @return [Boolean] true if the connection should be automatically re-established; default: false
      def reconnect?
        @reconnect == true
      end

      # Close the connection to the server and all child shells.
      # Disconnected shells cannot be split.
      def disconnect(timeout = nil)
        if timeout
          EM::Timer.new(timeout) { disconnect! }
        end
        close
        @session && @session.close
        disconnect!
      end

      def disconnect!
        @session = nil
        if @connection
          @connection.close_connection
          @connection = nil
        end
      end # disconnect!

      # @return [Boolean] true if the session is still alive
      def connected?
        session && !session.closed?
      end

      # Close this shell and all children.
      # Even when a shell is closed it is still connected to the server.
      # Fires :closed event.
      # @see Callbacks
      def close
        shell.close.tap{ debug("closing") } if shell && shell.active?
        @closed = true
        children.each { |c| c.close }
        fire(:closed)
      end

      # @return [Boolean] Has this shell been closed.
      def closed?
        @closed == true
      end

      # Open a shell on the server.
      # You generally don't need to call this.
      # @return [self, Exception]
      def open(&blk)
        debug("open(#{blk})")
        f      = Fiber.current
        trace  = caller

        begin
          connect
          session.open_channel do |channel|
            debug "**** channel open: #{channel}"
            channel.request_pty(options[:pty] || {}) do |pty,suc|
              debug "***** pty open: #{pty}; suc: #{suc}"
              pty.send_channel_request("shell") do |shell,success|
                if !success
                  f.resume(ConnectionError.new("Failed to create shell").tap{|e| e.set_backtrace(caller) })
                else
                  debug "***** shell open: #{shell}"
                  @closed = false
                  ###
                  @shell  = shell
                  shell.extend(EventMachine::Ssh::Connection::Channel::Interactive)
                  shell.line_terminator = @line_terminator if @line_terminator
                  shell.on(:data) { |data| debug("#{shell.dump_buffers}") }
                  ###
                  Fiber.new { yield(self) if block_given? }.resume
                  f.resume(self)
                end
              end # |shell,success|
            end # |pty,suc|
          end # |channel|
        rescue => e
          raise ConnectionError.new("failed to create shell for #{host}: #{e} (#{e.class})")
        end

        return Fiber.yield.tap { |r| raise r if r.is_a?(Exception) }
      end

      # Create a new shell using the same ssh connection.
      # A connection will be established if this shell is not connected.
      # If a block is provided the child will be closed after yielding.
      # @yield [Shell] child
      # @return [Shell] child
      def split
        connect unless connected?
        child = self.class.new(host, user, pass, {:session => session, :parent => self}.merge(options))
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
        return @session if connected?
        trace = caller
        f = Fiber.current
        ::EM::Ssh.start(host, user, connect_opts) do |connection|
          @connection = connection
          connection.callback do |ssh|
            f.resume(@session = ssh)
          end
          connection.errback do |e|
            e.set_backtrace(trace + Array(e.backtrace))
            f.resume(e)
          end
        end
        return Fiber.yield.tap { |r| raise r if r.is_a?(Exception) }
      end

      # Ensure the channel is open of fail.
      def assert_channel!
        reconnect? ? open : raise(Disconnected) unless connected?
        raise ClosedChannel if closed?
      end
      private :assert_channel!

      # Wait for a number of seconds until a specified string or regexp is matched by the
      # data returned from the ssh connection. Optionally send a given string first.
      #
      # If a block is not provided the current Fiber will yield until strregex matches or
      # :timeout # is reached.
      #
      # If a block is provided expect will return.
      #
      # @param [String, Regexp] strregex to match against
      # @param [String] send_str the data to send before waiting
      # @param [Hash] opts
      # @option opts [Fixnum] :timeout (@timeout) number of seconds to wait when there is no activity
      # @return [Shell, String] all data received up to an including strregex if a block is not provided.
      #                         the Shell if a block is provided
      # @example expect a prompt
      #   expect(' ~]$ ')
      # @example send a command and wait for a prompt
      #   expect(' ~]$ ', '/sbin/ifconfig')
      # @example expect a prompt and within 5 seconds
      #   expect(' ~]$ ', :timeout => 5)
      # @example send a command and wait up to 10 seconds for a prompt
      #   expect(' ~]$ ', '/etc/sysconfig/openvpn restart', :timeout => 10)
      def expect(strregex, send_str = nil, opts = {})
        assert_channel!
        shell.expect(strregex,
                     send_str,
                     {:timeout => @timeout, :log => self }.merge(opts))
      end

      # Send a string to the server and wait for a response containing a specified String or Regex.
      # @param [String] send_str
      # @return [String] all data in the buffer including the wait_str if it was found
      def send_and_wait(send_str, wait_str = nil, opts = {})
        assert_channel!
        shell.send_and_wait(send_str,
                            wait_str,
                            {:timeout => @timeout, :log => self }.merge(opts))
      end

      # Send data to the ssh server shell.
      # You generally don't need to call this.
      # @see #send_and_wait
      # @param [String] d the data to send encoded as a string
      def send_data(d, send_newline=true)
        assert_channel!
        shell.send_data(d, send_newline)
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
        assert_channel!
        shell.wait_for(strregex, {:timeout => @timeout, :log => self }.merge(opts))
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
