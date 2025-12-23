defmodule StarTicketsWeb.PageController do
  use StarTicketsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
