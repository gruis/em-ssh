require 'eventmachine'

require 'fiber'
require 'timeout'

require 'net/ssh'
require 'em-ssh/log'

module EventMachine
  # @example
  #   EM::Ssh.start(host, user, :password => password) do |ssh|
  #    ssh.exec("hostname") do |ch,stream,data|
  #      puts "data: #{data}"
  #    end
  #  end
  class Ssh
    DEFAULT_PORT = 22

    # Generic error tag
    module Error; end
    # Any class that inherits from SshError will be an Exception and include a Ssh::Error tag
    class SshError < Net::SSH::Exception; include Error; end
    class TimeoutError < Timeout::Error; include Error; end
    class ClosedChannel < SshError; end
    class Disconnected < SshError; end
    class ConnectionFailed < SshError; end
    class ConnectionTimeout < ConnectionFailed; end
    class ConnectionTerminated < SshError; end
    # The server failed to negotiate an ssh protocol version
    class NegotiationTimeout < ConnectionFailed; end


    class << self
      attr_writer :logger
      # Creates a logger when necessary
      # @return [Logger]
      def logger(level = Logger::WARN)
        @logger ||= ::Logger.new(STDERR).tap{ |l| l.level = level }
      end

      # Connect to an ssh server
      # @param [String] host
      # @param [String] user
      # @param [Hash] opts all options accepted by Net::SSH.start
      # @yield [Session]  an EventMachine compatible Net::SSH::Session
      # @see http://net-ssh.github.com/ssh/v2/api/index.html
      # @return [Session]
      # @example
      #   EM::Ssh.start(host, user, options) do |connection|
      #    log.debug "**** connected: #{connection}"
      #    connection.open_channel do |channel|
      #      log.debug "**** channel: #{channel}"
      #      channel.request_pty(options[:pty] || {}) do |pty,suc|
      def connect(host, user, opts = {}, &blk)
        opts[:logger] || logger.debug("#{self}.connect(#{host}, #{user}, #{opts})")
        options = { :host => host, :user => user, :port => DEFAULT_PORT }.merge(opts)
        EM.connect(options[:host], options[:port], Connection, options, &blk)
      end
      alias :start :connect
    end # << self

    # Pull in the constants from Net::SSH::[Transport, Connection and Authentication]
    # and define them locally.
    [:Transport, :Connection, :Authentication]
    .map{ |sym| Net::SSH.const_get(sym).const_get(:Constants) }
    .each do |mod|
      mod.constants.each do |name|
        const_set(name, mod.const_get(name))
      end #  |name|
    end #  |module|

  end # class::Ssh
end # module::EventMachine

EM::P::Ssh = EventMachine::Ssh


require 'em-ssh/callbacks'
require 'em-ssh/connection'
require 'em-ssh/server-version'
require 'em-ssh/packet-stream'
require 'em-ssh/authentication-session'
require 'em-ssh/session'
# load our evil monkey patch
require 'em-ssh/ext/net/ssh/connection/channel'
