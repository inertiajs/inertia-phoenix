defmodule Inertia.ErrorsTest do
  use ExUnit.Case, async: true

  alias Inertia.Errors
  alias Ecto.Changeset

  describe "to_errors/1 for Map" do
    test "passes through valid errors" do
      assert Errors.to_errors(%{"foo" => "bar"}) == %{"foo" => "bar"}
      assert Errors.to_errors(%{foo: "bar"}) == %{foo: "bar"}
    end

    test "passes through valid bagged errors" do
      assert Errors.to_errors(%{"updateCompany" => %{"foo" => "bar"}}) == %{
               "updateCompany" => %{"foo" => "bar"}
             }
    end

    test "raises an exception if errors are not the valid shape" do
      assert_raise(ArgumentError, fn ->
        # Errors must be a flat mapping of string or atom keys to string values
        Errors.to_errors(%{"foo" => ["bar"]})
      end)
    end
  end

  describe "to_errors/1 for Ecto.Changeset" do
    test "simple error" do
      assert Errors.to_errors(%Changeset{
               action: :insert,
               errors: [
                 name: {"can't be blank", [validation: :required]}
               ],
               data: %{},
               valid?: false
             }) == %{
               name: "can't be blank"
             }
    end

    test "outputs the first error when there are multiple" do
      assert Errors.to_errors(%Changeset{
               action: :insert,
               errors: [
                 name: {"can't be blank", [validation: :required]},
                 name: {"must be real", [validation: :realness]}
               ],
               data: %{},
               valid?: false
             }) == %{
               name: "can't be blank"
             }
    end

    test "nested errors" do
      assert Errors.to_errors(%Changeset{
               action: :insert,
               errors: [],
               changes: %{
                 settings: %Changeset{
                   errors: [color: {"must be a valid hex color", []}]
                 }
               },
               types: %{settings: {:assoc, %{cardinality: :one}}},
               data: %{},
               valid?: false
             }) == %{"settings.color" => "must be a valid hex color"}
    end

    test "array of nested errors" do
      assert Errors.to_errors(%Changeset{
               action: :insert,
               errors: [],
               changes: %{
                 items: [
                   %Changeset{
                     errors: [name: {"can't be blank", []}]
                   }
                 ]
               },
               types: %{items: {:assoc, %{cardinality: :many}}},
               data: %{},
               valid?: false
             }) == %{"items[0].name" => "can't be blank"}
    end
  end

  describe "to_errors/2 for Ecto.Changeset" do
    test "uses custom message function" do
      assert Errors.to_errors(
               %Changeset{
                 action: :insert,
                 errors: [
                   name: {"can't be blank", [validation: :required]}
                 ],
                 data: %{},
                 valid?: false
               },
               fn {_msg, _opts} -> "Custom message" end
             ) == %{
               name: "Custom message"
             }
    end
  end
end
