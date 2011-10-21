require 'em-ssh'

module EM
  class Ssh < EventMachine::Connection
    class Shell 
      include Log
      include Callbacks
      
      # Global timeout for wait operations; can be overriden by :timeout option to new
      TIMEOUT = 15
      # [Net::SSH::Connection::Channel] The shell to which we can send_data
      attr_reader :shell
      # [Net::SSH::Connection]
      attr_reader :connection
      # Default (false) halt on timeout value - when true any exception will be propogated
      attr_reader :halt_on_timeout
      attr_writer :line_terminator
      # [Hash]
      attr_reader :options
      attr_reader :connect_opts
      
      # [String] the host to login to
      attr_reader :host
      # [String] The user to authenticate as
      attr_reader :user
      # [String] the password to authenticate with - can be nil
      attr_reader :pass
      # [Array] all shells that have been split off from this one.
      attr_reader :children
      # [Shell] the parent of this shell
      attr_reader :parent

      # [String] 
      def line_terminator
        @line_terminator ||= "\r\n"
      end
      
      def initialize(address, user, pass, opts = {}, &blk)
        @halt_on_timeout = opts[:halt_on_timeout] || false
        @timeout         = opts[:timeout].is_a?(Fixnum) ? opts[:timeout] : TIMEOUT
        @host            = address
        @user            = user
        @pass            = pass
        @options         = opts
        @connect_opts    = {:password => pass, :port => 22, :auth_methods => ['publickey', 'password']}.merge(opts[:net_ssh] || {})
        @connection      = opts[:connection]
        @parent          = opts[:parent]
        @children        = []
        
        block_given? ? start(address, user, pass, opts = {}, &blk) : start(address, user, pass, opts = {})
      end # initialize(address, user, pass)
      
      def connected?
        connection && !connection.closed?
      end
      
      def close
        shell.close.tap{ debug("closing") } if shell.active?
        @closed = true
        children.each { |c| c.close }
        fire(:closed)
      end
      
      def closed?
        @closed == true
      end
      
      # @param [String] d the data to send encoded as a string
      # @return
      def send_data(d)        
        #debug("send_data: #{d}#{line_terminator}")
        shell.send_data("#{d}#{line_terminator}")
      end # send_data(d)
      
      
      def send_and_wait(send_str, wait_str = nil, opts = {})
        debug("send_and_wait(#{send_str.inspect}, #{wait_str.inspect}, #{opts})")
        send_data(send_str)
        return wait_for(wait_str, opts)
      end # send_and_wait(send_str, wait_str = nil, opts = {})
      
      # @param [String, Regexp] strregex a string or regex to match the console output against.
      # @param [Hash] opts
      # @option opts [Fixnum] :timeout (Session::TIMEOUT) the maximum number of seconds to wait
      # @option opts [Boolean] (false) :halt_on_timeout 
      # @option opts [Decimal] :speed
      # @return [String] the contents of the buffer
      def wait_for(strregex, opts = { })
        debug("wait_for(#{strregex}, #{opts})")
        opts      = { :timeout => @timeout, :halt_on_timeout => @halt_on_timeout }.merge(opts)
        @buffer ||=  ""
        found     = nil
        f         = Fiber.current
        
        shell.on_data do |ch,data|
          found = strregex.is_a?(Regexp) ? ((@buffer << data).match(strregex))  :  ((@buffer << data).include?(strregex))
        end #  |ch,data|
        
        timer   = nil
        timeout = proc do
          @buffer = ""
          shell.on_data {|c,d| }
          if opts[:halt_on_timeout]
            raise Timeout::Error("timeout while waiting for #{strregex.inspect}; received: #{@buffer.inspect}").extend(Error)
          else
            warn("timeout while waiting for #{strregex.inspect}; received: #{@buffer.inspect}")
          end # opts[:halt_on_timeout]
        end # timeout
        
        waiter = proc do
          if found
            timer.cancel
            result = @buffer.clone
            @buffer = ""
            shell.on_data {|c,d| }
            f.resume(result)
          else
            EM.next_tick(&waiter)
          end # found
        end # waiter
        
        EM.next_tick(&waiter)
        timer = EM::Timer.new(opts[:timeout], &timeout)
        return Fiber.yield
      end # wait_for(strregex, opts = { })
      
      
      # Create a new shell using the same ssh connection
      # If a block is provided the child will be closed after yielding.
      # @yield [Shell] child
      # @return [Shell] child
      def split
        child = self.class.new(host, user, pass, {:connection => connection, :parent => self}.merge(options))
        child.line_terminator = line_terminator 
        children.push(child)
        child.on(:closed) do
          children.delete(child) 
          fire(:childless).tap{ info("fired :childless") } if children.empty?
        end
        fire(:split, child)
        block_given? ? yield(child).tap { child.close } : child
      end # split
      
      
    private
      
      # @return
      def connect
        f = Fiber.current
        ::EM::Ssh.start(host, user, connect_opts) do |connection|
          @connection = connection
          f.resume
        end # |connection|
        return Fiber.yield
      end # connect
      
      
      def start(host, user, pass, opts = {})
        f = Fiber.current

        connect unless connected?

        connection.open_channel do |channel|
          debug "**** channel open: #{channel}"
          channel.request_pty(opts[:pty] || {}) do |pty,suc|
            debug "***** pty open: #{pty}; suc: #{suc}"
            pty.send_channel_request("shell") do |shell,success|
              raise ConnectionError, "Failed to create shell." unless success
              debug "***** shell open: #{shell}"
              @shell = shell
              f.resume
            end # |shell,success|
          end # |pty,suc|
        end # |channel|
        
        return Fiber.yield
      end # start(address, user pass, opts = {})
      
      
      def on_extended_data
        shell.on_extended_data { |ch, type, data| yield(data) if block_given? }
      end # on_extended_data(&block)

      # The callback to execute when data is received. This callback
      # will be overwritten by any calls to #wait_for
      # @yield [String] data
      # @return
      def on_data(&block)
        @last_on_data = block
        shell && shell.on_data do |ch,data|
          block_given? ? yield(data) : nil
        end
      end # on_data(ch, data)

    end # class::Shell
  end # class::Ssh < EventMachine::Connection
end # module::EM
