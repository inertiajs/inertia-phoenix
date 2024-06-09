defmodule Inertia.ControllerTest do
  use ExUnit.Case, async: true

  import Inertia.Controller, only: [inertia_lazy: 1]

  describe "inertia_lazy/1" do
    test "tags a value as lazy" do
      fun = fn -> 1 end
      assert inertia_lazy(fun) == {:lazy, fun}
    end

    test "raises an argument error if value is not a function" do
      assert_raise(ArgumentError, fn ->
        inertia_lazy("1")
      end)
    end
  end
end
