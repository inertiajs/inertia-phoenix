defmodule Inertia.HTML do
  use Phoenix.Component

  def page(assigns) do
    ~H"""
    <div id="app" data-page={json_library().encode!(%{component: @component, props: @props, url: @url, version: @version})}></div>
    """
  end

  defp json_library do
    Phoenix.json_library()
  end
end
