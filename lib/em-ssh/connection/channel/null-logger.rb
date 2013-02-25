require 'logger'

module EventMachine
  class Ssh
    class Connection
      class Channel
        class NullLogger < ::Logger

          def add(*params, &block)
            nil
          end

        end # class NullLogger
      end # class Channel
    end # class Connection
  end # class Ssh
end # module EventMachine
