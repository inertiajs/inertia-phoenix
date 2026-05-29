if match?({:module, _}, Code.ensure_compiled(Flop.Meta)) do
  defimpl Inertia.Paginated, for: Flop.Meta do
    @moduledoc """
    First-party `Inertia.Paginated` implementation for `Flop.Meta`.

    Flop returns records separately from their metadata (`Flop.run/3` returns a
    `{records, %Flop.Meta{}}` tuple), so the implementation provides metadata only
    (no `:entries`) and you pass the tuple directly to `inertia_scroll/2`:

        {users, meta} = Flop.run(query, params)

        conn
        |> assign_prop(:users, inertia_scroll({users, meta}))
        |> render_inertia("Users/Index")

    Only page/offset-based pagination is supported. Cursor-based Flop pagination
    uses `:after`/`:before` cursors that don't map onto the single page-number
    scroll model; supply a custom `:metadata` function to `inertia_scroll/2` for
    that case.

    Flop's page query parameter is assumed to be `"page"`. If you've configured a
    different parameter name, override it with the `:page_name` option.
    """
    # Flop populates `current_page` for page- and offset-based pagination and
    # leaves it nil only for cursor-based pagination (where the page-number scroll
    # model doesn't apply).
    def to_scroll(%Flop.Meta{current_page: nil}) do
      raise ArgumentError, """
      cursor-based Flop pagination is not supported by Inertia.Paginated.

      The infinite-scroll metadata model uses a single page name with integer
      page numbers, which does not map onto Flop's :after/:before cursors. Pass a
      custom :metadata function to inertia_scroll/2 to handle cursor pagination.
      """
    end

    # page_name is omitted; it defaults to "page" downstream (override per call
    # with the :page_name option if you've configured a different parameter).
    def to_scroll(%Flop.Meta{} = meta) do
      %{
        current_page: meta.current_page,
        previous_page: meta.previous_page,
        next_page: meta.next_page
      }
    end
  end
end
