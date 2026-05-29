defmodule Inertia.PaginationTest do
  use ExUnit.Case, async: true

  describe "Inertia.Paginated for Scrivener.Page" do
    test "returns entries and page-based metadata" do
      page = %Scrivener.Page{
        entries: [%{id: 1}, %{id: 2}],
        page_number: 2,
        page_size: 2,
        total_entries: 6,
        total_pages: 3
      }

      assert %{
               entries: [%{id: 1}, %{id: 2}],
               current_page: 2,
               previous_page: 1,
               next_page: 3
             } = Inertia.Paginated.to_scroll(page)
    end

    test "previous_page is nil on the first page" do
      page = %Scrivener.Page{entries: [], page_number: 1, total_pages: 3}
      assert %{previous_page: nil, next_page: 2} = Inertia.Paginated.to_scroll(page)
    end

    test "next_page is nil on the last page" do
      page = %Scrivener.Page{entries: [], page_number: 3, total_pages: 3}
      assert %{previous_page: 2, next_page: nil} = Inertia.Paginated.to_scroll(page)
    end

    test "handles nil page fields without raising" do
      page = %Scrivener.Page{entries: [%{id: 1}]}

      assert %{entries: [%{id: 1}], current_page: nil, previous_page: nil, next_page: nil} =
               Inertia.Paginated.to_scroll(page)
    end
  end

  describe "Inertia.Paginated for Flop.Meta" do
    test "returns page-based metadata without entries" do
      meta = %Flop.Meta{current_page: 2, previous_page: 1, next_page: 3}

      result = Inertia.Paginated.to_scroll(meta)

      # page_name is omitted here and defaults to "page" downstream.
      assert result == %{current_page: 2, previous_page: 1, next_page: 3}
      refute Map.has_key?(result, :entries)
    end

    test "carries nil page boundaries through" do
      meta = %Flop.Meta{current_page: 1, previous_page: nil, next_page: 2}
      assert %{previous_page: nil, next_page: 2} = Inertia.Paginated.to_scroll(meta)
    end

    test "raises for cursor-based pagination (current_page is nil)" do
      meta = %Flop.Meta{current_page: nil, start_cursor: "abc", end_cursor: "xyz"}

      assert_raise ArgumentError, ~r/cursor-based Flop pagination is not supported/, fn ->
        Inertia.Paginated.to_scroll(meta)
      end
    end

    test "raises for an empty cursor-based result (current_page and cursors nil)" do
      meta = %Flop.Meta{current_page: nil, start_cursor: nil, end_cursor: nil}

      assert_raise ArgumentError, ~r/cursor-based Flop pagination is not supported/, fn ->
        Inertia.Paginated.to_scroll(meta)
      end
    end
  end
end
