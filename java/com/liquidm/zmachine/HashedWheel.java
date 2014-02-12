package com.liquidm.zmachine;

import java.lang.System;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.concurrent.Callable;

public class HashedWheel
{
	private class Timeout
	{
		long deadline;
		Object callback;
		boolean canceled;

		public Timeout(long deadline, Object callback)
		{
			this.deadline = deadline;
			this.callback = callback;
			this.canceled = false;
		}

		public Object getCallback()
		{
			return this.callback;
		}

		public void cancel()
		{
			this.canceled = true;
		}

		public boolean isCanceled()
		{
			return this.canceled;
		}
	}

	int number_of_slots;
	long tick_length;
	Object[] slots;
	int current_tick;
	long last;

	public HashedWheel(int number_of_slots, long tick_length)
	{
		this.number_of_slots = number_of_slots;
		this.tick_length = tick_length * 1000000; // ms to ns
		reset();
	}

	@SuppressWarnings("unchecked")
	public Object[] getSlots()
	{
		return this.slots;
	}

	public Timeout add(int timeout)
	{
		return add(timeout, null);
	}

	@SuppressWarnings("unchecked")
	public Timeout add(long timeout, Object callback)
	{
		timeout = timeout * 1000000; // ms to ns
		long ticks = timeout / this.tick_length;
		int slot = (int)((this.current_tick + ticks) % this.number_of_slots);
		long deadline = System.nanoTime() + timeout;
		Timeout hwt = new Timeout(deadline, callback);
		ArrayList<Timeout> list = (ArrayList<Timeout>) this.slots[slot];
		list.add(hwt);
		return hwt;
	}

	public long reset()
	{
		return reset(System.nanoTime());
	}

	public long reset(long last)
	{
		this.slots = new Object[this.number_of_slots];
		for (int i = 0; i < this.number_of_slots; i++) {
			this.slots[i] = new ArrayList<Timeout>();
		}
		this.current_tick = 0;
		this.last = last;
		return last;
	}

	public ArrayList<Timeout> advance()
	{
		return advance(System.nanoTime());
	}

	@SuppressWarnings("unchecked")
	public ArrayList<Timeout> advance(long now)
	{
		long passed_ticks = (now - this.last) / this.tick_length;
		ArrayList<Timeout> result = new ArrayList<Timeout>();
		do {
			this.current_tick = this.current_tick % this.number_of_slots;
			Iterator<Timeout> it = ((ArrayList<Timeout>)this.slots[this.current_tick]).iterator();
			while (it.hasNext()) {
				Timeout timeout = it.next();
				if (timeout.deadline < now) {
					if (!timeout.isCanceled()) {
						result.add(timeout);
					}
					it.remove();
				}
			}
			this.current_tick += 1;
			passed_ticks -= 1;
		} while (passed_ticks > 0);
		this.last = now;
		return result;
	}
}
