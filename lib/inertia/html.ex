defmodule Inertia.HTML do
  @moduledoc """
  HTML components for Inertia views.
  """

  use Phoenix.Component

  @doc type: :component
  attr(:prefix, :string,
    default: nil,
    doc: "A prefix added before the content of `inner_block`."
  )

  attr(:suffix, :string, default: nil, doc: "A suffix added after the content of `inner_block`.")
  slot(:inner_block, required: true, doc: "Content rendered inside the `title` tag.")

  def inertia_title(assigns) do
    ~H"""
    <title data-prefix={@prefix} data-suffix={@suffix} inertia>
      {@prefix}{render_slot(@inner_block)}{@suffix}
    </title>
    """
  end

  @doc type: :component
  attr(:content, :list, required: true, doc: "The list of tags to inject into the `head` tag.")

  def inertia_head(assigns) do
    ~H"""
    {Phoenix.HTML.raw(Enum.join(@content, "\n"))}
    """
  end

  @doc false
  def inertia_page(assigns) do
    ~H"""
    <div id="app" data-page={json_library().encode!(@page)}></div>
    """
  end

  @doc false
  def inertia_ssr(assigns) do
    ~H"""
    {Phoenix.HTML.raw(@body)}
    """
  end

  defp json_library do
    Phoenix.json_library()
  end
end
