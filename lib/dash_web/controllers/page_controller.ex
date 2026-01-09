defmodule DashWeb.PageController do
  use DashWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
