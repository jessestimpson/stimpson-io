defmodule StimpsonWeb.BlogController do
  use StimpsonWeb, :controller

  alias Stimpson.Blog

  @page_title "Make Sure"

  def index(conn, _params) do
    conn
    |> assign(:page_title, @page_title)
    |> render("index.html", layout: false, posts: Blog.published_posts())
  end

  def show(conn, %{"id" => id}) do
    conn
    |> assign(:page_title, @page_title)
    |> render("show.html", layout: false, post: Blog.get_post_by_id!(id))
  end
end
