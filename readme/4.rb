#!/usr/bin/env ruby
require "em-ssh"
require File.expand_path("../arg-parser", __FILE__)

host, user = require_host_user

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
