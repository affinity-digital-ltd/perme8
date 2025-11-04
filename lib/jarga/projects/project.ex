defmodule Jarga.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field :name, :string
    field :description, :string
    field :color, :string
    field :is_default, :boolean, default: false
    field :is_archived, :boolean, default: false

    belongs_to :user, Jarga.Accounts.User
    belongs_to :workspace, Jarga.Workspaces.Workspace

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :color, :is_default, :is_archived, :user_id, :workspace_id])
    |> validate_required([:name, :user_id, :workspace_id])
    |> validate_length(:name, min: 1)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
  end
end
