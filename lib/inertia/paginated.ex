defprotocol Inertia.Paginated do
  @moduledoc """
  Protocol for normalizing a paginated result into scroll metadata (and,
  optionally, the page's entries) for use with `Inertia.Controller.inertia_scroll/2`.

  Implementations return a map. Pagination structs that *carry* their own entries
  (such as `Scrivener.Page`) include an `:entries` key; metadata-only structs
  (such as `Flop.Meta`, where the records are returned separately) omit it, and
  the entries are taken from the `{entries, meta}` tuple passed to `inertia_scroll`.

  ## Return value

  A map with any of the following keys (omitted keys fall back to defaults):

  - `:entries` - The list of items on the page (include this only for
    self-contained pagination structs)
  - `:page_name` - The query parameter name for pagination (defaults to `"page"`)
  - `:current_page` - The current page
  - `:previous_page` - The previous page, or `nil` if on the first page
  - `:next_page` - The next page, or `nil` if on the last page

  ## Example: a struct that carries its entries

      defimpl Inertia.Paginated, for: Scrivener.Page do
        def to_scroll(%{entries: entries, page_number: page, total_pages: total}) do
          %{
            entries: entries,
            current_page: page,
            previous_page: if(page > 1, do: page - 1),
            next_page: if(page < total, do: page + 1)
          }
        end
      end

  ## Example: a metadata-only struct

      defimpl Inertia.Paginated, for: MyPaginator.Meta do
        def to_scroll(meta) do
          %{
            current_page: meta.current_page,
            previous_page: meta.previous_page,
            next_page: meta.next_page
          }
        end
      end

      # used as:
      assign_prop(conn, :users, inertia_scroll({records, meta}))
  """

  @doc """
  Normalizes paginated data into a scroll metadata map, optionally including `:entries`.
  """
  @spec to_scroll(t) :: map()
  def to_scroll(data)
end
