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
          if @version.include?("\n")
            @version, _ = @version.split("\n", 2)
            @header     = version.clone + "\n"
            @version.chomp!
            log.debug("server version: #{@version}")
            if !@version.match(/^SSH-(1\.99|2\.0)-/)
              connection.fire(:error, SshError.new("incompatible SSH version `#{@version}'"))
            else
              log.debug("local version: #{Net::SSH::Transport::ServerVersion::PROTO_VERSION}")
              connection.send_data("#{Net::SSH::Transport::ServerVersion::PROTO_VERSION}\r\n")
              cb.cancel
              connection.fire(:version_negotiated)
            end
          end # @header[-1] == "\n"
        end #  |data|
      end
    end # class::ServerVersion
  end # module::Ssh
end # module::EventMachine
