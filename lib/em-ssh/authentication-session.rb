module EventMachine
  class Ssh
    class AuthenticationSession < Net::SSH::Authentication::Session
      include Log

      def authenticate(*args)
        debug { "authenticate(#{args.join(", ")})" }
        super(*args)
      end # authenticate(*args)

      # Returns once an acceptable auth packet is received.
      def next_message
        packet = transport.next_message

        case packet.type
        when USERAUTH_BANNER
          info { packet[:message] }
          transport.fire(:auth_banner, packet[:message])
          return next_message
        when USERAUTH_FAILURE
          @allowed_auth_methods = packet[:authentications].split(/,/)
          debug { "allowed methods: #{packet[:authentications]}" }
          return packet

        when USERAUTH_METHOD_RANGE, SERVICE_ACCEPT
          return packet

        when USERAUTH_SUCCESS
          transport.hint :authenticated
          return packet

        else
          raise SshError, "unexpected message #{packet.type} (#{packet})"
        end
      end # next_message
    end # class::AuthenticationSession
  end # module::Ssh
end # module::EventMachine
