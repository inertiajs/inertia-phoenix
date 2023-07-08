defmodule MyAppWeb.Layouts do
  @moduledoc false

  use MyAppWeb, :html

  import Inertia.HTML

  embed_templates "layouts/*"
end
