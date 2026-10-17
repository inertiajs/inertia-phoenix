defmodule Inertia.DevTools.ULID do
  @moduledoc false

  # Crockford's base32 alphabet, as used by the ULID spec.
  @alphabet "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

  @doc """
  Generates a ULID: a 48-bit millisecond timestamp followed by 80 bits that
  are otherwise random, encoded as 26 characters.

  ULIDs sort lexically by creation time, which the entry store relies on to
  list entries newest first. So that ids created within the same millisecond
  sort too, the first 32 of the 80 bits are a monotonic counter.
  """
  @spec generate() :: String.t()
  def generate do
    timestamp = System.system_time(:millisecond)
    counter = rem(:erlang.unique_integer([:positive, :monotonic]), 0x100000000)

    encode(<<0::2, timestamp::48, counter::32, :crypto.strong_rand_bytes(6)::binary>>)
  end

  @doc """
  Returns whether the given value is a well-formed ULID.
  """
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value) and byte_size(value) == 26 do
    for <<char <- value>>, reduce: true do
      valid -> valid and :binary.match(@alphabet, <<char>>) != :nomatch
    end
  end

  def valid?(_), do: false

  defp encode(bits) do
    for <<chunk::5 <- bits>>, into: "", do: <<:binary.at(@alphabet, chunk)>>
  end
end
