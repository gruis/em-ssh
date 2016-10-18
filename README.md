#EM-SSH
Em-ssh is a net-ssh adapter for EventMachine. For the most part you can take any net-ssh code you have and run it in the EventMachine reactor.

Em-ssh is not associated with the Jamis Buck's [net-ssh](http://net-ssh.github.com/) library. Please report any bugs with em-ssh to [https://github.com/simulacre/em-ssh/issues](https://github.com/simulacre/em-ssh/issues)
##Installation
  gem install em-ssh

##Synopsis

```ruby
require "em-ssh"
EM.run do
  EM::Ssh.start(host, user, :password => password) do |connection|
    connection.errback do |err|
      $stderr.puts "#{err} (#{err.class})"
      EM.stop
    end
    connection.callback do |ssh|
      # capture all stderr and stdout output from a remote process
      ssh.exec!('uname -a').tap {|r| puts "\nuname: #{r}"}

      # capture only stdout matching a particular pattern
      stdout = ""
      ssh.exec!("ls -l /home") do |channel, stream, data|
        stdout << data if stream == :stdout
      end
      puts "\n#{stdout}"

      # run multiple processes in parallel to completion
      ssh.exec('ping -c 1 www.google.com')
      ssh.exec('ping -c 1 www.yahoo.com')
      ssh.exec('ping -c 1 www.rakuten.co.jp')

      #open a new channel and configure a minimal set of callbacks, then wait for the channel to finishes (closees).
      channel = ssh.open_channel do |ch|
        ch.exec "/usr/local/bin/ruby /path/to/file.rb" do |ch, success|
          raise "could not execute command" unless success

          # "on_data" is called when the process writes something to stdout
          ch.on_data do |c, data|
            $stdout.print data
          end

          # "on_extended_data" is called when the process writes something to stderr
          ch.on_extended_data do |c, type, data|
            $stderr.print data
          end

          ch.on_close { puts "done!" }
        end
      end

      channel.wait

      ssh.close
      EM.stop
    end
  end
end
```

See [http://net-ssh.github.com/ssh/v2/api/index.html](http://net-ssh.github.com/ssh/v2/api/index.html)

##Shell

Em-ssh provides an expect-like shell abstraction layer on top of net-ssh in EM::Ssh::Shell

### Example

```ruby
require 'em-ssh/shell'
EM.run do
  EM::Ssh::Shell.new(host, ENV['USER'], "") do |shell|
    shell.callback do
      shell.expect(Regexp.escape('~]$ '))
      $stderr.puts shell.expect(Regexp.escape('~]$ '),'uname -a')
      $stderr.puts shell.expect(Regexp.escape('~]$ '), '/sbin/ifconfig -a')
      EM.stop
    end
    shell.errback do |err|
      $stderr.puts "error: #{err} (#{err.class})"
      EM.stop
    end
  end
end
```

### Run Multiple Commands in Parallel

```ruby
require 'em-ssh/shell'

waitstr = Regexp.escape('~]$ ')
commands = ["uname -a", "uptime", "ifconfig"]
EM.run do
  EM::Ssh::Shell.new(host, user, "") do |shell|
    shell.errback do |err|
      $stderr.puts "error: #{err} (#{err.class})"
      EM.stop
    end

    shell.callback do
      commands.clone.each do |command|
        mys = shell.split # provides a second session over the same connection

        mys.on(:closed) do
          commands.delete(command)
          EM.stop if commands.empty?
        end

        mys.callback do
          $stderr.puts("waiting for: #{waitstr.inspect}")
          # When given a block, Shell#expect does not 'block'
          mys.expect(waitstr) do
            $stderr.puts "sending #{command.inspect} and waiting for #{waitstr.inspect}"
            mys.expect(waitstr, command) do |result|
              $stderr.puts "#{mys} result: '#{result}'"
              mys.close
            end
          end
        end

        mys.errback do |err|
          $stderr.puts "subshell error: #{err} (#{err.class})"
          mys.close
        end

      end
    end
  end
end
```


```ruby
waitstr  = Regexp.escape('~]$ ')
commands = ["uname -a", "uptime", "ifconfig"]

require 'em-ssh/shell'
EM.run do
  EM::Ssh::Shell.new(host, user, "") do |shell|
    shell.errback do |err|
      $stderr.puts "error: #{err} (#{err.class})"
      $stderr.puts err.backtrace
      EM.stop
    end

    shell.callback do
      commands.clone.each do |command|
        Fiber.new {
          # When given a block Shell#split will close the Shell after
          # the block returns. If a block is given it must be called
          # within a Fiber.
          sresult = shell.split do |mys|
            mys.on(:closed) do
              commands.delete(command)
              EM.stop if commands.empty?
            end
            mys.errback do |err|
              $stderr.puts "subshell error: #{err} (#{err.class})"
              mys.close
            end

              mys.expect(waitstr)
              result = mys.expect(waitstr, command)
              $stderr.puts "#{mys} result: '#{result.inspect}'"
              result
          end
          $stderr.puts "split result: #{sresult.inspect} +++"
        }.resume

      end
    end
  end
end
```

## Other Examples
See bin/em-ssh for an example of a basic replacement for system ssh.

See bin/em-ssh-shell for a more complex example usage of Shell.

## Known Issues

Em-ssh relies on Fibers. MRI 1.9.2-p290 on OSX Lion has been known to segfault when using Fibers.

## Testing

The specs for em-ssh require two accessible ssh servers. The quickest
and most consistent way to get the servers up is to use Docker.

Containers run from ``krlmlr/debian-ssh:wheezy`` will be accessible with
users 'docker' and 'root'.

If you have ``docker-compose`` installed:
```shell
SSH_KEY="$(cat ~/.ssh/id_rsa.pub)" docker-compose up
```

If you do not have ``docker-compose`` installed:
```
docker run -d -p 2222:22 -e SSH_KEY="$(cat ~/.ssh/id_rsa.pub)" krlmlr/debian-ssh:wheezy
docker run -d -p 2223:22 -e SSH_KEY="$(cat ~/.ssh/id_rsa.pub)" krlmlr/debian-ssh:wheezy
```

Once the two containers are running just run the specs.

```shell
rspec spec
```

If you want to use different ssh servers for testing you'll need to
update the variables in ``spec/constants.rb``

If you need to debug failing tests you can change the verbosity of
EM::Ssh:

```shell
VERBOSITY=DEBUG rspec spec
```

### Manual Testing

You can also run manual tests using the executable in ``bin``.

```shell
bin/em-ssh-shell docker@localhost:2223 '$ ' 'ls -al' 'hostname' 'uname -a'
```

```shell
be bin/em-ssh docker@localhost:2223
```


## Known Issues

 - If the server's signature changes from the one recorded in your
   ``known_hosts`` file ``EM::Ssh.start`` will hang
 - ``bin/em-ssh`` and ``bin/em-ssh-shell`` will ask for passwords even
   when one isn't required

##Copyright
Copyright (c) 2011 Caleb Crane

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


Portions of this software are Copyright (c) 2008 Jamis Buck
