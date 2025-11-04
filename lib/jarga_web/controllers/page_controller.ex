defmodule JargaWeb.PageController do
  use JargaWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: {JargaWeb.Layouts, :app})
  end
end
