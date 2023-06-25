defmodule Inertia.HTML do
  use Phoenix.Component

  def page(%{conn: %{private: %{inertia: inertia}}} = assigns) do
    ~H"""
    <div id="app" data-page={Phoenix.json_library().encode!(inertia)}></div>
    """
  end
end
