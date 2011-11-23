module EventMachine
  class Ssh
    class ServerVersion
      include Log

      attr_reader :header
      attr_reader :version

      def initialize(connection)
        debug("#{self}.new(#{connection})")
        negotiate!(connection)
      end


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
            log.debug("local version: #{Net::SSH::Transport::ServerVersion::PROTO_VERSION}")
            connection.send_data("#{Net::SSH::Transport::ServerVersion::PROTO_VERSION}\r\n")
            cb.cancel
            connection.fire(:version_negotiated)
          end # @header[-1] == "\n"
        end #  |data|
      end
    end # class::ServerVersion
  end # module::Ssh
end # module::EventMachine
