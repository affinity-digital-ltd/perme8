defmodule JargaWeb.AppLive.Dashboard do
  use JargaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div>
          <.header>
            Welcome to Jarga
            <:subtitle>Your authenticated dashboard</:subtitle>
          </.header>
        </div>

        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <.link
            navigate={~p"/app/editor"}
            class="card bg-base-200 hover:bg-base-300 transition-colors"
          >
            <div class="card-body">
              <h2 class="card-title">Editor</h2>
              <p>Create and edit documents with real-time collaboration.</p>
            </div>
          </.link>

          <.link
            navigate={~p"/users/settings"}
            class="card bg-base-200 hover:bg-base-300 transition-colors"
          >
            <div class="card-body">
              <h2 class="card-title">Settings</h2>
              <p>Manage your account email address and password settings.</p>
            </div>
          </.link>
        </div>

        <div class="divider"></div>

        <div class="space-y-4">
          <h3 class="text-lg font-semibold">Quick Actions</h3>
          <div class="flex gap-2">
            <.button variant="primary" phx-click="new_document">
              New Document
            </.button>
            <.button variant="outline" navigate={~p"/app/editor"}>
              Browse Documents
            </.button>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("new_document", _params, socket) do
    # Generate a new document ID and redirect to the editor
    doc_id = Ecto.UUID.generate()
    {:noreply, push_navigate(socket, to: ~p"/app/editor/#{doc_id}")}
  end
end
