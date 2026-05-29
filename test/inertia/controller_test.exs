defmodule Inertia.ControllerTest do
  use ExUnit.Case, async: true

  import Inertia.Controller,
    only: [inertia_optional: 1, inertia_defer: 1, inertia_defer: 2, inertia_defer: 3]

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

    test "accepts on_error: :ignore as options" do
      fun = fn -> 1 end
      assert inertia_defer(fun, on_error: :ignore) == {:defer, {fun, "default", :ignore}}
    end

    test "treats an empty keyword list as the default group" do
      fun = fn -> 1 end
      assert inertia_defer(fun, []) == {:defer, {fun, "default"}}
    end

    test "raises when given a non-keyword list instead of silently defaulting" do
      fun = fn -> 1 end

      assert_raise(ArgumentError, fn ->
        inertia_defer(fun, ["dashboard", "sidebar"])
      end)
    end

    test "raises on an unknown option" do
      fun = fn -> 1 end

      assert_raise(ArgumentError, fn ->
        inertia_defer(fun, on_errors: :ignore)
      end)
    end

    test "raises on an invalid on_error value" do
      fun = fn -> 1 end

      assert_raise(ArgumentError, fn ->
        inertia_defer(fun, on_error: :explode)
      end)
    end
  end

  describe "inertia_defer/3" do
    test "tags as deferred with given group and options" do
      fun = fn -> 1 end

      assert inertia_defer(fun, "dashboard", on_error: :ignore) ==
               {:defer, {fun, "dashboard", :ignore}}
    end

    test "raises an argument error if group is not a string" do
      fun = fn -> 1 end

      assert_raise(ArgumentError, fn ->
        inertia_defer(fun, 3, on_error: :ignore)
      end)
    end

    test "raises on an unknown option" do
      fun = fn -> 1 end

      assert_raise(ArgumentError, fn ->
        inertia_defer(fun, "dashboard", bogus: true)
      end)
    end
  end
end
