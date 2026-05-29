if match?({:module, _}, Code.ensure_compiled(Scrivener.Page)) do
  defimpl Inertia.Paginated, for: Scrivener.Page do
    @moduledoc """
    First-party `Inertia.Paginated` implementation for `Scrivener.Page`.

    The page struct carries both its entries and page metadata, so it can be
    passed directly to `inertia_scroll/2`:

        conn
        |> assign_prop(:users, inertia_scroll(MyApp.Repo.paginate(query)))
        |> render_inertia("Users/Index")
    """
    def to_scroll(%Scrivener.Page{} = page) do
      %{entries: entries, page_number: page_number, total_pages: total_pages} = page

      %{
        entries: entries,
        current_page: page_number,
        previous_page: previous_page(page_number),
        next_page: next_page(page_number, total_pages)
      }
    end

    # Scrivener.Page types page_number/total_pages as integers, but the struct
    # defaults them to nil. Guard with is_integer/2 rather than comparing against
    # a possibly-nil value (nil > 1 is true in Elixir term ordering, so nil - 1
    # would raise).
    defp previous_page(page) when is_integer(page) and page > 1, do: page - 1
    defp previous_page(_page), do: nil

    defp next_page(page, total) when is_integer(page) and is_integer(total) and page < total do
      page + 1
    end

    defp next_page(_page, _total), do: nil
  end
end
