defmodule Stimpson.Portfolio do
  alias Stimpson.Portfolio.Project

  use NimblePublisher,
    build: Project,
    from: Application.app_dir(:stimpson, "priv/projects/*.md"),
    as: :projects,
    highlighters: [:makeup_elixir, :makeup_erlang]

  defmodule NotFoundError, do: defexception([:message, plug_status: 404])

  @projects Enum.sort_by(@projects, & &1.featured)

  # Let's also get all tags
  @tags @projects |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  # And finally export them
  def all_projects, do: @projects
  def all_tags, do: @tags
  def published_projects, do: Enum.filter(all_projects(), &(&1.published == true))

  def featured_projects(n \\ 100_000),
    do: Enum.filter(published_projects(), &(&1.featured != false)) |> Enum.take(n)

  def get_project_by_id!(id) do
    Enum.find(all_projects(), &(&1.id == id)) ||
      raise NotFoundError, "project with id=#{id} not found"
  end

  def get_projects_by_tag!(tag) do
    case Enum.filter(all_projects(), &(tag in &1.tags)) do
      [] -> raise NotFoundError, "projects with tag=#{tag} not found"
      projects -> projects
    end
  end
end
