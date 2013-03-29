require 'em-ssh/connection/channel/null-logger'

module EventMachine
  class Ssh
    class Connection
      class Channel

        # This module adds functionality to any channel it extends.
        # It mainly provides functionality to help interactive behaviour on said channel.
        # * #send_data (improved) that can append 'line terminators'.
        # * #wait_for - waits for the shell to send data containing the given string.
        # * #send_and_wait - sends a string and waits for a response containing a specified pattern.
        # * #expect - waits for a number of seconds until a pattern is matched by the channel output.
        # @example
        #   ch = get_some_ssh_channel_from_somewhere
        #   ch.extend(Interactive)
        #   ch.send_and_wait("ls -a", PROMPT)
        #   # > we get the result of the `ls -a` command through the channel (hopefully)
        module Interactive

          include Callbacks

          DEFAULT_TIMEOUT = 15

          attr_accessor :buffer
          private :buffer, :buffer=

          # @return[String] a string (\r\n) to append to every command
          attr_accessor :line_terminator

          def self.extended(channel)
            channel.init_interactive_module
          end

          # When this module extends an object this method is automatically called (via self#extended).
          # In other cases (include, prepend?), you need to call this method manually before use of the channel.
          def init_interactive_module
            @buffer = ''
            @line_terminator = "\n"
            on_data do |ch, data|
              @buffer += data
              fire(:data, data)
            end
          end

          # @returns[#to_s] Returns a #to_s object describing the dump of the content of the buffers used by
          #                 the methods of the interactive module mixed in the host object.
          def dump_buffers
            @buffer.dump
          end

          # Wait for a number of seconds until a specified string or regexp is matched by the
          # data returned from the ssh channel. Optionally send a given string first.
          #
          # If a block is not provided the current Fiber will yield until strregex matches or
          # :timeout is reached.
          #
          # If a block is provided expect will return.
          #
          # @param [String, Regexp] strregex to match against
          # @param [String] send_str the data to send before waiting
          # @param [Hash] opts
          # @option opts [Fixnum] :timeout (@timeout) number of seconds to wait when there is no activity
          # @return [Shell, String] all data received up to an including strregex if a block is not provided.
          #                         the Shell if a block is provided
          # @example expect a prompt
          #   expect(' ~]$ ')
          # @example send a command and wait for a prompt
          #   expect(' ~]$ ', '/sbin/ifconfig')
          # @example expect a prompt and within 5 seconds
          #   expect(' ~]$ ', :timeout => 5)
          # @example send a command and wait up to 10 seconds for a prompt
          #   expect(' ~]$ ', '/etc/sysconfig/openvpn restart', :timeout => 10)
          def expect(strregex, send_str = nil, opts = {})
            send_str, opts = nil, send_str if send_str.is_a?(Hash)
            if block_given?
              Fiber.new {
                yield send_str ? send_and_wait(send_str, strregex, opts) : wait_for(strregex, opts)
              }.resume
              self
            else
              send_str ? send_and_wait(send_str, strregex, opts) : wait_for(strregex, opts)
            end
          end

          # Send a string to the server and wait for a response containing a specified String or Regex.
          # @param [String] send_str
          # @return [String] all data in the buffer including the wait_str if it was found
          def send_and_wait(send_str, wait_str = nil, opts = {})
            send_data(send_str, true)
            return wait_for(wait_str, opts)
          end

          # Send data to the ssh server shell.
          # You generally don't need to call this.
          # @see #send_and_wait
          # @param [String]  d            the data to send encoded as a string
          # @param [Boolean] send_newline appends a newline terminator to the data (defaults: false).
          def send_data(d, send_newline=false)
            if send_newline
              super("#{d}#{@line_terminator}")
            else
              super("#{d}")
            end
          end

          # Wait for the shell to send data containing the given string.
          # @param [String, Regexp] strregex a string or regex to match the console output against.
          # @param [Hash] opts
          # @option opts [Fixnum] :timeout (Session::TIMEOUT) the maximum number of seconds to wait
          # @return [String] the contents of the buffer or a TimeoutError
          # @raise Disconnected
          # @raise ClosedChannel
          # @raise TimeoutError
          def wait_for(strregex, opts = { })
            ###
            log = opts[:log] || NullLogger.new
            timeout_value = opts[:timeout].is_a?(Fixnum) ? opts[:timeout] : DEFAULT_TIMEOUT
            ###
            log.debug("wait_for(#{strregex.inspect}, :timeout => #{timeout_value})")
            opts          = { :timeout => timeout_value }.merge(opts)
            found         = nil
            f             = Fiber.current
            trace         = caller
            timer         = nil
            data_callback = nil
            matched       = false
            started       = Time.new

            timeout_proc = proc do
              data_callback && data_callback.cancel
              f.resume(TimeoutError.new("#{connection.host}: inactivity timeout (#{opts[:timeout]}) while waiting for #{strregex.inspect}; received: #{buffer.inspect}; waited total: #{Time.new - started}"))
            end

            data_callback = on(:data) do
              timer && timer.cancel
              if matched
                log.warn("data_callback invoked when already matched")
                next
              end
              if (matched = buffer.match(strregex))
                log.debug("matched #{strregex.inspect} on #{buffer.inspect}")
                data_callback.cancel
                @buffer = matched.post_match
                f.resume(matched.pre_match + matched.to_s)
              else
                timer = EM::Timer.new(opts[:timeout], &timeout_proc)
              end
            end

            # Check against current buffer
            EM::next_tick { data_callback.call() if buffer.length > 0 }

            timer = EM::Timer.new(opts[:timeout], &timeout_proc)
            Fiber.yield.tap do |res|
              if res.is_a?(Exception)
                res.set_backtrace(Array(res.backtrace) + trace)
                raise res
              end
              yield(res) if block_given?
            end
          end

        end # module Interactive
      end # class Channel
    end # class Connection
  end # class Ssh
end # module EventChannel
