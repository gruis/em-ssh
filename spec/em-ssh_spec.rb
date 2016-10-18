require 'em-ssh'
require_relative "spec_helper"

module EM::Ssh::Test
  include Constants

  describe "EM::Ssh" do
    it "should be addressable through EM::P and EM::Protocols" do
      EM::P.const_defined?(:Ssh).should be true
      EM::Protocols.const_defined?(:Ssh).should be true
      EM::P::Ssh.should == EM::Ssh
      EM::Protocols::Ssh.should == EM::Ssh
    end

    it "should raise a ConnectionTimeout error when a connection can't be established before the given timeout" do
      expect {
        EM.run {
          EM::Ssh.start(REMOTE1_IP, REMOTE1_USERNAME, port: REMOTE1_PORT,  timeout:  0.0000000001) do |ssh|
            ssh.callback { EM.stop }
            ssh.errback{|e| raise e }
          end
        }
      }.to raise_error(EM::Ssh::NegotiationTimeout)
    end

    it "should raise a ConnectionError when the address is invalid" do
      expect {
        EM.run {
          EM::Ssh.start('0.0.0.1', 'docker') do |ssh| # 0.0.0.1 is an invalid address
            ssh.callback { EM.stop }
            ssh.errback { |e| raise(e) }
          end
        }
      }.to raise_error(EM::Ssh::ConnectionFailed)
    end

    it "should run exec! succesfully" do
      res = ""
      EM.run {
        EM::Ssh.start(REMOTE2_URL, REMOTE2_USERNAME, port: REMOTE2_PORT) do |con|
          con.errback do |err|
            raise err
          end
          con.callback do |ssh|
            res = ssh.exec!("uname -a")
            ssh.close
            EM.stop
          end
        end
      }
      res.should include REMOTE2_UNAME_A
    end
  end
end
