require 'eventmachine'
require 'fiber'

require 'net/ssh'

module EM
  class Ssh < EventMachine::Connection
    # Generic error tag
    module Error; end
    # Any class that inherits from SshError will be an Exception and include a Ssh::Error tag
    class SshError < ::StandardError; include Error; end

    class << self
      attr_writer :logger
      def logger(level = Logger::WARN)
        @logger ||= ::Logger.new(STDERR).tap{ |l| l.level = level }
      end # logger(level = Logger::WARN)
    end # << self
    
    module Log
      def log
        EM::Ssh.logger
      end # log

      def debug(msg = nil, &blk)
        log.debug("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end # debug

      def info(msg = nil, &blk)
        log.info("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end # fatal

      def fatal(msg = nil, &blk)
        log.fatal("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end # fatal

      def warn(msg = nil, &blk)
        log.warn("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end # warn

      def error(msg = nil, &blk)
        log.error("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end # error
    end # module::Log
    
  end # class::Ssh
end # module::EM


require 'em-ssh/callbacks'
require 'em-ssh/connection'
require 'em-ssh/constants'
require 'em-ssh/server-version'
require 'em-ssh/packet-stream'
require 'em-ssh/authentication-session'
require 'em-ssh/session'
