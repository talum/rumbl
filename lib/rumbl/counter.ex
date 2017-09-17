defmodule Rumbl.Counter do
  # pid is id of server process
  def inc(pid), do: send(pid, :inc)
  
  def dec(pid), do: send(pid, :dec)

  def val(pid, timeout \\ 5000) do
    # make_ref() is a unique reference to the request
    ref = make_ref()
              # 3-tuple with an atom
    send(pid, {:val, self(), ref})
    receive do
      # only match on tuples that have the exact ref
      # exit after timeout if no match
      {^ref, val} -> val
    after timeout -> exit(:timeout)
    end
  end

  def start_link(initial_val) do
    {:ok, spawn_link(fn -> listen(initial_val) end)}
  end

  # server
  defp listen(val) do
    # using recursion to manage state
    # When the last thing you do in a function is call the function itself,
    # the function is tail recursive
    # normally bad, but elixir processes are cheap
    receive do
      :inc -> listen(val + 1)
      :dec -> listen(val - 1)
      {:val, sender, ref} -> 
        send sender, {ref, val}
        listen(val)
    end
  end
end
