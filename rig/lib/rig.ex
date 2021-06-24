defmodule Rig do
  def start(number) do
    DynamicSupervisor.start_child(
      Rig.Firecracker.Supervisor,
      {Rig.Firecracker.Instance, number}
    )
  end

  def stop(number) do
    GenServer.call({:via, Registry, {Rig.Registry, {:rig, number}}}, :stop)
  end
end
