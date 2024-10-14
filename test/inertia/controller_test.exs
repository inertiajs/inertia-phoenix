defmodule Inertia.ControllerTest do
  use ExUnit.Case, async: true

  import Inertia.Controller, only: [inertia_optional: 1, inertia_defer: 1, inertia_defer: 2]

  describe "inertia_optional/1" do
    test "tags a value as optional" do
      fun = fn -> 1 end
      assert inertia_optional(fun) == {:optional, fun}
    end

    test "raises an argument error if value is not a function" do
      assert_raise(ArgumentError, fn ->
        inertia_optional("1")
      end)
    end
  end

  describe "inertia_defer/1" do
    test "tags as deferred with 'default' group" do
      fun = fn -> 1 end
      assert inertia_defer(fun) == {:defer, {fun, "default"}}
    end

    test "raises an argument error if value is not a function" do
      assert_raise(ArgumentError, fn ->
        inertia_defer("1")
      end)
    end
  end

  describe "inertia_defer/2" do
    test "tags as deferred with given group" do
      fun = fn -> 1 end
      assert inertia_defer(fun, "dashboard") == {:defer, {fun, "dashboard"}}
    end

    test "raises an argument error if value is not a function" do
      assert_raise(ArgumentError, fn ->
        inertia_defer("1", "dashboard")
      end)
    end

    test "raises an argument error if group is not a string" do
      fun = fn -> 1 end

      assert_raise(ArgumentError, fn ->
        inertia_defer(fun, 3)
      end)
    end
  end
end
