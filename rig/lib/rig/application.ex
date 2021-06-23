defmodule Rig.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Cluster.Supervisor, [
          [local: [strategy: Cluster.Strategy.LocalEpmd]],
          [name: Rig.ClusterSupervisor]]},
      {Registry, keys: :unique, name: Rig.Registry},
      Rig.Firecracker.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Rig.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Rig.Firecracker.Supervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule Rig.Firecracker.Instance do
  use GenServer, restart: :temporary
  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state,
      name: {:via, Registry, {Rig.Registry, {:rig, state}}})
  end

  @impl true
  def init(number) do
    Logger.info("rig #{number}: starting")

    {:ok, pid, os_pid} =
      Exexec.run_link(
        "rig-start #{number}",
        stdout: self(),
        stderr: self(),
        kill_command: "kill ${CHILD_PID}"
      )

    Logger.info("rig #{number}: started with pid #{os_pid} #{inspect(pid)}")

    {:ok, %{
        pid: pid,
        os_pid: os_pid,
        hostname: "tap#{number}.local",
        number: number
     }}
  end

  @impl true
  def handle_call(:stop, _, %{os_pid: pid} = state) do
    :ok = Exexec.stop(pid)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info({:stdout, _pid, line}, state) do
#    Logger.debug("rig #{state.number} out: #{line}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:stderr, _pid, line}, state) do
    Logger.debug("rig #{state.number} err: #{line}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    case reason do
      :normal ->
        nil
      _ ->
        Exexec.stop_and_wait(state.pid)
    end
    Logger.info("rig #{state.number} terminating: #{inspect(reason)}")
    :ok
  end
end
