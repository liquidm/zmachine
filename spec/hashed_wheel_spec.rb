require 'zmachine/hashed_wheel'

describe ZMachine::HashedWheel do
  let(:wheel) { ZMachine::HashedWheel.new(16, 100) }

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
    expect(timedout).to eq(1)
  end

  it 'calculates the timeout set correctly' do
    now = wheel.reset
    wheel.add 10
    wheel.add 40
    wheel.add 1900
    wheel.add 3300
    wheel.add 4000
    timedout = wheel.advance(now + 3900 * 1_000_000)
    expect(timedout).to eq(4)
  end

  it 'cancels timers correctly' do
    now = wheel.reset
    result = nil
    wheel.add(90, -> { result = true })
    wheel.add(110, -> { result = false }).cancel
    timedout = wheel.advance(now + 200 * 1_000_000)
    expect(result).to eq(true)
    expect(timedout).to eq(2)
  end

end
