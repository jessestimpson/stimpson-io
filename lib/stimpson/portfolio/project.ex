defmodule Stimpson.Portfolio.Project do
  @enforce_keys [:id, :author, :title, :body, :description, :tags, :featured, :published]
  defstruct [
    :id,
    :author,
    :title,
    :img,
    :logo,
    :body,
    :description,
    :tags,
    :featured,
    :published,
    :github,
    :hexpm,
    :hexdocs,
    :link
  ]

  def build(filename, attrs, body) do
    [id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-1)
    struct!(__MODULE__, [id: id, body: body] ++ Map.to_list(attrs))
  end
end
