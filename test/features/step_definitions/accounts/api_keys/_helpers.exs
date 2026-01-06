defmodule Jarga.Accounts.ApiKeys.Helpers do
  @moduledoc """
  Shared helper functions for API Key step definitions.
  """

  alias Ecto.Adapters.SQL.Sandbox

  def ensure_sandbox_checkout do
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end
  end

  def build_workspace_owners(table_data, users) do
    Enum.reduce(table_data, %{}, fn row, acc ->
      slug = row["Slug"]
      owner_email = row["Owner"]
      owner = Map.get(users, owner_email)
      Map.put(acc, slug, owner)
    end)
  end

  def parse_workspace_access(nil), do: []
  def parse_workspace_access(""), do: []

  def parse_workspace_access(workspace_access_str) do
    workspace_access_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end
end
