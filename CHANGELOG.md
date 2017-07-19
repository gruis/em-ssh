0.8.1
- [#33](https://github.com/simulacre/em-ssh/pull/33) - Loosen net-ssh dependencies to permit > 3.2 [@kt97679](https://github.com/kt97679)

0.8.0
-	[b1f5774](https://github.com/simulacre/em-ssh/commit/b1f5774f10b2496063db5d52bab66b1871b2cd26) - net-ssh 3.2.0; em 1.2.0; docker for testing. Contributions from Kirill Timofeev

0.7.0
- [88323761c67c433bd46fedfd042ae9a97b726cb6](https://github.com/simulacre/em-ssh/commit/88323761c67c433bd46fedfd042ae9a97b726cb6) - Deal with ssh servers that send algo data and server version at the same time (Dropbear). Discovered by [@mandre](https://github.com/mandre)

0.6.5
- [#26](https://github.com/simulacre/em-ssh/issues/26) - Remove echo binary

0.6.4
- [#24](https://github.com/simulacre/em-ssh/issues/24) - Don't zap Em::Ssh::Shell callbacks when sharing them with Net::Ssh::Connection::Channel

0.6.3
- [#25](https://github.com/simulacre/em-ssh/issues/25) - Failed negotiations are properly caught

0.6.2
- [#24](https://github.com/simulacre/em-ssh/pull/24) - Fix callbacks defined on EM::Ssh::Shell don't work [@mandre](https://github.com/mandre)

0.6.1
 - Allow Shell#buffer to be cleared

0.6.0
 - Disconnect error codes are converted to Ruby exceptions and raised
 - ChannelOpen error codes are converted to Ruby exceptions and raised
 - Shell#split will detect ChannelOpen errors and raise an Exception

0.5.1
 - [#21](https://github.com/simulacre/em-ssh/pull/22) - Fix em-ssh throws exception when no logger is defined [@mandre](https://github.com/mandre)
 - [#20](https://github.com/simulacre/em-ssh/pull/20) - Fix Interactive timeout wasn't set if parameter not fed [@freakhill](https://github.com/freakhill)

0.5.0
 - Shell an Connection instances can have their own Loggers
 - [#18](https://github.com/simulacre/em-ssh/pull/18) - Target devices and options for specs can be configured through environment variables [@freakhill](https://github.com/freakhill)
 - [#19](https://github.com/simulacre/em-ssh/pull/19) - Decouple interactive behavior from Shell allowing for other channels to be extended with #expect, etc., [@freakhill](https://github.com/freakhill)

0.4.2
 - Connection accepts :nego_timeout (seconds to wait for protocol and algorithm negotiation to finish)
 - If protocol, or algorithm negotiation fail #errback will be called
 - Shell#disconnect! forcefully terminates the connection
 - Shell#disconnect takes a timeout
 - EM::Ssh::Session#close overrides Net::SSH::Connection::Session to check for
 transport before trying to close channels
 - Fixes: dangling references to EM::Timers are removed from EM::Ssh::Connection
 - Fixes: various dangling references to EM::Ssh::Connection and EM::Ssh::Session are properly removed

0.4.1
 - Connections terminated before version negotiation wil fail with EM::Ssh::ConnectionTermianted

0.3.0
 - Provides Shell#expect which can be used to wait for a string, or send a command and then wait
 - Connection errors are provided as Deferreds and don't halt the entire reactor
 - Shell timeouts are for inactivity and not total duration
 - Shell buffer is maintained until wait_for matches; results from send_cmd without a corresponding wait_for will be retained in the buffer.

0.1.0
 - Connection#initialize will fire :error Net::SSH::AuthenticationError when authentication fails rather than raising an error
 - Shell#open will catch :error fired by Connection#initialize and raise it as a ConnectionError
 - Shell no longer accepts :halt_on_timeout
 - Shell#wait_for will fire :error if timeout is reached
 - Key exchange exceptions will be caught and propagated through fire :error

0.0.3
 - Removes CPU pegging via recursive EM.next_tick
 - Adds an auto reconnect option to shell
