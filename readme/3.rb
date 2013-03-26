#!/usr/bin/env ruby
require File.expand_path("../arg-parser", __FILE__)

host, user = require_host_user

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
