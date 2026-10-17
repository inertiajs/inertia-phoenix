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
  Renders a `<title>` tag that includes the `data-inertia` attribute needed for the
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
    <title data-prefix={@prefix} data-suffix={@suffix} data-inertia>
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
    <div id="app"></div>
    <script data-page="app" type="application/json" nonce={@csp_nonce}>
      <%= Phoenix.HTML.raw(encode_page(@page)) %>
    </script>
    <.devtools_id devtools={@inertia_devtools} />
    """
  end

  @doc false
  def inertia_ssr(assigns) do
    ~H"""
    {Phoenix.HTML.raw(@body)}
    <.devtools_id devtools={@inertia_devtools} />
    """
  end

  # The DevTools extension cannot see the response headers of the initial page
  # load, so the id of its recorded entry is rendered into the page instead.
  defp devtools_id(assigns) do
    ~H"""
    <script
      :if={@devtools}
      data-inertia-devtools-id
      data-inertia-devtools-base-path={@devtools.base_path}
      type="application/json"
    >
      <%= Phoenix.HTML.raw(json_library().encode!(@devtools.id)) %>
    </script>
    """
  end

  # Escapes `<` so a prop value containing `</script>` (or `<!--`) cannot end
  # the surrounding `<script>` tag early. `\u003c` is a valid JSON escape, so
  # the page data parses to the same value. This is done on the encoded
  # output (rather than via a Jason-specific option) so it holds for any
  # configured JSON library.
  defp encode_page(page) do
    page
    |> json_library().encode!()
    |> IO.iodata_to_binary()
    |> String.replace("<", "\\u003c")
  end

  defp json_library do
    Phoenix.json_library()
  end
end
