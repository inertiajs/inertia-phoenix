defmodule Inertia.Controller do
  @moduledoc """
  Controller functions for rendering Inertia.js responses.
  """

  require Logger

  alias Inertia.Errors
  alias Inertia.SSR.RenderError
  alias Inertia.SSR

  import Phoenix.Controller
  import Plug.Conn

  @title_regex ~r/<title inertia>(.*?)<\/title>/

  @type lazy() :: {:lazy, fun()}
  @type always() :: {:keep, any()}

  @doc """
  Marks a prop value as lazy, which means it will only get evaluated if
  explicitly requested in a partial reload.

  Lazy props will _only_ be included the when explicitly requested in a partial
  reload. If you want to include the prop on first visit, you'll want to use a
  bare anonymous function or named function reference instead.

      conn
      # ALWAYS included on first visit...
      # OPTIONALLY included on partial reloads...
      # ALWAYS evaluated...
      |> assign_prop(:cheap_thing, cheap_thing())

      # ALWAYS included on first visit...
      # OPTIONALLY included on partial reloads...
      # ONLY evaluated when needed...
      |> assign_prop(:expensive_thing, fn -> calculate_thing() end)
      |> assign_prop(:another_expensive_thing, &calculate_another_thing/0)

      # NEVER included on first visit...
      # OPTIONALLY included on partial reloads...
      # ONLY evaluated when needed...
      |> assign_prop(:super_expensive_thing, inertia_lazy(fn -> calculate_thing() end))
  """
  @spec inertia_lazy(fun :: fun()) :: lazy()
  def inertia_lazy(fun) when is_function(fun), do: {:lazy, fun}

  def inertia_lazy(_) do
    raise ArgumentError, message: "inertia_lazy/1 only accepts a function argument"
  end

  @doc """
  Marks a prop value as "always included", which means it will be included in
  the props on initial page load and subsequent partial loads (even when it's
  not explicitly requested).
  """
  @spec inertia_always(value :: any()) :: always()
  def inertia_always(value), do: {:keep, value}

  @doc """
  Assigns a prop value to the Inertia page data.
  """
  @spec assign_prop(Plug.Conn.t(), atom(), any()) :: Plug.Conn.t()
  def assign_prop(conn, key, value) do
    shared = conn.private[:inertia_shared] || %{}
    put_private(conn, :inertia_shared, Map.put(shared, key, value))
  end

  @doc """
  Assigns errors to the Inertia page data. This helper accepts an
  `Ecto.Changeset` (and automatically serializes its errors into a shape
  compatible with Inertia), or a bare map of errors.

  If you are serializing your own errors, they should take the following shape:

      %{
        "name" => "Name is required",
        "password" => "Password must be at least 5 characters",
        "team.name" => "Team name is required",
      }

  When assigning a changeset, you may optionally pass a message-generating function
  to use when traversing errors. See [`Ecto.Changeset.traverse_errors/2`](https://hexdocs.pm/ecto/Ecto.Changeset.html#traverse_errors/2)
  for more information about the message function.

      defp default_msg_func({msg, opts}) do
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{\#{key}}", fn _ -> to_string(value) end)
        end)
      end

  This default implementation performs a simple string replacement for error
  message containing variables, like `count`. For example, given the following
  error:

      {"should be at least %{count} characters", [count: 3, validation: :length, min: 3]}

  The generated description would be "should be at least 3 characters". If you would
  prefer to use the `Gettext` module for pluralizing and localizing error messages, you
  can override the message function:

      conn
      |> assign_errors(changeset, fn {msg, opts} ->
        if count = opts[:count] do
          Gettext.dngettext(MyAppWeb.Gettext, "errors", msg, msg, count, opts)
        else
          Gettext.dgettext(MyAppWeb.Gettext, "errors", msg, opts)
        end
      end)
  """
  @spec assign_errors(Plug.Conn.t(), data :: Ecto.Changeset.t() | map()) :: Plug.Conn.t()
  @spec assign_errors(Plug.Conn.t(), data :: Ecto.Changeset.t(), msg_func :: function()) ::
          Plug.Conn.t()
  def assign_errors(conn, map_or_changeset) do
    assign_prop(conn, :errors, Errors.compile_errors!(conn, map_or_changeset))
  end

  def assign_errors(conn, %Ecto.Changeset{} = changeset, msg_func) do
    assign_prop(conn, :errors, Errors.compile_errors!(conn, changeset, msg_func))
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
      |> maybe_put_flash(conn)

    conn
    |> put_private(:inertia_page, %{component: component, props: props})
    |> send_response()
  end

  # Private helpers

  defp resolve_props(map, opts) when is_map(map) do
    values =
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

    if keep?(opts, values) do
      Map.new(values)
    else
      :skip
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

  defp keep?(opts, values) do
    case {opts[:keep], opts[:path], values} do
      {true, _, _} -> true
      {_, nil, _} -> true
      {_, _, [_ | _]} -> true
      {_, _, _} -> false
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

  # Skip putting flash in the props if there's already `:flash` key assigned.
  # Otherwise, put the flash in the props.
  defp maybe_put_flash(%{flash: _} = props, _conn), do: props
  defp maybe_put_flash(props, conn), do: Map.put(props, :flash, conn.assigns.flash)

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
