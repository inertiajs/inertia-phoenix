defmodule MyAppWeb.Plugs.ShareUser do
  @moduledoc false

  import Inertia.Controller
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign_prop(:current_user, %{name: "Alice"})
    |> assign(:shared_user, true)
  end
end
