defmodule TrueBGWeb.Router do
  use TrueBGWeb, :router

  pipeline :api do
    plug TrueBG.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TrueBG.Auth.Pipeline.Secure
  end

  scope "/api", TrueBGWeb do
    pipe_through :api
    get "/ping", PingController, :ping
    post "/sessions", SessionController, :create
  end

  scope "/api", TrueBGWeb do
    pipe_through [:api, :api_secure]
    get "/sessions", SessionController, :ping
    delete "/sessions", SessionController, :destroy
    resources "/users", UserController, except: [:new, :edit]
    resources "/domain_groups", DomainGroupController, except: [:new, :edit]
  end

end
