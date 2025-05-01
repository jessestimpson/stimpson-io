defmodule StimpsonWeb.Router do
  use StimpsonWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StimpsonWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", StimpsonWeb do
    pipe_through :browser

    get "/", PageController, :default
    get "/home", PageController, :home

    get "/makesure", BlogController, :index
    get "/makesure/:id", BlogController, :show

    get "/projects", PortfolioController, :index
    get "/projects/:id", PortfolioController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", StimpsonWeb do
  #   pipe_through :api
  # end
end
