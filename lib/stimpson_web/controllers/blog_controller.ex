defmodule StimpsonWeb.BlogController do
  use StimpsonWeb, :controller

  alias Stimpson.Blog

  def index(conn, _params) do
    render(conn, "index.html", layout: false, posts: Blog.published_posts())
  end

  def show(conn, %{"id" => id}) do
    render(conn, "show.html", layout: false, post: Blog.get_post_by_id!(id))
  end
end
