module EM
  class Ssh < EventMachine::Connection
    class ServerVersion
      include Log
      
      #PROTO_VERSION = "SSH-2.0-Ruby/EM::SSH_0.0.1 #{RUBY_PLATFORM}"
      # We are using Net::SSH::Algorithms for the key exchange, so we need to use its PROTO_VERSION
      PROTO_VERSION = "SSH-2.0-Ruby/Net::SSH_#{Net::SSH::Version::CURRENT} #{RUBY_PLATFORM}"
      
      attr_reader :header
      attr_reader :version
      
      def initialize(connection)
        log.debug("#{self}.new(#{connection})")
        negotiate!(connection)
      end # initialize(connection)
      
      
    private
      
      def negotiate!(connection)
        @version = ''
        cb = connection.on(:data) do |data|
          log.debug("#{self.class}.on(:data, #{data.inspect})")
          @version << data
          @header = @version.clone
          if @version[-1] == "\n"
            @version.chomp!
            log.debug("server version: #{@version}")
            raise SshError.new("incompatible SSH version `#{@version}'") unless @version.match(/^SSH-(1\.99|2\.0)-/)
            log.debug("local version: #{PROTO_VERSION}")
            connection.send_data("#{PROTO_VERSION}\r\n")
            cb.cancel
            connection.fire(:version_negotiated)
          end # @header[-1] == "\n"
        end #  |data|
      end # negotiate!(connection)

    end # class::ServerVersion
  end # module::Ssh
end # module::EM
