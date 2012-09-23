module Net; module SSH; module Connection
  # Moneky patching is the root of all evil.
  #
  # Net:SSH::Connection::Channel doesn't expect its #connection to every be
  # nil. EM::Ssh unsets the Channels @connection to facilitate garbage
  # collection when the session is closed. Anything that maintains a reference
  # to a Channel could still call Channel#wait, Channel#active?, so we need a
  # guard in those methods.
  #
  # TODO be a good citizen. Verify that the possible memory leak in
  # EM::Ssh::Session is also possible in Net::SSHi::Connection and submit a
  # pull request with fixes.
  class Channel
    def active?
      return unless connection
      connection.channels.key?(local_id)
    end

    def wait
      return unless connection
      connection.loop { active? }
    end
  end
end; end; end
