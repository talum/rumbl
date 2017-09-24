defmodule Rumbl.InfoSys.Supervisor do
  use Supervisor

  def start_link() do
    # starts the supervisor
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
                        # module name, initial state, reference to reach
                        # supervisor from anywhere with the name instead of
                        # pid
  end

  def init(_opts) do
    # initializes the workers
    children = [
      worker(Rumbl.InfoSys, [], restart: :temporary)
      # only child is a GenServer worker
    ]

    supervise children, strategy: :simple_one_for_one
    # begins to supervisor all of the workers 
    # simple_for_one doesn't start any children, but waits for us to
    # explicitly ask it to start a child process
  end
end
