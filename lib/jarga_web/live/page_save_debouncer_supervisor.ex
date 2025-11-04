defmodule JargaWeb.PageSaveDebouncerSupervisor do
  @moduledoc """
  DynamicSupervisor for PageSaveDebouncer processes.
  Creates one debouncer per active page.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
