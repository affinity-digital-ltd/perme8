defmodule Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy do
  @moduledoc """
  Pure business rules for API key workspace access.

  This module defines validation rules for API key workspace access.
  All functions are deterministic with zero infrastructure dependencies.

  ## Access Validation Rules

  - Workspace access list can be empty (no workspace access)
  - Workspace access list can contain valid workspace slugs
  - Workspace slugs cannot be duplicated
  - Workspace slugs cannot be nil

  """

  @doc """
  Validates workspace access list format.

  Returns `:ok` if the workspace access list is valid, `:error` otherwise.

  ## Validation Rules

  - List can be empty (no workspace access)
  - All items must be non-nil strings
  - No duplicate workspace slugs allowed

  ## Parameters

    - `workspace_slugs` - List of workspace slugs to validate

  ## Returns

  - `:ok` - Workspace access list is valid
  - `:error` - Workspace access list is invalid

  ## Examples

      iex> WorkspaceAccessPolicy.valid_workspace_access?([])
      :ok

      iex> WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", "workspace2"])
      :ok

      iex> WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", "workspace1"])
      :error

      iex> WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", nil])
      :error

  """
  def valid_workspace_access?(workspace_slugs) when is_list(workspace_slugs) do
    # Check for nil values
    if Enum.any?(workspace_slugs, &is_nil/1) do
      :error
    else
      # Check for duplicates
      if length(workspace_slugs) == length(Enum.uniq(workspace_slugs)) do
        :ok
      else
        :error
      end
    end
  end

  @doc """
  Checks if an API key has access to a workspace.

  Returns `true` if the workspace is in the API key's access list.

  ## Parameters

    - `api_key` - ApiKey domain entity (must have `workspace_access` field)
    - `workspace_slug` - Workspace slug to check

  ## Returns

  Boolean indicating if API key has workspace access

  ## Examples

      iex> api_key = %{workspace_access: ["workspace1", "workspace2"]}
      iex> WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace1")
      true

      iex> WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace3")
      false

  """
  def has_workspace_access?(%{workspace_access: workspace_slugs}, workspace_slug) do
    workspace_slug in workspace_slugs
  end
end
