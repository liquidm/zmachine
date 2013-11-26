# ZMachine

ZMachine is a pure JRuby multi-threaded event loop based on java.nio.Selector
and a hashed wheel timer implementation. ZMachine supports TCP and ZeroMQ
sockets natively and exposes an EventMachine compatible API where possible.

[![Gem Version](https://badge.fury.io/rb/zmachine.png)](http://badge.fury.io/rb/zmachine)
[![Build Status](https://travis-ci.org/liquidm/zmachine.png)](https://travis-ci.org/liquidm/zmachine)
[![Code Climate](https://codeclimate.com/github/liquidm/zmachine.png)](https://codeclimate.com/github/liquidm/zmachine)
[![Dependency Status](https://gemnasium.com/liquidm/zmachine.png)](https://gemnasium.com/liquidm/zmachine)

## Installation

Add this line to your application's Gemfile:

    gem 'zmachine'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install zmachine

## Usage

ZMachine is mostly API compatible with EventMachine. Replace `EM` /
`EventMachine` with `ZMachine` in your code and it should work out of the box.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
