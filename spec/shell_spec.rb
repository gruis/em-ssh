require 'em-ssh/shell'
require_relative "spec_helper"


module EM::Ssh::Test
  include Constants

  describe "Ssh::Shell" do

    it "should return a shell" do
      EM.run {
        Fiber.new {
          timer = EM::Timer.new(REMOTE2_TIMEOUT) { raise "failed #{$0}" }
          shell = EM::Ssh::Shell.new(REMOTE2_URL, REMOTE2_USERNAME, "", port: REMOTE2_PORT)
          shell.callback do
            shell.should be_a(EventMachine::Ssh::Shell)
            shell.expect(Regexp.escape(REMOTE2_PROMPT))
            shell.send_and_wait("uname -a", Regexp.escape(REMOTE2_PROMPT)).should include("GNU/Linux")
            timer.cancel
            EM.stop
          end
          shell.errback { EM.stop }
        }.resume
      }
    end # should return a shell

    it "should yield a shell" do
      EM.run {
        timer = EM::Timer.new(REMOTE2_TIMEOUT*2) { raise "failed #{$0}" }
        EM::Ssh::Shell.new(REMOTE2_URL, REMOTE2_USERNAME, "", port: REMOTE2_PORT) do |shell|
          shell.callback do
            shell.should be_a(EventMachine::Ssh::Shell)
            shell.wait_for(Regexp.escape(REMOTE2_PROMPT))
            shell.send_and_wait('uname -a', Regexp.escape(REMOTE2_PROMPT)).should include("GNU/Linux")
            shell.send_and_wait('ip addr', Regexp.escape(REMOTE2_PROMPT)).should include("eth0")
            timer.cancel
            EM.stop
          end
        end
      }
    end

    it "should yield a shell even when in a fiber" do
      EM.run {
        Fiber.new{
          timer = EM::Timer.new(REMOTE2_TIMEOUT*2) { raise "failed #{$0}" }
          EM::Ssh::Shell.new(REMOTE2_URL, REMOTE2_USERNAME, "", port: REMOTE2_PORT) do |shell|
            shell.callback do
              shell.should be_a(EventMachine::Ssh::Shell)
              shell.wait_for(Regexp.escape(REMOTE2_PROMPT))
              shell.send_and_wait('uname -a', Regexp.escape(REMOTE2_PROMPT)).should include("GNU/Linux")
              timer.cancel
              EM.stop
            end
          end
        }.resume
      }
    end # should yield a shell

    it "should raise a proper error with good backtrace on timeout" do
      EM.run {
        Fiber.new {
          timer = EM::Timer.new(REMOTE2_TIMEOUT*2) { raise TimeoutError.new("failed to finish test") }
          EM::Ssh::Shell.new(REMOTE2_URL, REMOTE2_USERNAME, "", port: REMOTE2_PORT) do |shell|
            shell.callback do
              shell.should be_a(EventMachine::Ssh::Shell)
              shell.wait_for(Regexp.escape(REMOTE2_PROMPT), :timeout => 1)
              e = shell.send_and_wait('uname -a', Regexp.escape(']%'), :timeout => 2) rescue $!
              e.should be_a(EM::Ssh::TimeoutError)
              e.backtrace.join.should include("#{__FILE__}:#{__LINE__ - 2}:in `block")
              timer.cancel
              EM.stop
            end
          end
        }.resume
      }
    end # should raise a proper error with good backtrace on timeout

    specify "#wait_for should raise TimeoutError on timeout" do
      EM.run {
        Fiber.new {
          timer = EM::Timer.new(REMOTE2_TIMEOUT*2) { raise TimeoutError.new("failed to finish test") }
          EM::Ssh::Shell.new(REMOTE2_URL, REMOTE2_USERNAME, "", port: REMOTE2_PORT) do |shell|
            shell.callback do
              expect {
                shell.wait_for(Regexp.escape(']%'), :timeout => 1)
              }.to raise_error(EM::Ssh::TimeoutError)
              timer.cancel
              EM.stop
            end
          end
        }.resume
      }
    end
  end
end
