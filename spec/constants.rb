module EM
  class Ssh
    module Test

      # Hold would-be-hardcoded values used for testing, constants in regard to the actual testing.
      module Constants

        # Previously, values used for tests (urls, credentials, ips, etc.) were hardcoded
        # and spread through the test codebase.
        # For a slight improvement, this class match previously hardcoded constants to environment variables,
        # use these environment variables if present, and if not rely on hardcoded values provided when
        # said constants were declared (via #add_field(constant_name, default_hardcoded_value).
        class EnvElseHardcoded

          def initialize(header)
            @header = header
          end

          # Sets an accessor for 'name', sets its value as the one from ENV["#@header#{name}".upcase],
          # but if nil, sets is value as parameter 'default7 (default: ''). &blk is called on the chosen value.
          # @param[#to_s]  name     Name of the accessor to create. Be careful with field names that would break a ruby object
          #                         (like :method_missing for instance).
          # @param[Object] default  Value to use if associed ENV value is not set
          # @block                  Called on chosen value
          # @example
          #   DEVICE1 = EnvElseHardcoded.new("THAT_DEVICE_")
          #   DEVICE1.add_field(:some_kind_of_conf, 'default_hardcoded_value') # matched to the environment variable "THAT_DEVICE_SOME_KIND_OF_CONF"
          #    # if the environment variable exists it will use the value it holds, else it will use 'default_hardcoded_value'
          #    # similarily
          #   DEVICE2 = EnvElseHardcoded.new("THAT_OTHER_DEVICE_")
          #   DEVICE2.add_field(:some_other_kind_of_integer_conf, '1', &:to_i) # in this case the block will convert the environment value to an integer
          #    # note, that if no environment variable is provided, the default hardcoded value will also be passed through the block.
          #   DEVICE2.add_field(:ahahah, '2') { |i| i.to_i } # this works_too
          #    # also note that the default hardcoded value defaults to ''.
          def add_field(name, default='', &blk)
            value = ENV["#@header#{name}".upcase] || default
            class << self; self; end.instance_eval { attr_accessor name }
            send("#{name}=", blk ? blk.call(value) : value)
          end
        end

        ### remote server 1
        REMOTE1 = EnvElseHardcoded.new("REMOTE1_")
        REMOTE1.add_field(:ip, '192.168.92.11')
        REMOTE1.add_field(:username, 'caleb')
        REMOTE1.add_field(:prompt)
        ### remote server 2
        REMOTE2 = EnvElseHardcoded.new("REMOTE2_")
        REMOTE2.add_field(:url, 'icaleb.org')
        REMOTE2.add_field(:username, 'calebcrane')
        REMOTE2.add_field(:prompt, ']$')
        REMOTE2.add_field(:timeout, 2, &:to_i)
        REMOTE2.add_field(:uname_a, "Linux icaleb 2.6.18-194.3.1.el5 #1 SMP Thu May 13 13:08:30 EDT 2010 x86_64 x86_64 x86_64 GNU/Linux\n")

      end # module Constants

    end # module Test
  end # module Ssh
end # module EM

