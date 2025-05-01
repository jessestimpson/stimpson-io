defmodule StimpsonWeb.PageController do
  use StimpsonWeb, :controller

  alias Stimpson.Portfolio
  alias Stimpson.Blog

  def home(conn, _params) do
    render(conn, :home,
      featured_projects: Portfolio.featured_projects(3),
      latest_articles: Blog.recent_posts(3)
    )
  end

  def default(conn, _params) do
    redirect(conn, to: ~p"/makesure")
  end
end
