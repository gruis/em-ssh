module EM
  class Ssh
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
