defmodule Rumbl.InfoSys do
  @backends [Rumbl.InfoSys.Wolfram]
  # module attribute

  defmodule Result do
    # result struct to hold each search result
    defstruct score: 0, text: nil, url: nil, backend: nil
  end

  def start_link(backend, query, query_ref, owner, limit) do
    # this is the proxy
    # supervisor calls start_child, which invokes this
    backend.start_link(query, query_ref, owner, limit)
    # starts the backend to computs its own results
  end

  def compute(query, opts \\ []) do
    limit = opts[:limit] || 10
    backends = opts[:backends] || @backends

    backends
    |> Enum.map(&spawn_query(&1, query, limit))
    #spawn_query starts a child, gives it options
    |> await_results(opts)
    # waits for results
    |> Enum.sort(&(&1.score >= &2.score))
    |> Enum.take(limit)
  end

  defp spawn_query(backend, query, limit) do
    query_ref = make_ref()
    opts = [backend, query, query_ref, self(), limit]
    {:ok, pid} = Supervisor.start_child(Rumbl.InfoSys.Supervisor, opts)
    monitor_ref = Process.monitor(pid)
    {pid, monitor_ref, query_ref}
  end

  defp await_results(children, opts) do
    timeout = opts[:timeout] || 5000
    timer = Process.send_after(self(), :timedout, timeout)
    results = await_result(children, [], :infinity)
    cleanup(timer)
    results
  end

  defp await_result([head|tail], acc, timeout) do
    {pid, monitor_ref, query_ref} = head

    receive do
      {:results, ^query_ref, results} -> 
        Process.demonitor(monitor_ref, [:flush])
        # flush option guarnatees that the :DOWN message is removed from inbox
        # in case it's delivered before we drop the monitor
        await_result(tail, results ++ acc, timeout)
      {:DOWN, ^monitor_ref, :process, ^pid, _reason} ->
      # :DOWN messages come from the monitor, not the GenServer
        await_result(tail, acc, timeout)
      :timedout -> 
        # kill the backend we're waiting on
        # move to await the next one
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)
        # this timeout change to 0 triggers the after branch of the receive
        # call for subsequent backends
    after
      timeout -> 
        # why call kill twice?
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)
    end
  end

  defp await_result([], acc, _) do
    # Breaks the recursion after list is consumed
    acc
  end

  defp kill(pid, ref) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
  end

  defp cleanup(timer) do
    :erlang.cancel_timer(timer)
    receive do
      :timedout -> :ok
    after
      0 -> :ok
    end
  end
end
