defmodule Inertia.Plug do
  @moduledoc """
  The plug module for detecting Inertia.js requests.
  """

  import Inertia.Controller, only: [assign_errors: 2]
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn
    |> assign(:inertia_head, [])
    |> put_private(:inertia_version, compute_version())
    |> put_private(:inertia_error_bag, get_error_bag(conn))
    |> put_private(:inertia_encrypt_history, default_encrypt_history())
    |> put_private(:inertia_clear_history, false)
    |> put_private(:inertia_camelize_props, default_camelize_props())
    |> merge_forwarded_flash()
    |> fetch_inertia_errors()
    |> detect_inertia()
  end

  defp fetch_inertia_errors(conn) do
    errors = get_session(conn, "inertia_errors") || %{}
    conn = assign_errors(conn, errors)

    register_before_send(conn, fn %{status: status} = conn ->
      props = conn.private[:inertia_shared] || %{}

      errors =
        case props[:errors] do
          {:keep, data} -> data
          _ -> %{}
        end

      # Keep errors if we are responding with a traditional redirect (301..308)
      # or a force refresh (409) and there are some errors set
      if (status in 300..308 or status == 409) and map_size(errors) > 0 do
        put_session(conn, "inertia_errors", errors)
      else
        delete_session(conn, "inertia_errors")
      end
    end)
  end

  defp detect_inertia(conn) do
    case get_req_header(conn, "x-inertia") do
      ["true"] ->
        conn
        |> put_private(:inertia_version, compute_version())
        |> put_private(:inertia_request, true)
        |> detect_partial_reload()
        |> detect_reset()
        |> convert_redirects()
        |> check_version()

      _ ->
        conn
    end
  end

  defp detect_partial_reload(conn) do
    case get_req_header(conn, "x-inertia-partial-component") do
      [component] when is_binary(component) ->
        conn
        |> put_private(:inertia_partial_component, component)
        |> put_private(:inertia_partial_only, get_partial_only(conn))
        |> put_private(:inertia_partial_except, get_partial_except(conn))

      _ ->
        conn
    end
  end

  defp detect_reset(conn) do
    resets =
      case get_req_header(conn, "x-inertia-reset") do
        [stringified_list] when is_binary(stringified_list) ->
          String.split(stringified_list, ",")

        _ ->
          []
      end

    put_private(conn, :inertia_reset, resets)
  end

  defp get_partial_only(conn) do
    case get_req_header(conn, "x-inertia-partial-data") do
      [stringified_list] when is_binary(stringified_list) ->
        String.split(stringified_list, ",")

      _ ->
        []
    end
  end

  defp get_partial_except(conn) do
    case get_req_header(conn, "x-inertia-partial-except") do
      [stringified_list] when is_binary(stringified_list) ->
        String.split(stringified_list, ",")

      _ ->
        []
    end
  end

  defp get_error_bag(conn) do
    case get_req_header(conn, "x-inertia-error-bag") do
      [error_bag] when is_binary(error_bag) -> error_bag
      _ -> nil
    end
  end

  defp convert_redirects(conn) do
    register_before_send(conn, fn %{method: method, status: status} = conn ->
      cond do
        # see: https://inertiajs.com/redirects#external-redirects
        external_redirect?(conn) ->
          [location] = get_resp_header(conn, "location")

          conn
          |> put_status(409)
          |> put_resp_header("x-inertia-location", location)

        # see: https://inertiajs.com/redirects#303-response-code
        method in ["PUT", "PATCH", "DELETE"] and status in [301, 302] ->
          put_status(conn, 303)

        true ->
          conn
      end
    end)
  end

  defp external_redirect?(%{status: status} = conn) when status in 300..308 do
    [location] = get_resp_header(conn, "location")
    !String.starts_with?(location, "/")
  end

  defp external_redirect?(_conn), do: false

  # see: https://inertiajs.com/the-protocol#asset-versioning
  defp check_version(%{private: %{inertia_version: current_version}} = conn) do
    if conn.method == "GET" && get_req_header(conn, "x-inertia-version") != [current_version] do
      force_refresh(conn)
    else
      conn
    end
  end

  defp compute_version do
    if is_atom(endpoint()) and length(static_paths()) > 0 do
      hash_static_paths(endpoint(), static_paths())
    else
      default_version()
    end
  end

  defp hash_static_paths(endpoint, paths) do
    paths
    |> Enum.map_join(&endpoint.static_path(&1))
    |> then(&Base.encode16(:crypto.hash(:md5, &1), case: :lower))
  end

  defp force_refresh(conn) do
    conn
    |> put_resp_header("x-inertia-location", request_url(conn))
    |> put_resp_content_type("text/html")
    |> forward_flash()
    |> send_resp(:conflict, "")
    |> halt()
  end

  defp forward_flash(%{assigns: %{flash: flash}} = conn)
       when is_map(flash) and map_size(flash) > 0 do
    put_session(conn, "inertia_flash", flash)
  end

  defp forward_flash(conn), do: conn

  defp merge_forwarded_flash(conn) do
    case get_session(conn, "inertia_flash") do
      nil ->
        conn

      flash ->
        conn
        |> delete_session("inertia_flash")
        |> assign(:flash, Map.merge(conn.assigns.flash, flash))
    end
  end

  defp static_paths do
    Application.get_env(:inertia, :static_paths, [])
  end

  defp endpoint do
    Application.get_env(:inertia, :endpoint, nil)
  end

  defp default_version do
    Application.get_env(:inertia, :default_version, "1")
  end

  defp default_camelize_props do
    Application.get_env(:inertia, :camelize_props, false)
  end

  defp default_encrypt_history do
    history_config = Application.get_env(:inertia, :history) || []
    !!history_config[:encrypt]
  end
end
