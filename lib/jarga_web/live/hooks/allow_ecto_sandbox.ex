defmodule JargaWeb.Live.Hooks.AllowEctoSandbox do
  @moduledoc """
  LiveView hook to allow Ecto sandbox for Wallaby tests.

  This ensures database transactions are shared between the test process
  and the LiveView process handling WebSocket connections.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Phoenix.Ecto.SQL.Sandbox

  def on_mount(:default, _params, _session, socket) do
    allow_ecto_sandbox(socket)
    {:cont, socket}
  end

  defp allow_ecto_sandbox(socket) do
    %{assigns: %{phoenix_ecto_sandbox: metadata}} =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        if connected?(socket), do: get_connect_info(socket, :user_agent)
      end)

    # Only allow sandbox access if both metadata and sandbox config exist
    # This prevents errors when LiveView processes start during test teardown
    if metadata && Application.get_env(:jarga, :sandbox) do
      Sandbox.allow(metadata, Application.get_env(:jarga, :sandbox))
    end
  end
end
