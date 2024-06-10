defmodule MyApp.Settings do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:theme, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:theme])
    |> validate_required([:theme])
  end
end
