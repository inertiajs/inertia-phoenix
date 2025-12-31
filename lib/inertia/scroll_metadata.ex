defprotocol Inertia.ScrollMetadata do
  @moduledoc """
  Protocol for extracting scroll metadata from paginated data structures.

  This protocol allows different pagination libraries to provide their own
  implementation for extracting metadata needed by the InfiniteScroll component.

  ## Required Metadata

  Implementations should return a map with the following keys:

  - `:page_name` - The query parameter name for pagination (e.g., "page")
  - `:current_page` - The current page number
  - `:previous_page` - The previous page number, or nil if on first page
  - `:next_page` - The next page number, or nil if on last page

  ## Example Implementation

      defimpl Inertia.ScrollMetadata, for: Scrivener.Page do
        def to_scroll_metadata(page) do
          %{
            page_name: "page",
            current_page: page.page_number,
            previous_page: if(page.page_number > 1, do: page.page_number - 1),
            next_page: if(page.page_number < page.total_pages, do: page.page_number + 1)
          }
        end
      end
  """

  @doc """
  Extracts scroll metadata from paginated data.

  Returns a map with `:page_name`, `:current_page`, `:previous_page`, and `:next_page`.
  """
  @spec to_scroll_metadata(t) :: %{
          page_name: String.t(),
          current_page: integer() | String.t() | nil,
          previous_page: integer() | String.t() | nil,
          next_page: integer() | String.t() | nil
        }
  def to_scroll_metadata(data)
end

defimpl Inertia.ScrollMetadata, for: Map do
  @moduledoc """
  Default implementation for maps.

  Expects the map to have a `:meta` or `"meta"` key containing pagination info
  with the following structure:

      %{
        data: [...],
        meta: %{
          current_page: 1,
          next_page: 2,
          previous_page: nil,
          page_name: "page"
        }
      }
  """
  def to_scroll_metadata(data) do
    meta = data[:meta] || data["meta"] || %{}

    %{
      page_name: meta[:page_name] || meta["page_name"] || "page",
      current_page: meta[:current_page] || meta["current_page"],
      previous_page: meta[:previous_page] || meta["previous_page"],
      next_page: meta[:next_page] || meta["next_page"]
    }
  end
end
