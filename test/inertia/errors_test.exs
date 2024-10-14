defmodule Inertia.ErrorsTest do
  use ExUnit.Case, async: true

  alias Inertia.Errors

  describe "process_changeset_errors/1" do
    test "simple map" do
      assert process_changeset_errors(%{"name" => ["is required"]}) == %{
               "name" => "is required"
             }
    end

    test "outputs the first error when there are multiple" do
      assert process_changeset_errors(%{"name" => ["is required", "must be real"]}) == %{
               "name" => "is required"
             }
    end

    test "nested errors" do
      assert process_changeset_errors(%{
               "a" => %{"b" => ["is invalid"]},
               "c" => %{"d" => %{"e" => ["is invalid"]}}
             }) == %{
               "a.b" => "is invalid",
               "c.d.e" => "is invalid"
             }
    end

    test "array of nested errors" do
      assert process_changeset_errors(%{
               "items" => [%{"name" => ["is invalid"]}, %{"name" => ["is invalid"]}]
             }) == %{"items[0].name" => "is invalid", "items[1].name" => "is invalid"}
    end
  end

  defp process_changeset_errors(value) do
    value
    |> Errors.process_changeset_errors()
    |> Map.new()
  end
end
