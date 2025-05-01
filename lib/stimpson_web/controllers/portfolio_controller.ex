defmodule StimpsonWeb.PortfolioController do
  use StimpsonWeb, :controller

  alias Stimpson.Portfolio

  def index(conn, _params) do
    render(conn, "index.html", layout: false, projects: Portfolio.published_projects())
  end

  def show(conn, %{"id" => id}) do
    render(conn, "show.html", layout: false, project: Portfolio.get_project_by_id!(id))
  end
end
