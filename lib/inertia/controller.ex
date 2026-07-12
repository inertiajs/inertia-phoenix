defmodule Inertia.Controller do
  @moduledoc """
  Controller functions for rendering Inertia.js responses.
  """
  require Logger

  alias Inertia.Errors
  alias Inertia.SSR
  alias Inertia.SSR.RenderError

  import Phoenix.Controller
  import Plug.Conn

  # Matches the <title> tag emitted by the client-side adapters during SSR.
  # The attribute may be bare (`data-inertia`) or carry a value
  # (`data-inertia=""` or a head-key, e.g. `data-inertia="title"`).
  @title_regex ~r/<title data-inertia(?:="[^"]*")?>(.*?)<\/title>/

  # The HTML entities that the client-side adapters escape when rendering
  # the <title> contents during SSR.
  @title_entities %{
    "&amp;" => "&",
    "&lt;" => "<",
    "&gt;" => ">",
    "&quot;" => "\"",
    "&#39;" => "'",
    "&#x27;" => "'"
  }

  @title_entity_regex ~r/&(?:amp|lt|gt|quot|#39|#x27);/

  defmodule Once do
    @moduledoc false
    @type t :: %__MODULE__{
            fun: fun() | tuple(),
            key: String.t() | nil,
            expires_at: integer() | nil,
            fresh: boolean()
          }
    defstruct [:fun, :key, :expires_at, :fresh]
  end

  defmodule Scroll do
    @moduledoc false
    @type t :: %__MODULE__{
            fun: fun() | any(),
            wrapper: String.t(),
            scroll_metadata: (any() -> map()) | nil,
            meta: (any() -> map()) | nil,
            page_name: String.t() | nil,
            transform: (any() -> any()) | nil
          }
    defstruct [:fun, :transform, :page_name, :meta, wrapper: "data", scroll_metadata: nil]
  end

  defmodule PropsMeta do
    @moduledoc false
    defstruct merge_props: [],
              prepend_props: [],
              deep_merge_props: [],
              match_props_on: [],
              deferred_props: %{},
              once_props: %{},
              scroll_props: %{},
              rescued_props: []
  end

  defmodule ResolveContext do
    @moduledoc false
    defstruct [:is_partial, :only, :except, :reset, :except_once_props, :opts]
  end

  @type raw_prop_key :: atom() | String.t()

  @opaque optional() :: {:optional, fun()}
  @opaque always() :: {:keep, any()}
  @opaque merge() :: {:merge, any()} | {:merge, any(), String.t()}
  @opaque prepend() :: {:prepend, any()} | {:prepend, any(), String.t()}
  @opaque deep_merge() :: {:deep_merge, any()} | {:deep_merge, any(), String.t()}
  @opaque defer() :: {:defer, {fun(), String.t()}} | {:defer, {fun(), String.t(), atom()}}
  @opaque once() :: Once.t()
  @opaque scroll() :: Scroll.t()
  @opaque shared() :: {:shared, any()}
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

  @doc """
  Marks that a prop should be merged with existing data on the client-side.

  ## Options

  - `:match_on` - A key (or list of keys) used for client-side deduplication of
    merged items. Each key may be a dot-path into the merged items (e.g. `"data.id"`).
  """
  @doc since: "1.0.0"
  @spec inertia_merge(value :: any()) :: merge()
  @spec inertia_merge(value :: any(), opts :: keyword()) :: merge()
  def inertia_merge(value, opts \\ []) do
    case Keyword.get(opts, :match_on) do
      nil -> {:merge, value}
      key -> {:merge, value, key}
    end
  end

  @doc """
  Marks that a prop should be prepended (instead of appended) when merging
  with existing data on the client-side.

  ## Options

  - `:match_on` - A key (or list of keys) used for client-side deduplication of
    merged items. Each key may be a dot-path into the merged items (e.g. `"data.id"`).
  """
  @doc since: "3.0.0"
  @spec inertia_prepend(value :: any()) :: prepend()
  @spec inertia_prepend(value :: any(), opts :: keyword()) :: prepend()
  def inertia_prepend(value, opts \\ []) do
    case Keyword.get(opts, :match_on) do
      nil -> {:prepend, value}
      key -> {:prepend, value, key}
    end
  end

  @doc """
  Marks that a prop should be deeply merged with existing data on the client-side.

  ## Options

  - `:match_on` - A key (or list of keys) used for client-side deduplication of
    merged items. Each key may be a dot-path into the merged items (e.g. `"data.id"`).
  """
  @doc since: "2.5.0"
  @spec inertia_deep_merge(value :: any()) :: deep_merge()
  @spec inertia_deep_merge(value :: any(), opts :: keyword()) :: deep_merge()
  def inertia_deep_merge(value, opts \\ []) do
    case Keyword.get(opts, :match_on) do
      nil -> {:deep_merge, value}
      key -> {:deep_merge, value, key}
    end
  end

  @doc """
  Marks that a prop should fetched immediately after the page is loaded on the client-side.

  ## Options

  - `:on_error` - Controls what happens when the prop's resolver fails while the
    client is fetching its deferred group. Defaults to letting the error
    propagate (failing the partial reload). Pass `:ignore` to degrade
    gracefully: the error is contained, the prop is omitted from the response,
    and its path is reported in the `rescuedProps` page metadata so the client
    can render a fallback. Rescued failures emit a
    `[:inertia, :deferred_prop, :rescue]` telemetry event and are logged.

  ## Examples

      # Default group
      assign_prop(conn, :stats, inertia_defer(fn -> expensive_stats() end))

      # Custom group
      assign_prop(conn, :stats, inertia_defer(fn -> expensive_stats() end, "dashboard"))

      # Degrade gracefully if the resolver fails
      assign_prop(conn, :stats, inertia_defer(fn -> expensive_stats() end, on_error: :ignore))

      # Custom group + graceful failure
      assign_prop(conn, :stats, inertia_defer(fn -> expensive_stats() end, "dashboard", on_error: :ignore))
  """
  @doc since: "1.0.0"
  @spec inertia_defer(fun :: fun()) :: defer()
  def inertia_defer(fun) when is_function(fun), do: {:defer, {fun, "default"}}

  def inertia_defer(_) do
    raise ArgumentError, message: "inertia_defer/1 only accepts a function argument"
  end

  @doc since: "1.0.0"
  @spec inertia_defer(fun :: fun(), group :: String.t()) :: defer()
  @spec inertia_defer(fun :: fun(), opts :: keyword()) :: defer()
  def inertia_defer(fun, group) when is_function(fun) and is_binary(group) do
    {:defer, {fun, group}}
  end

  def inertia_defer(fun, opts) when is_function(fun) and is_list(opts) do
    build_defer(fun, "default", opts)
  end

  def inertia_defer(_, _) do
    raise ArgumentError,
      message: "inertia_defer/2 only accepts function and group (or options) arguments"
  end

  @doc since: "3.0.0"
  @spec inertia_defer(fun :: fun(), group :: String.t(), opts :: keyword()) :: defer()
  def inertia_defer(fun, group, opts)
      when is_function(fun) and is_binary(group) and is_list(opts) do
    build_defer(fun, group, opts)
  end

  def inertia_defer(_, _, _) do
    raise ArgumentError,
      message: "inertia_defer/3 only accepts function, group, and options arguments"
  end

  defp build_defer(fun, group, opts) do
    case Keyword.validate(opts, [:on_error]) do
      {:ok, opts} ->
        apply_defer_opts(fun, group, opts)

      {:error, invalid} ->
        raise ArgumentError,
          message: "inertia_defer received invalid options: #{inspect(invalid)}"
    end
  end

  defp apply_defer_opts(fun, group, opts) do
    case Keyword.get(opts, :on_error) do
      nil ->
        {:defer, {fun, group}}

      :ignore ->
        {:defer, {fun, group, :ignore}}

      other ->
        raise ArgumentError,
          message: "inertia_defer :on_error only accepts :ignore, got: #{inspect(other)}"
    end
  end

  @doc """
  Marks a prop value as "always included", which means it will be included in
  the props on initial page load and subsequent partial loads (even when it's
  not explicitly requested).
  """
  @spec inertia_always(value :: any()) :: always()
  def inertia_always(value), do: {:keep, value}

  @doc """
  Marks a prop value as shared, causing its key to appear in the `sharedProps` page metadata.

  This tells the frontend which props are "shared" (set globally in plugs/middleware)
  so it can carry them forward optimistically during instant visits.
  """
  @doc since: "3.0.0"
  @spec inertia_share(value :: any()) :: shared()
  def inertia_share(value), do: {:shared, value}

  @doc """
  Marks a prop as a "once" prop, which is cached on the client-side and
  reused on subsequent pages that include the same prop.

  ## Options

  - `:fresh` - When `true`, forces the prop to be refreshed ignoring the client cache.
    Also accepts a boolean condition. Defaults to `false`.
  - `:until` - Sets an expiration time. Accepts a `DateTime` or integer seconds from now.
  - `:as` - Custom key for sharing data across pages with different prop names.

  ## Examples

      # Basic once prop
      assign_prop(conn, :plans, inertia_once(fn -> Plan.all() end))

      # Force refresh
      assign_prop(conn, :plans, inertia_once(fn -> Plan.all() end, fresh: true))

      # With expiration (1 hour)
      assign_prop(conn, :rates, inertia_once(fn -> ExchangeRate.all() end, until: 3600))

      # With custom key for sharing across pages
      assign_prop(conn, :member_roles, inertia_once(fn -> Role.all() end, as: "roles"))

      # Combined options
      assign_prop(conn, :plans, inertia_once(fn -> Plan.all() end,
        fresh: should_refresh?,
        until: DateTime.utc_now() |> DateTime.add(1, :day),
        as: "billing_plans"
      ))

      # Combining with other prop types
      assign_prop(conn, :permissions, inertia_once(inertia_defer(fn -> Permission.all() end)))
  """
  @doc since: "2.6.0"
  @spec inertia_once(
          fun_or_tagged :: fun() | defer() | merge() | prepend() | deep_merge() | optional()
        ) :: once()
  @spec inertia_once(
          fun_or_tagged :: fun() | defer() | merge() | prepend() | deep_merge() | optional(),
          opts :: keyword()
        ) :: once()
  def inertia_once(fun, opts \\ [])

  def inertia_once(fun, opts) when is_function(fun) do
    %Once{
      fun: fun,
      key: Keyword.get(opts, :as),
      expires_at: parse_expiration(Keyword.get(opts, :until)),
      fresh: Keyword.get(opts, :fresh, false)
    }
  end

  def inertia_once({tag, _} = tagged, opts)
      when tag in [:defer, :optional, :merge, :prepend, :deep_merge] do
    %Once{
      fun: tagged,
      key: Keyword.get(opts, :as),
      expires_at: parse_expiration(Keyword.get(opts, :until)),
      fresh: Keyword.get(opts, :fresh, false)
    }
  end

  def inertia_once({tag, _, _} = tagged, opts)
      when tag in [:merge, :prepend, :deep_merge] do
    %Once{
      fun: tagged,
      key: Keyword.get(opts, :as),
      expires_at: parse_expiration(Keyword.get(opts, :until)),
      fresh: Keyword.get(opts, :fresh, false)
    }
  end

  defp parse_expiration(nil), do: nil
  defp parse_expiration(%DateTime{} = dt), do: DateTime.to_unix(dt, :millisecond)

  defp parse_expiration(seconds) when is_integer(seconds) do
    DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.to_unix(:millisecond)
  end

  @doc """
  Marks a prop for infinite scroll pagination. Automatically configures
  merge behavior for the data key and extracts pagination metadata.

  Accepts several shapes of paginated data:

  - A struct implementing the `Inertia.Paginated` protocol (e.g. `Scrivener.Page`)
  - A `{entries, meta}` tuple where `meta` implements `Inertia.Paginated`
    (e.g. Flop's `{records, %Flop.Meta{}}`)
  - A map shaped like `%{data: [...], meta: %{...}}` (where the entries live under
    the `:wrapper` key)

  In every case the entries are placed under the `:wrapper` key (default `"data"`)
  so the resulting prop is uniformly shaped (e.g. `%{"data" => [...]}`) regardless
  of the pagination library. Pagination metadata is emitted separately in
  `scrollProps`, so it is not echoed in the prop value.

  ## Options

  - `:wrapper` - The key the data items are placed under (default: "data")
  - `:page_name` - Override the page query parameter name
  - `:scroll_metadata` - Custom metadata extraction function for `scrollProps` (the
    pagination state the client `<InfiniteScroll>` component uses; receives the
    original value). A per-call override of the `Inertia.Paginated` protocol.
  - `:transform` - A 1-arity function applied to each entry before serialization,
    for shaping entries into a prop-friendly form
  - `:meta` - A 1-arity function (receiving the original value) whose returned map
    is placed under a `"meta"` key in the prop, alongside the entries — for
    surfacing additional pagination data (totals, etc.) to the page. This is
    distinct from `:scroll_metadata`/`scrollProps`, which drives the scroll component.

  ## Examples

      # Basic usage with auto-detected metadata
      assign_prop(conn, :users, inertia_scroll(paginated_users))

      # Scrivener (via the Inertia.Paginated protocol)
      assign_prop(conn, :users, inertia_scroll(MyApp.Repo.paginate(query)))

      # Flop ({records, meta} tuple)
      assign_prop(conn, :users, inertia_scroll(Flop.run(query, params)))

      # With lazy evaluation
      assign_prop(conn, :users, inertia_scroll(fn -> User.paginate(params) end))

      # Custom wrapper key
      assign_prop(conn, :users, inertia_scroll(data, wrapper: "items"))

      # Serialize each entry
      assign_prop(conn, :users,
        inertia_scroll(Flop.run(query, params), transform: &serialize_user/1))

      # Custom scroll metadata (overrides the Inertia.Paginated protocol)
      assign_prop(conn, :users, inertia_scroll(data, scroll_metadata: fn data ->
        %{page_name: "p", current_page: 1, next_page: 2, previous_page: nil}
      end))

      # Surface extra pagination data under a "meta" key in the prop
      assign_prop(conn, :users,
        inertia_scroll(Flop.run(query, params),
          meta: fn {_records, meta} -> %{total: meta.total_count} end
        ))
      # => %{users: %{data: [...], meta: %{total: 42}}}
  """
  @doc since: "2.6.0"
  @spec inertia_scroll(value :: any()) :: scroll()
  @spec inertia_scroll(value :: any(), opts :: keyword()) :: scroll()
  def inertia_scroll(value, opts \\ []) do
    # A 0-arity function value is resolved lazily at prop-resolution time; see
    # unwrap_scroll/5.
    %Scroll{
      fun: value,
      wrapper: Keyword.get(opts, :wrapper, "data"),
      scroll_metadata: Keyword.get(opts, :scroll_metadata),
      meta: Keyword.get(opts, :meta),
      page_name: Keyword.get(opts, :page_name),
      transform: Keyword.get(opts, :transform)
    }
  end

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
  Assigns a shared prop value to the Inertia page data.

  This is a convenience for `assign_prop(conn, key, inertia_share(value))`.
  Shared props have their keys included in the `sharedProps` page metadata,
  which tells the frontend to carry them forward during instant visits.
  """
  @doc since: "3.0.0"
  @spec assign_shared_prop(Plug.Conn.t(), prop_key(), any()) :: Plug.Conn.t()
  def assign_shared_prop(conn, key, value) do
    assign_prop(conn, key, inertia_share(value))
  end

  @doc """
  Instruct the client-side to encrypt history for this page.
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
  Instruct the client-side to clear the history.
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
  Instruct the client-side to preserve the URL fragment across this navigation.
  """
  @doc since: "3.0.0"
  @spec preserve_fragment(Plug.Conn.t()) :: Plug.Conn.t()
  def preserve_fragment(conn), do: put_private(conn, :inertia_preserve_fragment, true)

  @doc since: "3.0.0"
  @spec preserve_fragment(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def preserve_fragment(conn, val) when is_boolean(val),
    do: put_private(conn, :inertia_preserve_fragment, val)

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
      if map_size(errors) > 0 do
        %{error_bag => errors}
      else
        errors
      end
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
    except_once_props = conn.private[:inertia_except_once_props] || []

    scroll_merge_intent = conn.private[:inertia_scroll_merge_intent] || "append"

    opts =
      Keyword.merge(opts,
        camelize_props: camelize_props,
        reset: reset,
        scroll_merge_intent: scroll_merge_intent
      )

    props = Map.merge(shared_props, inline_props)

    # Unwrap {:shared, _} tags and collect shared prop keys
    {props, shared_prop_keys} = resolve_shared_props(props, opts)

    ctx = %ResolveContext{
      is_partial: is_partial,
      only: only,
      except: except,
      reset: reset,
      except_once_props: except_once_props,
      opts: opts
    }

    {resolved_props, meta} = resolve_props(props, ctx, %PropsMeta{}, "", false)

    {flash, resolved_props} = resolve_flash(resolved_props, conn)

    conn
    |> put_private(:inertia_page, %{
      component: component,
      props: resolved_props,
      flash: flash,
      merge_props: meta.merge_props,
      prepend_props: meta.prepend_props,
      deep_merge_props: meta.deep_merge_props,
      match_props_on: meta.match_props_on,
      deferred_props: meta.deferred_props,
      once_props: meta.once_props,
      scroll_props: meta.scroll_props,
      rescued_props: meta.rescued_props,
      shared_props: shared_prop_keys,
      is_partial: is_partial
    })
    |> detect_ssr(opts)
    |> put_csrf_cookie()
    |> send_response()
  end

  # Extract flash from props if explicitly assigned, otherwise use conn.assigns.flash
  defp resolve_flash(resolved_props, conn) do
    case Map.pop(resolved_props, :flash) do
      {nil, _} -> {conn.assigns.flash, resolved_props}
      {f, p} -> {f, p}
    end
  end

  @doc """
  Determines if a response has been rendered with Inertia.
  """
  @spec inertia_response?(Plug.Conn.t()) :: boolean()
  def inertia_response?(%Plug.Conn{private: %{inertia_page: _}} = _conn), do: true
  def inertia_response?(_), do: false

  @doc """
  Forces the Inertia.js client side to perform a redirect. This can be used as a
  plug or inline when building a response.

  This plug modifies the response to be a 409 Conflict response and include the
  destination URL in the `x-inertia-location` header, which will cause the
  Inertia client to perform a `window.location = url` visit.

  **Note**: we automatically convert regular external redirects (via the Phoenix
  `redirect` helper), but this function is useful if you need to force redirect
  to a non-external route that is not handled by Inertia.

  See https://inertiajs.com/redirects#external-redirects

  ## Examples

      conn
      |> force_inertia_redirect()
      |> redirect(to: "/non-inertia-powered-page")

  """
  @doc since: "2.3.0"
  @spec force_inertia_redirect(Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
  def force_inertia_redirect(conn, _opts \\ []) do
    put_private(conn, :inertia_force_redirect, true)
  end

  # Private helpers

  defp resolve_shared_props(props, opts) do
    Enum.reduce(props, {[], []}, fn {key, value}, {props_acc, shared_acc} ->
      case value do
        {:shared, inner} ->
          transformed_key = key |> transform_key(opts) |> to_string()
          {[{key, inner} | props_acc], [transformed_key | shared_acc]}

        _ ->
          {[{key, value} | props_acc], shared_acc}
      end
    end)
  end

  # Path-matching helpers for nested partial filtering

  # Returns true if `path` equals or is a descendant of any only-path
  defp matches_only?(path, only_paths) do
    Enum.any?(only_paths, fn op ->
      path == op or String.starts_with?(path, op <> ".")
    end)
  end

  # Returns true if `path` is an ancestor of any only-path (allows traversal into children)
  defp leads_to_only?(path, only_paths) do
    Enum.any?(only_paths, fn op ->
      String.starts_with?(op, path <> ".")
    end)
  end

  # Returns true if `path` equals or is a descendant of any except-path
  defp matches_except?(path, except_paths) do
    Enum.any?(except_paths, fn ep ->
      path == ep or String.starts_with?(path, ep <> ".")
    end)
  end

  defp should_include_in_partial?(value, path, parent_was_resolved, ctx) do
    # Always-props bypass all filtering
    case value do
      {:keep, _} ->
        true

      _ ->
        cond do
          # Except filter — explicit exclusions always apply, even inside resolved closures
          ctx.except != [] -> !matches_except?(path, ctx.except)
          # If parent was a resolved closure, include all children
          parent_was_resolved -> true
          # Only filter
          ctx.only != [] -> matches_only?(path, ctx.only) or leads_to_only?(path, ctx.only)
          # No filter (initial load) — include everything
          true -> true
        end
    end
  end

  # Single recursive resolver that handles all prop types at any nesting level.
  # Returns {resolved_map, updated_meta}.
  defp resolve_props(props, ctx, meta, prefix, parent_was_resolved) do
    opts = ctx.opts

    Enum.reduce(props, {%{}, meta}, fn {key, value}, {props_acc, meta_acc} ->
      transformed_key = key |> transform_key(opts) |> to_string()
      path = if prefix == "", do: transformed_key, else: "#{prefix}.#{transformed_key}"

      # Check partial filter
      if ctx.is_partial and
           not should_include_in_partial?(value, path, parent_was_resolved, ctx) do
        # Still need to collect once metadata even for skipped props
        meta_acc = collect_once_meta_if_skipped(value, path, ctx, meta_acc)
        {props_acc, meta_acc}
      else
        resolve_prop(
          key,
          value,
          path,
          transformed_key,
          props_acc,
          meta_acc,
          ctx,
          parent_was_resolved
        )
      end
    end)
  end

  # Collects once metadata for props that were filtered out by partial filtering
  defp collect_once_meta_if_skipped(%Once{} = once, path, _ctx, meta) do
    once_key = once.key || path
    %{meta | once_props: Map.put(meta.once_props, once_key, build_once_meta(once, path))}
  end

  defp collect_once_meta_if_skipped(fun, path, ctx, meta) when is_function(fun, 0) do
    collect_once_meta_if_skipped(fun.(), path, ctx, meta)
  end

  defp collect_once_meta_if_skipped(map, path, ctx, meta)
       when is_map(map) and not is_struct(map) do
    Enum.reduce(map, meta, fn {key, value}, meta_acc ->
      transformed_key = key |> transform_key(ctx.opts) |> to_string()
      child_path = if path == "", do: transformed_key, else: "#{path}.#{transformed_key}"
      collect_once_meta_if_skipped(value, child_path, ctx, meta_acc)
    end)
  end

  defp collect_once_meta_if_skipped(_, _, _, meta), do: meta

  defp resolve_prop(key, value, path, transformed_key, props_acc, meta, ctx, parent_was_resolved) do
    # Step 1: Unwrap %Once{} structs
    {value, meta, skip_once} = unwrap_once(value, path, ctx, meta)

    if skip_once do
      {props_acc, meta}
    else
      # Step 2: Unwrap %Scroll{} structs (eagerly evaluate)
      {value, meta} = unwrap_scroll(value, path, transformed_key, ctx, meta)

      # Step 3: Resolve functions
      {value, was_resolved} = resolve_value(value)

      # Step 4: Two-level unwrapping — if a function returned a prop type, detect and process
      {value, meta, was_resolved} =
        unwrap_second_level(value, path, transformed_key, ctx, meta, was_resolved)

      # Step 5: Collect metadata based on prop type tags
      {value, meta} = collect_metadata(value, path, ctx, meta)

      # Step 6: Initial-response exclusion for optional props
      if ctx.is_partial or not optional?(value) do
        finalize_and_put(
          key,
          value,
          path,
          props_acc,
          meta,
          ctx,
          parent_was_resolved,
          was_resolved
        )
      else
        {props_acc, meta}
      end
    end
  end

  # Resolves a rescuable deferred prop within a try/catch. If resolution of the
  # prop (including its nested values) fails, the prop is omitted, its path is
  # recorded in rescued_props, and the failure is reported via telemetry +
  # logging. A nested *rescuable* prop still handles its own failure first (via
  # its own clause here), so it is reported under its own path; only otherwise
  # unhandled failures bubble up to this ancestor.
  defp finalize_and_put(
         key,
         {:optional, fun, :rescue},
         path,
         props_acc,
         meta,
         ctx,
         parent_was_resolved,
         was_resolved
       ) do
    {value, resolved_meta} =
      finalize_prop({:optional, fun}, path, meta, ctx, parent_was_resolved, was_resolved)

    put_resolved(props_acc, key, value, resolved_meta, ctx)
  rescue
    exception ->
      report_rescued_prop(path, :error, exception, __STACKTRACE__)
      {props_acc, %{meta | rescued_props: [path | meta.rescued_props]}}
  catch
    kind, reason ->
      report_rescued_prop(path, kind, reason, __STACKTRACE__)
      {props_acc, %{meta | rescued_props: [path | meta.rescued_props]}}
  end

  defp finalize_and_put(
         key,
         value,
         path,
         props_acc,
         meta,
         ctx,
         parent_was_resolved,
         was_resolved
       ) do
    {value, meta} = finalize_prop(value, path, meta, ctx, parent_was_resolved, was_resolved)
    put_resolved(props_acc, key, value, meta, ctx)
  end

  defp put_resolved(props_acc, key, value, meta, ctx) do
    output_key = transform_key(key, ctx.opts)
    {Map.put(props_acc, output_key, value), meta}
  end

  defp report_rescued_prop(path, kind, reason, stacktrace) do
    :telemetry.execute(
      [:inertia, :deferred_prop, :rescue],
      %{},
      %{prop: path, kind: kind, reason: reason, stacktrace: stacktrace}
    )

    Logger.error(
      "Inertia rescued deferred prop #{inspect(path)}:\n" <>
        Exception.format(kind, reason, stacktrace)
    )
  end

  defp finalize_prop(value, path, meta, ctx, parent_was_resolved, was_resolved) do
    # Unwrap remaining tags
    value = unwrap_tags(value)

    # Resolve the final value (in case it's a function inside a tag)
    value = resolve_final_value(value, ctx.opts)

    # Recurse into maps
    if is_map(value) and not is_struct(value) do
      # Only set parent_was_resolved for children when this key was directly
      # requested (not just traversed to reach a deeper target)
      directly_matched =
        ctx.only == [] or parent_was_resolved or matches_only?(path, ctx.only)

      child_parent_resolved = parent_was_resolved or (was_resolved and directly_matched)
      resolve_props(value, ctx, meta, path, child_parent_resolved)
    else
      {value, meta}
    end
  end

  defp unwrap_once(%Once{} = once, path, ctx, meta) do
    once_key = once.key || path
    meta = %{meta | once_props: Map.put(meta.once_props, once_key, build_once_meta(once, path))}

    # Determine if we should skip resolution
    skip =
      once_key in ctx.except_once_props and
        not once.fresh and
        not (ctx.is_partial and matches_only?(path, ctx.only))

    if skip do
      {nil, meta, true}
    else
      {once.fun, meta, false}
    end
  end

  defp unwrap_once(value, _path, _ctx, meta), do: {value, meta, false}

  defp build_once_meta(once, path) do
    %{"prop" => path, "expiresAt" => once.expires_at}
  end

  defp unwrap_scroll(%Scroll{} = scroll, path, _transformed_key, ctx, meta) do
    resolved_value = if is_function(scroll.fun, 0), do: scroll.fun.(), else: scroll.fun
    {entries, base_metadata} = normalize_scroll(resolved_value, scroll)

    # Place entries under the wrapper key (alongside any opt-in `:meta`). The
    # wrapper key is transformed (e.g. camelized) by the prop resolver, and the
    # merge path below applies the same transform to the wrapper segment so the
    # two stay in sync. Entries take precedence on a key collision.
    prop_value =
      scroll.meta
      |> scroll_meta_map(resolved_value)
      |> Map.put(scroll.wrapper, apply_scroll_transform(entries, scroll.transform))

    metadata = finalize_scroll_metadata(base_metadata, resolved_value, scroll)
    merge_path = "#{path}.#{transform_key(scroll.wrapper, ctx.opts)}"

    is_reset = merge_path in ctx.reset

    scroll_meta =
      %{
        "pageName" => metadata.page_name,
        "currentPage" => metadata.current_page,
        "previousPage" => metadata.previous_page,
        "nextPage" => metadata.next_page
      }
      |> then(fn meta_map ->
        if is_reset, do: Map.put(meta_map, "reset", true), else: meta_map
      end)

    meta = %{meta | scroll_props: Map.put(meta.scroll_props, path, scroll_meta)}

    # Add merge path unless reset; use prepend list when intent is "prepend"
    meta =
      if is_reset do
        meta
      else
        meta = %{meta | merge_props: [merge_path | meta.merge_props]}

        if ctx.opts[:scroll_merge_intent] == "prepend" do
          %{meta | prepend_props: [merge_path | meta.prepend_props]}
        else
          meta
        end
      end

    {prop_value, meta}
  end

  defp unwrap_scroll(value, _path, _transformed_key, _ctx, meta), do: {value, meta}

  # Returns {entries, raw_metadata} for the supported paginated shapes.

  # A {entries, meta} tuple (e.g. Flop's {records, %Flop.Meta{}}): the entries are
  # supplied directly and metadata is derived from `meta`. Protocol metadata
  # extraction is skipped when a custom :scroll_metadata function is given, so
  # cursor-based pagination (which would otherwise raise) can still be handled.
  defp normalize_scroll({entries, meta}, scroll) when is_list(entries) do
    raw_metadata =
      cond do
        scroll.scroll_metadata ->
          nil

        Inertia.Paginated.impl_for(meta) ->
          Inertia.Paginated.to_scroll(meta)

        true ->
          raise ArgumentError,
                "inertia_scroll/2 received a {entries, meta} tuple, but #{inspect(meta)} " <>
                  "does not implement the Inertia.Paginated protocol. Implement it, or " <>
                  "pass a :scroll_metadata function."
      end

    {entries, raw_metadata}
  end

  # A struct implementing Inertia.Paginated that carries its own entries
  # (e.g. Scrivener.Page), or a plain %{data: [...], meta: %{...}} map whose
  # entries live under the wrapper key. Anything else is unsupported.
  defp normalize_scroll(value, scroll) do
    cond do
      impl = Inertia.Paginated.impl_for(value) ->
        scroll_map = impl.to_scroll(value)

        case Map.fetch(scroll_map, :entries) do
          {:ok, entries} ->
            {entries, Map.delete(scroll_map, :entries)}

          :error ->
            raise ArgumentError,
                  "#{inspect(value.__struct__)} provides pagination metadata only. " <>
                    "Pass a {entries, meta} tuple to inertia_scroll/2."
        end

      is_map(value) and not is_struct(value) ->
        {fetch_scroll_entries(value, scroll.wrapper), value[:meta] || value["meta"] || %{}}

      true ->
        raise ArgumentError, "inertia_scroll/2 expected paginated data, got: #{inspect(value)}"
    end
  end

  defp fetch_scroll_entries(map, wrapper) do
    Map.get(map, wrapper) || Map.get(map, existing_atom(wrapper)) || []
  end

  defp existing_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> nil
  end

  defp apply_scroll_transform(entries, nil), do: entries

  defp apply_scroll_transform(entries, fun) do
    validate_scroll_fun!(:transform, fun)
    Enum.map(entries, fun)
  end

  defp scroll_meta_map(nil, _value), do: %{}

  defp scroll_meta_map(fun, value) do
    validate_scroll_fun!(:meta, fun)
    %{"meta" => validate_meta_result!(fun.(value))}
  end

  defp validate_scroll_fun!(_opt, fun) when is_function(fun, 1), do: :ok

  defp validate_scroll_fun!(opt, other) do
    raise ArgumentError,
          "inertia_scroll/2 #{inspect(opt)} must be a 1-arity function, got: #{inspect(other)}"
  end

  defp validate_meta_result!(result) when is_map(result), do: result

  defp validate_meta_result!(other) do
    raise ArgumentError,
          "inertia_scroll/2 :meta function must return a map, got: #{inspect(other)}"
  end

  defp resolve_value(fun) when is_function(fun, 0), do: {fun.(), true}
  defp resolve_value(value), do: {value, false}

  # Two-level unwrapping: if a function returned a prop type tag, process it.
  # collect_metadata converts {:defer, {fun, group}} -> {:optional, fun} so the
  # main flow's is_optional? check will exclude it on initial load.
  defp unwrap_second_level({:defer, _} = tagged, path, _tk, ctx, meta, _was_resolved) do
    {wrapped, meta} = collect_metadata(tagged, path, ctx, meta)
    # wrapped is now {:optional, fun} — keep it wrapped for initial-response exclusion
    {wrapped, meta, false}
  end

  defp unwrap_second_level({:optional, _} = value, _path, _tk, _ctx, meta, _was_resolved) do
    {value, meta, false}
  end

  defp unwrap_second_level({:merge, _} = tagged, path, _tk, ctx, meta, was_resolved) do
    {inner, meta} = collect_metadata(tagged, path, ctx, meta)
    {resolved, was_resolved2} = resolve_value(inner)
    {resolved, meta, was_resolved or was_resolved2}
  end

  defp unwrap_second_level({:merge, _, _} = tagged, path, _tk, ctx, meta, was_resolved) do
    {inner, meta} = collect_metadata(tagged, path, ctx, meta)
    {resolved, was_resolved2} = resolve_value(inner)
    {resolved, meta, was_resolved or was_resolved2}
  end

  defp unwrap_second_level({:prepend, _} = tagged, path, _tk, ctx, meta, was_resolved) do
    {inner, meta} = collect_metadata(tagged, path, ctx, meta)
    {resolved, was_resolved2} = resolve_value(inner)
    {resolved, meta, was_resolved or was_resolved2}
  end

  defp unwrap_second_level({:prepend, _, _} = tagged, path, _tk, ctx, meta, was_resolved) do
    {inner, meta} = collect_metadata(tagged, path, ctx, meta)
    {resolved, was_resolved2} = resolve_value(inner)
    {resolved, meta, was_resolved or was_resolved2}
  end

  defp unwrap_second_level({:deep_merge, _} = tagged, path, _tk, ctx, meta, was_resolved) do
    {inner, meta} = collect_metadata(tagged, path, ctx, meta)
    {resolved, was_resolved2} = resolve_value(inner)
    {resolved, meta, was_resolved or was_resolved2}
  end

  defp unwrap_second_level({:deep_merge, _, _} = tagged, path, _tk, ctx, meta, was_resolved) do
    {inner, meta} = collect_metadata(tagged, path, ctx, meta)
    {resolved, was_resolved2} = resolve_value(inner)
    {resolved, meta, was_resolved or was_resolved2}
  end

  defp unwrap_second_level({:keep, _} = value, _path, _tk, _ctx, meta, was_resolved) do
    {value, meta, was_resolved}
  end

  defp unwrap_second_level(%Scroll{} = scroll, path, tk, ctx, meta, _was_resolved) do
    {value, meta} = unwrap_scroll(scroll, path, tk, ctx, meta)
    {value, meta, true}
  end

  defp unwrap_second_level(%Once{} = once, path, _tk, ctx, meta, _was_resolved) do
    {value, meta, skip} = unwrap_once(once, path, ctx, meta)

    if skip do
      {nil, meta, false}
    else
      {val, was_resolved} = resolve_value(value)
      # Check for further nested tags after once unwrap
      case val do
        {:defer, _} = v ->
          {v2, meta2} = collect_metadata(v, path, ctx, meta)
          # v2 is {:optional, fun} — keep wrapped for initial-response exclusion
          {v2, meta2, false}

        _ ->
          {val, meta, was_resolved}
      end
    end
  end

  defp unwrap_second_level(value, _path, _tk, _ctx, meta, was_resolved) do
    {value, meta, was_resolved}
  end

  defp collect_metadata({:merge, inner}, path, ctx, meta) do
    meta =
      if path in ctx.reset do
        meta
      else
        %{meta | merge_props: [path | meta.merge_props]}
      end

    {inner, meta}
  end

  defp collect_metadata({:merge, inner, match_key}, path, ctx, meta) do
    meta =
      if path in ctx.reset do
        meta
      else
        %{
          meta
          | merge_props: [path | meta.merge_props],
            match_props_on: match_prop_entries(path, match_key) ++ meta.match_props_on
        }
      end

    {inner, meta}
  end

  defp collect_metadata({:prepend, inner}, path, ctx, meta) do
    meta =
      if path in ctx.reset do
        meta
      else
        %{
          meta
          | merge_props: [path | meta.merge_props],
            prepend_props: [path | meta.prepend_props]
        }
      end

    {inner, meta}
  end

  defp collect_metadata({:prepend, inner, match_key}, path, ctx, meta) do
    meta =
      if path in ctx.reset do
        meta
      else
        %{
          meta
          | merge_props: [path | meta.merge_props],
            prepend_props: [path | meta.prepend_props],
            match_props_on: match_prop_entries(path, match_key) ++ meta.match_props_on
        }
      end

    {inner, meta}
  end

  defp collect_metadata({:deep_merge, inner}, path, ctx, meta) do
    meta =
      if path in ctx.reset do
        meta
      else
        %{meta | deep_merge_props: [path | meta.deep_merge_props]}
      end

    {inner, meta}
  end

  defp collect_metadata({:deep_merge, inner, match_key}, path, ctx, meta) do
    meta =
      if path in ctx.reset do
        meta
      else
        %{
          meta
          | deep_merge_props: [path | meta.deep_merge_props],
            match_props_on: match_prop_entries(path, match_key) ++ meta.match_props_on
        }
      end

    {inner, meta}
  end

  defp collect_metadata({:defer, {fun, group}}, path, _ctx, meta) do
    {{:optional, fun}, record_deferred(meta, group, path)}
  end

  defp collect_metadata({:defer, {fun, group, :ignore}}, path, _ctx, meta) do
    {{:optional, fun, :rescue}, record_deferred(meta, group, path)}
  end

  defp collect_metadata(value, _path, _ctx, meta), do: {value, meta}

  defp record_deferred(meta, group, path) do
    deferred = meta.deferred_props
    group_keys = Map.get(deferred, group, [])
    %{meta | deferred_props: Map.put(deferred, group, [path | group_keys])}
  end

  # Builds the "path.field" match entries for the matchPropsOn page metadata.
  # The client splits each entry on the final "." to derive the prop path and
  # the field used for item deduplication, so each match key is appended to the
  # prop's full dot-path. A list of keys produces one entry per key.
  defp match_prop_entries(path, match_keys) when is_list(match_keys) do
    Enum.map(match_keys, &"#{path}.#{&1}")
  end

  defp match_prop_entries(path, match_key), do: ["#{path}.#{match_key}"]

  defp optional?({:optional, _}), do: true
  defp optional?({:optional, _, :rescue}), do: true
  defp optional?(_), do: false

  defp unwrap_tags({:optional, v}), do: v
  defp unwrap_tags({:keep, v}), do: v
  defp unwrap_tags({:merge, v}), do: v
  defp unwrap_tags({:merge, v, _}), do: v
  defp unwrap_tags({:prepend, v}), do: v
  defp unwrap_tags({:prepend, v, _}), do: v
  defp unwrap_tags({:deep_merge, v}), do: v
  defp unwrap_tags({:deep_merge, v, _}), do: v
  defp unwrap_tags({:shared, v}), do: v
  defp unwrap_tags(v), do: v

  defp resolve_final_value(value, opts) do
    cond do
      is_function(value, 0) -> resolve_final_value(value.(), opts)
      is_list(value) -> Enum.map(value, &resolve_nested_value(&1, opts))
      true -> value
    end
  end

  defp resolve_nested_value(map, opts) when is_map(map) and not is_struct(map) do
    map
    |> Enum.map(fn {k, v} -> {transform_key(k, opts), resolve_nested_value(v, opts)} end)
    |> Map.new()
  end

  defp resolve_nested_value(list, opts) when is_list(list) do
    Enum.map(list, &resolve_nested_value(&1, opts))
  end

  defp resolve_nested_value(fun, opts) when is_function(fun, 0),
    do: resolve_nested_value(fun.(), opts)

  defp resolve_nested_value(value, _opts), do: value

  # Resolves the final scroll metadata, applying defaults. A custom :scroll_metadata
  # function (operating on the original resolved value) takes precedence over the
  # metadata extracted during normalization. A :page_name option always overrides
  # the resolved page name.
  defp finalize_scroll_metadata(base_metadata, resolved_value, scroll) do
    raw =
      if scroll.scroll_metadata do
        scroll.scroll_metadata.(resolved_value)
      else
        base_metadata || %{}
      end

    %{
      page_name: scroll.page_name || fetch_scroll_meta(raw, :page_name, "page"),
      current_page: fetch_scroll_meta(raw, :current_page),
      previous_page: fetch_scroll_meta(raw, :previous_page),
      next_page: fetch_scroll_meta(raw, :next_page)
    }
  end

  defp fetch_scroll_meta(raw, key, default \\ nil) do
    raw[key] || raw[to_string(key)] || default
  end

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

  # Put flash as a top-level page object key (pre-extracted during build_inertia_response).
  defp maybe_put_flash(assigns, conn) do
    Map.put(assigns, :flash, conn.private.inertia_page.flash)
  end

  defp send_response(%{private: %{inertia_request: true}} = conn) do
    conn
    |> put_status(200)
    |> put_resp_header("x-inertia", "true")
    |> json(inertia_assigns(conn))
  end

  defp send_response(conn) do
    if conn.private[:inertia_ssr] do
      case SSR.call(inertia_assigns(conn)) do
        {:ok, %{"head" => head, "body" => body}} ->
          send_ssr_response(conn, head, body)

        {:error, message} ->
          message = if is_binary(message), do: message, else: inspect(message)

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
    assign(conn, :page_title, unescape_title(page_title))
  end

  defp update_page_title(conn, _), do: conn

  # The client-side adapters HTML-escape the title when rendering it during
  # SSR. Since the extracted value is placed in the `page_title` assign (where
  # HEEx will escape it again on render), unescape it here to avoid
  # double-escaping.
  defp unescape_title(title) do
    Regex.replace(@title_entity_regex, title, fn entity ->
      Map.fetch!(@title_entities, entity)
    end)
  end

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
    |> render(:inertia_page, %{page: inertia_assigns(conn), csp_nonce: csp_nonce(conn)})
  end

  defp csp_nonce(conn) do
    case Application.get_env(:inertia, :csp_nonce_assign_key) do
      nil -> nil
      key -> conn.assigns[key]
    end
  end

  defp inertia_assigns(conn) do
    %{
      component: conn.private.inertia_page.component,
      props: conn.private.inertia_page.props,
      url: request_path(conn),
      version: conn.private.inertia_version
    }
    |> maybe_put_flash(conn)
    |> maybe_put_clear_history(conn)
    |> maybe_put_encrypt_history(conn)
    |> maybe_put_merge_props(conn)
    |> maybe_put_prepend_props(conn)
    |> maybe_put_deep_merge_props(conn)
    |> maybe_put_match_props_on(conn)
    |> maybe_put_deferred_props(conn)
    |> maybe_put_once_props(conn)
    |> maybe_put_scroll_props(conn)
    |> maybe_put_rescued_props(conn)
    |> maybe_put_shared_props(conn)
    |> maybe_put_preserve_fragment(conn)
  end

  defp maybe_put_encrypt_history(assigns, conn) do
    if conn.private.inertia_encrypt_history do
      Map.put(assigns, :encryptHistory, true)
    else
      assigns
    end
  end

  defp maybe_put_clear_history(assigns, conn) do
    if conn.private.inertia_clear_history do
      Map.put(assigns, :clearHistory, true)
    else
      assigns
    end
  end

  defp maybe_put_merge_props(assigns, conn) do
    merge_props = conn.private.inertia_page.merge_props

    if Enum.empty?(merge_props) do
      assigns
    else
      Map.put(assigns, :mergeProps, merge_props)
    end
  end

  defp maybe_put_prepend_props(assigns, conn) do
    prepend_props = conn.private.inertia_page.prepend_props

    if Enum.empty?(prepend_props) do
      assigns
    else
      Map.put(assigns, :prependProps, prepend_props)
    end
  end

  defp maybe_put_deep_merge_props(assigns, conn) do
    deep_merge_props = conn.private.inertia_page.deep_merge_props

    if Enum.empty?(deep_merge_props) do
      assigns
    else
      Map.put(assigns, :deepMergeProps, deep_merge_props)
    end
  end

  defp maybe_put_match_props_on(assigns, conn) do
    match_props_on = conn.private.inertia_page.match_props_on

    if Enum.empty?(match_props_on) do
      assigns
    else
      Map.put(assigns, :matchPropsOn, match_props_on)
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

  defp maybe_put_once_props(assigns, conn) do
    once_props = conn.private.inertia_page.once_props

    if Enum.empty?(once_props) do
      assigns
    else
      Map.put(assigns, :onceProps, once_props)
    end
  end

  defp maybe_put_scroll_props(assigns, conn) do
    scroll_props = conn.private.inertia_page.scroll_props

    if Enum.empty?(scroll_props) do
      assigns
    else
      Map.put(assigns, :scrollProps, scroll_props)
    end
  end

  defp maybe_put_rescued_props(assigns, conn) do
    rescued_props = conn.private.inertia_page.rescued_props

    if Enum.empty?(rescued_props) do
      assigns
    else
      Map.put(assigns, :rescuedProps, rescued_props)
    end
  end

  defp maybe_put_shared_props(assigns, conn) do
    shared_props = conn.private.inertia_page.shared_props

    if Enum.empty?(shared_props) do
      assigns
    else
      Map.put(assigns, :sharedProps, shared_props)
    end
  end

  defp maybe_put_preserve_fragment(assigns, conn) do
    if conn.private[:inertia_preserve_fragment] do
      Map.put(assigns, :preserveFragment, true)
    else
      assigns
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
    enabled = opts[:ssr] || ssr_enabled_globally?()
    put_private(conn, :inertia_ssr, enabled and not ssr_excluded_path?(conn.request_path))
  end

  defp ssr_excluded_path?(path) do
    Enum.any?(Application.get_env(:inertia, :ssr_exclude_paths, []), fn pattern ->
      case pattern do
        %Regex{} -> Regex.match?(pattern, path)
        prefix when is_binary(prefix) -> String.starts_with?(path, prefix)
        _ -> false
      end
    end)
  end

  defp ssr_enabled_globally? do
    Application.get_env(:inertia, :ssr, false)
  end

  defp raise_on_ssr_failure? do
    Application.get_env(:inertia, :raise_on_ssr_failure, true)
  end
end
