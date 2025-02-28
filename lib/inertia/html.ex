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

  @doc """
  Renders a `<title>` tag that includes the `inertia` attribute needed for the
  Inertia.js client-side to subsequently manage the page title.

  The content you provide to this component will only apply to the initial
  server-rendered response. You will also need to use the [client-side `<Head>`
  component](https://inertiajs.com/title-and-meta) in your Inertia page
  components to be sure the the page title is updated when internal navigation
  occurs.

  If you are planning to manage page titles from the server-side, you may find
  it useful to expose the `page_title` via regular assigns (so your
  `<.inertia_title>` can use it) AND via Inertia page props (so your client-side
  `<Head>` use it):

      def index(conn, _params)
        page_title = "Your page title"

        conn
        |> assign(:page_title, page_title)
        |> assign_prop(:page_title, page_title)
        |> render_inertia("YourPage")
      end

  """
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
