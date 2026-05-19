defmodule ExhsWeb.PageController do
  use ExhsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
