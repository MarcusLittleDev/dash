defmodule DashWeb.Router do
  use DashWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DashWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "You must be logged in")
      |> Phoenix.Controller.redirect(to: "/sign-in")
      |> Plug.Conn.halt()
    end
  end

  scope "/", DashWeb do
    pipe_through :browser

    get "/", PageController, :home

    sign_in_route(
      register_path: "/register",
      reset_path: "/reset",
      auth_routes_prefix: "/auth"
    )

    # ✅ FIXED: Second argument is the path string, or omitted for default "/sign-out"
    sign_out_route(AuthController, "/sign-out")

    reset_route()
  end

  scope "/", DashWeb do
    pipe_through [:browser, :require_authenticated_user]
    # Add protected routes here
  end

  scope "/auth" do
    pipe_through :browser

    auth_routes(Dash.Accounts.User, otp_app: :dash)
  end

  if Application.compile_env(:dash, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: DashWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
