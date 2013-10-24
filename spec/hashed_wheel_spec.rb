require 'spec_helper'
require 'lib/zmachine/hashed_wheel'

describe ZMachine::HashedWheelTimeout do
  it 'calculates the stop index correctly'
  it 'calculates remaining rounds correctly'
  it 'can be cancelled'
  it 'supports an action'
end

describe ZMachine::HashedWheel do
  let(:wheel) { ZMachine::HashedWheel.new(16, 100) }

  it 'returns a timeout on add' do
    expect(wheel.add(0)).to be_instance_of(ZMachine::HashedWheelTimeout)
  end

  it 'adds timeouts to the correct slot' do
    wheel.add 0
    wheel.add 90
    wheel.add 110
    wheel.add 1000
    wheel.add 1600
    wheel.add 3200
    expect(wheel.slots[0].length).to eq(4)
    expect(wheel.slots[1].length).to eq(1)
    expect(wheel.slots[10].length).to eq(1)
  end

  it 'times out same slot timeouts correctly' do
    now = wheel.reset
    wheel.add 10
    wheel.add 50
    timedout = wheel.advance(now + 30 * 1_000_000)
    expect(timedout.length).to eq(1)
  end

  it 'calculates the timeouted set correctly' do
    now = wheel.reset
    wheel.add 10
    wheel.add 40
    wheel.add 1900
    wheel.add 3300
    wheel.add 4000
    timedout = wheel.advance( now + 3900 * 1_000_000)
    expect(timedout).to be
    expect(timedout.length).to eq(4)
  end
end