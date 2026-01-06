defmodule Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Policies.WorkspaceAccessPolicy

  describe "valid_workspace_access?/1" do
    test "accepts empty list" do
      assert WorkspaceAccessPolicy.valid_workspace_access?([]) == :ok
    end

    test "accepts valid workspace slugs" do
      assert WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", "workspace2"]) == :ok
    end

    test "rejects duplicate workspace slugs" do
      assert WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", "workspace1"]) == :error
    end

    test "rejects nil workspace slugs" do
      assert WorkspaceAccessPolicy.valid_workspace_access?(["workspace1", nil]) == :error
    end
  end

  describe "has_workspace_access?/2" do
    setup do
      :ok
    end

    test "returns true for workspace in list" do
      api_key = %{
        workspace_access: ["workspace1", "workspace2"]
      }

      assert WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace1") == true
    end

    test "returns false for workspace not in list" do
      api_key = %{
        workspace_access: ["workspace1", "workspace2"]
      }

      assert WorkspaceAccessPolicy.has_workspace_access?(api_key, "workspace3") == false
    end
  end
end
