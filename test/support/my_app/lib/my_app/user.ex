defmodule MyApp.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    embeds_one(:settings, MyApp.Settings)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name])
    |> cast_embed(:settings, required: true)
    |> validate_required([:name])
  end
end
