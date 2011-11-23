module EventMachine
  class Ssh
    module Log
      # @return [Logger] the default logger
      def log
        EventMachine::Ssh.logger
      end

      def debug(msg = nil, &blk)
        log.debug("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end

      def info(msg = nil, &blk)
        log.info("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end

      def fatal(msg = nil, &blk)
        log.fatal("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end

      def warn(msg = nil, &blk)
        log.warn("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end

      def error(msg = nil, &blk)
        log.error("#{self.class}".downcase.gsub("::",".") + " #{msg}", &blk)
      end
    end # module::Log
  end # class::Ssh
end # module::EventMachine
