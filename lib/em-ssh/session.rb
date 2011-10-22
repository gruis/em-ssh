
module EM
  class Ssh
    class Session < Net::SSH::Connection::Session
      include Log
      
      def initialize(transport, options = {})
        super(transport, options)
        register_callbacks
      end
      
      # Override the default, blocking behavior of Net::SSH
      def loop(wait=nil, &block)
        return
      end
      
      # Override the default, blocking behavior of Net::SSH
      def process(wait=nil, &block)
        return true
      end

      def send_message(msg)
        transport.send_message(msg)
      end


    private


      def register_callbacks
        transport.on(:packet) do |packet|
          raise SshError, "unexpected response #{packet.type} (#{packet.inspect})" unless MAP.key?(packet.type)
          send(MAP[packet.type], packet)
        end #  |packet|

        chann_proc = proc do
          channels.each { |id, channel| channel.process unless channel.closing? }
          EM.next_tick(&chann_proc)
        end
        EM.next_tick(&chann_proc)
      end # register_callbacks

    end # class::Session
  end # class::Ssh
end # module::EM
