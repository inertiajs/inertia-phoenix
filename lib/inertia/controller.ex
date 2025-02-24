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

  @type raw_prop_key :: atom() | String.t()

  @opaque optional() :: {:optional, fun()}
  @opaque always() :: {:keep, any()}
  @opaque merge() :: {:merge, any()}
  @opaque defer() :: {:defer, {fun(), String.t()}}
  @opaque preserved_prop_key :: {:preserve, raw_prop_key()}

  @type render_opt() :: {:ssr, boolean()}
  @type render_opts() :: [render_opt()]

  @type prop_key() :: raw_prop_key() | preserved_prop_key()

  @doc """
  Marks a prop value as optional, which means it will only get evaluated if
  explicitly requested in a partial reload.

  Optional props will _only_ be included the when explicitly requested in a
  partial reload. If you want to include the prop on first visit, you'll want to
  use a bare anonymous function or named function reference instead.

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
      |> assign_prop(:super_expensive_thing, inertia_optional(fn -> calculate_thing() end))
  """
  @doc since: "1.0.0"
  @spec inertia_optional(fun :: fun()) :: optional()
  def inertia_optional(fun) when is_function(fun), do: {:optional, fun}

  @doc since: "1.0.0"
  def inertia_optional(_) do
    raise ArgumentError, message: "inertia_optional/1 only accepts a function argument"
  end

  @doc false
  @spec inertia_lazy(fun :: fun()) :: optional()
  @deprecated "Use inertia_optional/1 instead"
  def inertia_lazy(fun), do: inertia_optional(fun)

  @doc """
  Marks that a prop should be merged with existing data on the client-side.
  """
  @doc since: "1.0.0"
  @spec inertia_merge(value :: any()) :: merge()
  def inertia_merge(value), do: {:merge, value}

  @doc """
  Marks that a prop should fetched immediately after the page is loaded on the client-side.
  """
  @doc since: "1.0.0"
  @spec inertia_defer(fun :: fun()) :: defer()
  def inertia_defer(fun) when is_function(fun), do: {:defer, {fun, "default"}}

  def inertia_defer(_) do
    raise ArgumentError, message: "inertia_defer/1 only accepts a function argument"
  end

  @doc since: "1.0.0"
  @spec inertia_defer(fun :: fun(), group :: String.t()) :: defer()
  def inertia_defer(fun, group) when is_function(fun) and is_binary(group) do
    {:defer, {fun, group}}
  end

  def inertia_defer(_, _) do
    raise ArgumentError, message: "inertia_defer/2 only accepts function and group arguments"
  end

  @doc """
  Marks a prop value as "always included", which means it will be included in
  the props on initial page load and subsequent partial loads (even when it's
  not explicitly requested).
  """
  @spec inertia_always(value :: any()) :: always()
  def inertia_always(value), do: {:keep, value}

  @doc """
  Prevents auto-transformation of a prop key to camel-case (when
  `camelize_props` is enabled).

  ## Example

      conn
      |> assign_prop(preserve_case(:this_will_not_be_camelized), "value")
      |> assign_prop(:this_will_be_camelized, "another_value")
      |> camelize_props()
      |> render_inertia("Home")

  You can also use this helper inside of nested props:

      conn
      |> assign_prop(:user, %{
        preserve_case(:this_will_not_be_camelized) => "value",
        this_will_be_camelized: "another_value"
      })
      |> camelize_props()
      |> render_inertia("Home")
  """
  @doc since: "2.2.0"
  @spec preserve_case(raw_prop_key()) :: preserved_prop_key()
  def preserve_case(key), do: {:preserve, key}

  @doc """
  Assigns a prop value to the Inertia page data.
  """
  @spec assign_prop(Plug.Conn.t(), prop_key(), any()) :: Plug.Conn.t()
  def assign_prop(conn, key, value) do
    shared = conn.private[:inertia_shared] || %{}
    put_private(conn, :inertia_shared, Map.put(shared, key, value))
  end

  @doc """
  Instuct the client-side to encrypt history for this page.
  """
  @doc since: "1.0.0"
  @spec encrypt_history(Plug.Conn.t()) :: Plug.Conn.t()
  def encrypt_history(conn) do
    put_private(conn, :inertia_encrypt_history, true)
  end

  @doc since: "1.0.0"
  @spec encrypt_history(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def encrypt_history(conn, true_or_false) when is_boolean(true_or_false) do
    put_private(conn, :inertia_encrypt_history, true_or_false)
  end

  @doc """
  Instuct the client-side to clear the history.
  """
  @doc since: "1.0.0"
  @spec clear_history(Plug.Conn.t()) :: Plug.Conn.t()
  def clear_history(conn) do
    put_private(conn, :inertia_clear_history, true)
  end

  @doc since: "1.0.0"
  @spec clear_history(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def clear_history(conn, true_or_false) when is_boolean(true_or_false) do
    put_private(conn, :inertia_clear_history, true_or_false)
  end

  @doc """
  Enable (or disable) automatic conversion of prop keys from snake case (e.g.
  `inserted_at`), which is conventional in Elixir, to camel case (e.g.
  `insertedAt`), which is conventional in JavaScript.

  ## Examples

  Using `camelize_props` here will convert `first_name` to `firstName` in the
  response props.

      conn
      |> assign_prop(:first_name, "Bob")
      |> camelize_props()
      |> render_inertia("Home")

  You may also pass a boolean to the `camelize_props` function (to override any
  previously-set or globally-configured value):

      conn
      |> assign_prop(:first_name, "Bob")
      |> camelize_props(false)
      |> render_inertia("Home")
  """
  @doc since: "1.0.0"
  @spec camelize_props(Plug.Conn.t()) :: Plug.Conn.t()
  def camelize_props(conn) do
    put_private(conn, :inertia_camelize_props, true)
  end

  @doc since: "1.0.0"
  @spec camelize_props(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def camelize_props(conn, true_or_false) when is_boolean(true_or_false) do
    put_private(conn, :inertia_camelize_props, true_or_false)
  end

  @doc """
  Assigns errors to the Inertia page data. This helper accepts any data that
  implements the `Inertia.Errors` protocol. By default, this library implements
  error serializers for `Ecto.Changeset` and bare maps.

  If you are serializing your own errors maps, they should take the following shape:

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
  @spec assign_errors(Plug.Conn.t(), data :: term()) :: Plug.Conn.t()
  @spec assign_errors(Plug.Conn.t(), data :: term(), msg_func :: function()) ::
          Plug.Conn.t()
  def assign_errors(conn, data) do
    errors =
      data
      |> Errors.to_errors()
      |> bag_errors(conn)
      |> inertia_always()

    assign_prop(conn, :errors, errors)
  end

  def assign_errors(conn, data, msg_func) do
    errors =
      data
      |> Errors.to_errors(msg_func)
      |> bag_errors(conn)
      |> inertia_always()

    assign_prop(conn, :errors, errors)
  end

  defp bag_errors(errors, conn) do
    if error_bag = conn.private[:inertia_error_bag] do
      %{error_bag => errors}
    else
      errors
    end
  end

  @doc """
  Renders an Inertia response.

  ## Options

  - `ssr`: whether to server-side render the response (see the docs on
    "Server-side rendering" in the README for more information on setting this
    up). Defaults to the globally-configured value, or `false` if no global
    config is specified.

  ## Examples

      conn
      |> assign_prop(:user_id, 1)
      |> render_inertia("SettingsPage")

  You may pass additional props as map for the third argument:

      conn
      |> assign_prop(:user_id, 1)
      |> render_inertia("SettingsPage", %{name: "Bob"})

  You may also pass options for the last positional argument:

      conn
      |> assign_prop(:user_id, 1)
      |> render_inertia("SettingsPage", ssr: true)

      conn
      |> assign_prop(:user_id, 1)
      |> render_inertia("SettingsPage", %{name: "Bob"}, ssr: true)
  """
  @spec render_inertia(Plug.Conn.t(), component :: String.t()) :: Plug.Conn.t()
  @spec render_inertia(
          Plug.Conn.t(),
          component :: String.t(),
          inline_props_or_opts :: map() | render_opts()
        ) :: Plug.Conn.t()
  @spec render_inertia(
          Plug.Conn.t(),
          component :: String.t(),
          props :: map(),
          opts :: render_opts()
        ) :: Plug.Conn.t()
  def render_inertia(%Plug.Conn{} = conn, component) do
    build_inertia_response(conn, component, %{}, [])
  end

  def render_inertia(%Plug.Conn{} = conn, component, inline_props) when is_map(inline_props) do
    build_inertia_response(conn, component, inline_props, [])
  end

  def render_inertia(%Plug.Conn{} = conn, component, opts) when is_list(opts) do
    build_inertia_response(conn, component, %{}, opts)
  end

  def render_inertia(%Plug.Conn{} = conn, component, inline_props, opts)
      when is_map(inline_props) and is_list(opts) do
    build_inertia_response(conn, component, inline_props, opts)
  end

  defp build_inertia_response(conn, component, inline_props, opts) do
    shared_props = conn.private[:inertia_shared] || %{}

    # Only render partial props if the partial component matches the current page
    is_partial = conn.private[:inertia_partial_component] == component
    only = if is_partial, do: conn.private[:inertia_partial_only], else: []
    except = if is_partial, do: conn.private[:inertia_partial_except], else: []
    camelize_props = conn.private[:inertia_camelize_props] || false
    reset = conn.private[:inertia_reset] || []

    opts = Keyword.merge(opts, camelize_props: camelize_props, reset: reset)

    props = Map.merge(shared_props, inline_props)
    {props, merge_props} = resolve_merge_props(props, opts)
    {props, deferred_props} = resolve_deferred_props(props)

    props =
      props
      |> apply_filters(only, except, opts)
      |> resolve_props(opts)
      |> maybe_put_flash(conn)

    conn
    |> put_private(:inertia_page, %{
      component: component,
      props: props,
      merge_props: merge_props,
      deferred_props: deferred_props,
      is_partial: is_partial
    })
    |> detect_ssr(opts)
    |> put_csrf_cookie()
    |> send_response()
  end

  @doc """
  Determines if a response has been rendered with Inertia.
  """
  @spec inertia_response?(Plug.Conn.t()) :: boolean()
  def inertia_response?(%Plug.Conn{private: %{inertia_page: _}} = _conn), do: true
  def inertia_response?(_), do: false

  # Private helpers

  # Runs a reduce operation over the top-level props and looks for values that
  # were tagged via the `inertia_merge/1` helper. If the value is tagged, then
  # place the key in an array (unless that key is included in the list of
  # "reset" keys). Otherwise, make no modification.
  defp resolve_merge_props(props, opts) do
    Enum.reduce(props, {[], []}, fn {key, value}, {props, keys} ->
      transformed_key =
        key
        |> transform_key(opts)
        |> to_string()

      case value do
        {:merge, unwrapped_value} ->
          # Only include this key in the collection of merge prop keys
          # if it's not in the "reset" list
          merge_prop_keys =
            if transformed_key in opts[:reset] do
              keys
            else
              [key | keys]
            end

          {[{key, unwrapped_value} | props], merge_prop_keys}

        _ ->
          {[{key, value} | props], keys}
      end
    end)
  end

  defp resolve_deferred_props(props) do
    Enum.reduce(props, {[], %{}}, fn {key, value}, {props, keys} ->
      case value do
        {:defer, {fun, group}} ->
          keys =
            case Map.get(keys, group) do
              [_ | _] = group_keys -> Map.put(keys, group, [key | group_keys])
              _ -> Map.put(keys, group, [key])
            end

          {[{key, {:optional, fun}} | props], keys}

        _ ->
          {[{key, value} | props], keys}
      end
    end)
  end

  defp apply_filters(props, only, _except, opts) when length(only) > 0 do
    props
    |> Enum.filter(fn {key, value} ->
      case value do
        {:keep, _} ->
          true

        _ ->
          transformed_key =
            key
            |> transform_key(opts)
            |> to_string()

          Enum.member?(only, transformed_key)
      end
    end)
    |> Map.new()
  end

  defp apply_filters(props, _only, except, opts) when length(except) > 0 do
    props
    |> Enum.filter(fn {key, value} ->
      case value do
        {:keep, _} ->
          true

        _ ->
          transformed_key =
            key
            |> transform_key(opts)
            |> to_string()

          !Enum.member?(except, transformed_key)
      end
    end)
    |> Map.new()
  end

  defp apply_filters(props, _only, _except, _opts) do
    props
    |> Enum.filter(fn {_key, value} ->
      case value do
        {:optional, _} -> false
        _ -> true
      end
    end)
    |> Map.new()
  end

  defp resolve_props(map, opts) when is_map(map) and not is_struct(map) do
    map
    |> Enum.reduce([], fn {key, value}, acc ->
      [{transform_key(key, opts), resolve_props(value, opts)} | acc]
    end)
    |> Map.new()
  end

  defp resolve_props(list, opts) when is_list(list) do
    Enum.map(list, &resolve_props(&1, opts))
  end

  defp resolve_props({:optional, value}, opts), do: resolve_props(value, opts)
  defp resolve_props({:keep, value}, opts), do: resolve_props(value, opts)
  defp resolve_props({:merge, value}, opts), do: resolve_props(value, opts)
  defp resolve_props(fun, opts) when is_function(fun, 0), do: resolve_props(fun.(), opts)
  defp resolve_props(value, _opts), do: value

  # Applies any specified transformations to the key (such as conversion to
  # camel case), unless the key has been marked as "preserved".
  defp transform_key({:preserve, key}, _opts), do: key

  defp transform_key(key, opts) do
    if opts[:camelize_props] do
      key
      |> to_string()
      |> Phoenix.Naming.camelize(:lower)
      |> atomize_if(is_atom(key))
    else
      key
    end
  end

  defp atomize_if(value, true), do: String.to_atom(value)
  defp atomize_if(value, false), do: value

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
    if conn.private[:inertia_ssr] do
      case SSR.call(inertia_assigns(conn)) do
        {:ok, %{"head" => head, "body" => body}} ->
          send_ssr_response(conn, head, body)

        {:error, message} ->
          if raise_on_ssr_failure?() do
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
    |> render(:inertia_page, %{page: inertia_assigns(conn)})
  end

  defp inertia_assigns(conn) do
    %{
      component: conn.private.inertia_page.component,
      props: conn.private.inertia_page.props,
      url: request_path(conn),
      version: conn.private.inertia_version,
      encryptHistory: conn.private.inertia_encrypt_history,
      clearHistory: conn.private.inertia_clear_history
    }
    |> maybe_put_merge_props(conn)
    |> maybe_put_deferred_props(conn)
  end

  defp maybe_put_merge_props(assigns, conn) do
    merge_props = conn.private.inertia_page.merge_props

    if Enum.empty?(merge_props) do
      assigns
    else
      Map.put(assigns, :mergeProps, merge_props)
    end
  end

  defp maybe_put_deferred_props(assigns, conn) do
    is_partial = conn.private.inertia_page.is_partial
    deferred_props = conn.private.inertia_page.deferred_props

    if is_partial || Enum.empty?(deferred_props) do
      assigns
    else
      Map.put(assigns, :deferredProps, deferred_props)
    end
  end

  defp request_path(conn) do
    IO.iodata_to_binary([conn.request_path, request_url_qs(conn.query_string)])
  end

  defp request_url_qs(""), do: ""
  defp request_url_qs(qs), do: [??, qs]

  defp put_csrf_cookie(conn) do
    put_resp_cookie(conn, "XSRF-TOKEN", get_csrf_token(), http_only: false)
  end

  defp detect_ssr(conn, opts) do
    put_private(conn, :inertia_ssr, opts[:ssr] || ssr_enabled_globally?())
  end

  defp ssr_enabled_globally? do
    Application.get_env(:inertia, :ssr, false)
  end

  defp raise_on_ssr_failure? do
    Application.get_env(:inertia, :raise_on_ssr_failure, true)
  end
end
