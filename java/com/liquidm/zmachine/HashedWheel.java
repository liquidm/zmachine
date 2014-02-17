package com.liquidm.zmachine;

import java.lang.System;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.concurrent.Callable;

public class HashedWheel
{
	private class Timeout implements Comparable<Timeout>
	{
		private long deadline;
		private Callable<Object> callback;
		private boolean canceled;

		public Timeout(long deadline, Callable<Object> callback)
		{
			this.deadline = deadline;
			this.callback = callback;
			this.canceled = false;
		}

		public int compareTo(Timeout other)
		{
			return (int)(this.deadline - other.getDeadline());
		}

		public long getDeadline()
		{
			return this.deadline;
		}

		public Object getCallback()
		{
			return this.callback;
		}

		public void call() throws Exception
		{
			if (this.callback != null) {
				this.callback.call();
				this.cancel();
			}
		}

		public void cancel()
		{
			this.callback = null;
			this.canceled = true;
		}

		public boolean isCanceled()
		{
			return this.canceled;
		}
	}

	int number_of_slots;
	ArrayList<SortedSet<Timeout>> slots;

	long tick_length;
	int current_tick;

	long last;

	public HashedWheel(int number_of_slots, long tick_length)
	{
		this.number_of_slots = number_of_slots;
		this.tick_length = tick_length * 1000000; // ms to ns
		reset();
	}

	public ArrayList<SortedSet<Timeout>> getSlots()
	{
		return this.slots;
	}

	public Timeout add(int timeout)
	{
		return add(timeout, null);
	}

	@SuppressWarnings("unchecked")
	public Timeout add(long timeout, Callable<Object> callback)
	{
		timeout = timeout * 1000000; // ms to ns
		long deadline = System.nanoTime() + timeout;
		long ticks = timeout / this.tick_length;
		int slot = (int)((this.current_tick + ticks) % this.number_of_slots);
		Timeout hwt = new Timeout(deadline, callback);
		SortedSet<Timeout> timeouts = this.slots.get(slot);
		timeouts.add(hwt);
		return hwt;
	}

	public long reset()
	{
		return reset(System.nanoTime());
	}

	public long reset(long last)
	{
		this.slots = new ArrayList<SortedSet<Timeout>>(this.number_of_slots);
		for (int i = 0; i < this.number_of_slots; i++) {
			this.slots.add(i, new TreeSet<Timeout>());
		}
		this.current_tick = 0;
		this.last = last;
		return last;
	}

	public int advance() throws Exception
	{
		return advance(System.nanoTime());
	}

	public int advance(long now) throws Exception
	{
		int timedout = 0;
		long passed_ticks = (now - this.last) / this.tick_length;
		do {
			this.current_tick = this.current_tick % this.number_of_slots;
			SortedSet<Timeout> timeouts = this.slots.get(this.current_tick);
			Iterator<Timeout> it = timeouts.iterator();
			while (it.hasNext()) {
				Timeout timeout = it.next();
				long deadline = timeout.getDeadline();
				if (deadline > now) {
					break;
				}
				timedout++;
				timeout.call();
				it.remove();
			}
			this.current_tick += 1;
			passed_ticks -= 1;
		} while (passed_ticks > 0);
		this.last = now;
		return timedout;
	}
}
