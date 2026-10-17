defmodule Inertia.DevTools.Router do
  @moduledoc """
  Router helpers for mounting the Inertia DevTools endpoint.

  See `Inertia.DevTools` for setup instructions.
  """

  @doc """
  Defines the routes the DevTools extension reads recorded entries from.

  The extension requests entries at a fixed path, `/_inertia/devtools`,
  relative to where the app is mounted, so these routes must not be placed
  inside a scope with a path prefix.
  """
  defmacro inertia_devtools do
    quote do
      scope "/_inertia/devtools", alias: false, as: false do
        get "/entries", Inertia.DevTools.EntriesPlug, :index
        get "/entries/:id", Inertia.DevTools.EntriesPlug, :show
      end
    end
  end
end
