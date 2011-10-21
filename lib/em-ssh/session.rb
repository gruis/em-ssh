
module EM
  class Ssh < EventMachine::Connection
    class Session < Net::SSH::Connection::Session
      include Log
      
      def initialize(transport, options = {})
        super(transport, options)
        register_callbacks
      end # initialize(transport, options = {})
      
      # Override the default, blocking behavior of Net::SSH
      def loop(wait=nil, &block)
        return
      end # loop(wait=nil, &block)
      
      # Override the default, blocking behavior of Net::SSH
      def process(wait=nil, &block)
        return true
      end

      def send_message(msg)
        transport.send_message(msg)
      end # send_message(msg)
              
      
    private
      
      
      def register_callbacks
        transport.on(:session_packet) do |packet|
          unless MAP.key?(packet.type)
            raise Net::SSH::Exception, "unexpected response #{packet.type} (#{packet.inspect})"
          end
          send(MAP[packet.type], packet)
        end #  |packet|
        
        chann_proc = proc do
          channels.each { |id, channel| channel.process unless channel.closing? }
          EM.next_tick(&chann_proc)
        end # 
        EM.next_tick(&chann_proc)
      end # register_callbacks
              
    end # class::Session
  end # class::Ssh < EventMachine::Connection
end # module::EM
