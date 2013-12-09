require 'zmachine/hashed_wheel'

describe ZMachine::HashedWheel do
  let(:wheel) { ZMachine::HashedWheel.new(16, 0.1) }

  it 'returns a timeout on add' do
    expect(wheel.add(0)).to be_instance_of(ZMachine::HashedWheelTimeout)
  end

  it 'adds timeouts to the correct slot' do
    wheel.add 0
    wheel.add 0.090
    wheel.add 0.110
    wheel.add 1.000
    wheel.add 1.600
    wheel.add 3.200
    expect(wheel.slots[0].length).to eq(4)
    expect(wheel.slots[1].length).to eq(1)
    expect(wheel.slots[10].length).to eq(1)
  end

  it 'times out same slot timeouts correctly' do
    now = wheel.reset
    wheel.add 0.01
    wheel.add 0.05
    timedout = wheel.advance(now + 30 * 1_000_000)
    expect(timedout.length).to eq(1)
  end

  it 'calculates the timeout set correctly' do
    now = wheel.reset
    wheel.add 0.010
    wheel.add 0.040
    wheel.add 1.900
    wheel.add 3.300
    wheel.add 4.000
    timedout = wheel.advance(now + 3900 * 1_000_000)
    expect(timedout).to be
    expect(timedout.length).to eq(4)
  end

  it 'cancels timers correctly' do
    now = wheel.reset
    t1 = wheel.add 0.090
    t2 = wheel.add 0.110
    t1.cancel
    timedout = wheel.advance(now + 200 * 1_000_000)
    expect(timedout).to eq([t2])
    expect(timedout.length).to eq(1)
  end

end
