defmodule Jarga.Pages.Queries do
  @moduledoc """
  Query objects for the Pages context.
  Provides composable query functions for building database queries.
  """

  import Ecto.Query
  alias Jarga.Pages.Page
  alias Jarga.Accounts.User

  @doc """
  Base query for pages.
  """
  def base do
    from p in Page, as: :page
  end

  @doc """
  Filter pages by user.
  """
  def for_user(query, %User{id: user_id}) do
    from [page: p] in query,
      where: p.user_id == ^user_id
  end

  @doc """
  Filter pages by workspace.
  """
  def for_workspace(query, workspace_id) do
    from [page: p] in query,
      where: p.workspace_id == ^workspace_id
  end

  @doc """
  Filter pages by project.
  """
  def for_project(query, project_id) do
    from [page: p] in query,
      where: p.project_id == ^project_id
  end

  @doc """
  Filter pages by ID.
  """
  def by_id(query, page_id) do
    from [page: p] in query,
      where: p.id == ^page_id
  end

  @doc """
  Filter pages by slug.
  """
  def by_slug(query, slug) do
    from [page: p] in query,
      where: p.slug == ^slug
  end

  @doc """
  Order pages by creation date (newest first).
  """
  def ordered(query) do
    from [page: p] in query,
      order_by: [desc: p.inserted_at]
  end
end
