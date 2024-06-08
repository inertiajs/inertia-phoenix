defmodule Inertia.Controller do
  @moduledoc """
  Controller functions for rendering Inertia.js responses.
  """

  require Logger

  alias Inertia.SSR.RenderError
  alias Inertia.SSR

  import Phoenix.Controller
  import Plug.Conn

  @title_regex ~r/<title inertia>(.*?)<\/title>/

  @type lazy() :: {:lazy, fun()}

  @doc """
  Marks a prop value as lazy, which means it will only get evaluated if
  explicitly requested in a partial reload.
  """
  @spec inertia_lazy(fun :: fun()) :: lazy()
  def inertia_lazy(fun) when is_function(fun), do: {:lazy, fun}

  def inertia_lazy(_) do
    raise ArgumentError, message: "inertia_lazy/1 only accepts a function argument"
  end

  @doc """
  Assigns a prop value to the Inertia page data.
  """
  @spec assign_prop(Plug.Conn.t(), atom(), any()) :: Plug.Conn.t()
  def assign_prop(conn, key, value) do
    shared = conn.private[:inertia_shared] || %{}
    put_private(conn, :inertia_shared, Map.put(shared, key, value))
  end

  @doc """
  Renders an Inertia response.
  """
  @spec render_inertia(Plug.Conn.t(), component :: String.t()) :: Plug.Conn.t()
  @spec render_inertia(Plug.Conn.t(), component :: String.t(), props :: map()) :: Plug.Conn.t()

  def render_inertia(conn, component, props \\ %{}) do
    shared = conn.private[:inertia_shared] || %{}

    # Only render partial props if the partial component matches the current page
    is_partial = conn.private[:inertia_partial_component] == component
    only = if is_partial, do: conn.private[:inertia_partial_only], else: []
    except = if is_partial, do: conn.private[:inertia_partial_except], else: []

    props =
      shared
      |> Map.merge(props)
      |> resolve_props(only: only, except: except)

    conn
    |> put_private(:inertia_page, %{component: component, props: props})
    |> send_response()
  end

  # Private helpers

  defp resolve_props(map, opts) when is_map(map) do
    key_values =
      map
      |> Map.to_list()
      |> Enum.reduce([], fn {key, value}, acc ->
        path = if opts[:path], do: "#{opts[:path]}.#{key}", else: to_string(key)
        opts = Keyword.put(opts, :path, path)
        resolved_value = resolve_props(value, opts)

        if resolved_value == :skip do
          acc
        else
          [{key, resolved_value} | acc]
        end
      end)

    case {opts[:path], key_values} do
      {nil, key_values} -> Map.new(key_values)
      {_, [_ | _]} -> Map.new(key_values)
      {_, _} -> :skip
    end
  end

  defp resolve_props({:lazy, value}, opts) do
    if Enum.member?(opts[:only], opts[:path]) do
      resolve_props(value, opts)
    else
      :skip
    end
  end

  defp resolve_props({:keep, value}, opts) do
    opts = Keyword.put(opts, :keep, true)
    resolve_props(value, opts)
  end

  defp resolve_props(fun, opts) when is_function(fun, 0) do
    if skip?(opts) do
      :skip
    else
      fun.()
    end
  end

  defp resolve_props(value, opts) do
    if skip?(opts) do
      :skip
    else
      value
    end
  end

  defp skip?(opts) do
    path = opts[:path]
    only = opts[:only]
    except = opts[:except]
    keep = opts[:keep]

    cond do
      keep -> false
      length(only) > 0 && !Enum.member?(only, path) -> true
      length(except) > 0 && Enum.member?(except, path) -> true
      true -> false
    end
  end

  defp send_response(%{private: %{inertia_request: true}} = conn) do
    conn
    |> put_status(200)
    |> put_resp_header("x-inertia", "true")
    |> put_resp_header("vary", "X-Inertia")
    |> json(inertia_assigns(conn))
  end

  defp send_response(conn) do
    if ssr_enabled?() do
      case SSR.call(inertia_assigns(conn)) do
        {:ok, %{"head" => head, "body" => body}} ->
          send_ssr_response(conn, head, body)

        {:error, message} ->
          if raise_on_ssr_failure() do
            raise RenderError, message: message
          else
            Logger.error("SSR failed, falling back to CSR\n\n#{message}")
            send_csr_response(conn)
          end
      end
    else
      send_csr_response(conn)
    end
  end

  defp compile_head(%{assigns: %{inertia_head: current_head}} = conn, incoming_head) do
    {titles, other_tags} = Enum.split_with(current_head ++ incoming_head, &(&1 =~ @title_regex))

    conn
    |> assign(:inertia_head, other_tags)
    |> update_page_title(Enum.reverse(titles))
  end

  defp update_page_title(conn, [title_tag | _]) do
    [_, page_title] = Regex.run(@title_regex, title_tag)
    assign(conn, :page_title, page_title)
  end

  defp update_page_title(conn, _), do: conn

  defp send_ssr_response(conn, head, body) do
    conn
    |> put_view(Inertia.HTML)
    |> compile_head(head)
    |> assign(:body, body)
    |> render(:inertia_ssr)
  end

  defp send_csr_response(conn) do
    conn
    |> put_view(Inertia.HTML)
    |> render(:inertia_page, inertia_assigns(conn))
  end

  defp inertia_assigns(conn) do
    %{
      component: conn.private.inertia_page.component,
      props: conn.private.inertia_page.props,
      url: request_path(conn),
      version: conn.private.inertia_version
    }
  end

  defp request_path(conn) do
    IO.iodata_to_binary([conn.request_path, request_url_qs(conn.query_string)])
  end

  defp request_url_qs(""), do: ""
  defp request_url_qs(qs), do: [??, qs]

  defp ssr_enabled? do
    Application.get_env(:inertia, :ssr, false)
  end

  defp raise_on_ssr_failure do
    Application.get_env(:inertia, :raise_on_ssr_failure, true)
  end
end
