defmodule JargaWeb.AppLive.Workspaces.Edit do
  use JargaWeb, :live_view

  alias Jarga.Workspaces
  alias JargaWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto space-y-8">
        <div>
          <.header>
            Edit Workspace
            <:subtitle>
              <.link navigate={~p"/app/workspaces/#{@workspace.id}"} class="text-sm hover:underline">
                ← Back to {@workspace.name}
              </.link>
            </:subtitle>
          </.header>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <.form
              for={@form}
              id="workspace-form"
              phx-submit="save"
              class="space-y-4"
            >
              <.input
                field={@form[:name]}
                type="text"
                label="Name"
                placeholder="My Workspace"
                required
              />

              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                placeholder="Describe your workspace..."
              />

              <.input
                field={@form[:color]}
                type="text"
                label="Color"
                placeholder="#4A90E2"
              />

              <div class="flex gap-2 justify-end">
                <.link navigate={~p"/app/workspaces/#{@workspace.id}"} class="btn btn-ghost">
                  Cancel
                </.link>
                <.button type="submit" variant="primary">
                  Update Workspace
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(%{"id" => workspace_id}, _session, socket) do
    user = socket.assigns.current_scope.user

    # This will raise if user is not a member
    workspace = Workspaces.get_workspace!(user, workspace_id)
    changeset = Workspaces.Workspace.changeset(workspace, %{})

    {:ok,
     socket
     |> assign(:workspace, workspace)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    user = socket.assigns.current_scope.user
    workspace_id = socket.assigns.workspace.id

    case Workspaces.update_workspace(user, workspace_id, workspace_params) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace updated successfully")
         |> push_navigate(to: ~p"/app/workspaces/#{workspace.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update workspace")}
    end
  end
end
