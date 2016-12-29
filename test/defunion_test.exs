defmodule DiscUnionTest.Defunion do
  use ExUnit.Case, async: true

  test "discriminated union can have many case tags" do
    Code.eval_quoted(quote do
                      defmodule TestUnion0 do
                        use DiscUnion
                        defunion Asd | Qwe
                      end
    end)
    Code.eval_quoted(quote do
                      defmodule TestUnion1 do
                        use DiscUnion
                        defunion :asd | :qwe
                      end
    end)

    Code.eval_quoted(quote do
                      defmodule TestUnion2 do
                        use DiscUnion
                        defunion Asd
                        | Qwe
                        | Rty
                        | Zxc
                      end
    end)
    Code.eval_quoted(quote do
                      defmodule TestUnion3 do
                        use DiscUnion
                        defunion :asd
                        | :qwe
                        | :rtyq
                        | :zxc
                      end
    end)
  end

  test "discriminated union case tags can have multiple arguments" do
    Code.eval_quoted(quote do
                      defmodule TestUnion4 do
                        use DiscUnion
                        defunion Asd
                        | Qwe in any
                        | Rty in integer * atom
                        | Zxc in integer * String.t * String.t
                        | Vbn in {integer, integer}
                        | Fgh in {integer, integer} * {any, any, any}
                      end
    end)
    Code.eval_quoted(quote do
                      defmodule TestUnion5 do
                        use DiscUnion
                        defunion :asd
                        | :qwe in any
                        | :rty in integer * atom
                        | :zxc in integer * String.t * String.t
                        | :vbn in {integer, integer}
                        | :fgh in {integer, integer} * {any, any, any}
                      end
    end)
  end

  test "discriminated union case tags must be an atom" do
    assert_raise ArgumentError, "union case tag must be an atom", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion6 do
                          use DiscUnion
                          defunion 1 | 2
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be an atom", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion7 do
                          use DiscUnion
                          defunion 1 | 2 in any
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be an atom", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion8 do
                          use DiscUnion
                          defunion 1 | 2 in any*any
                        end
      end)
    end
  end

  test "discriminated union case tags must be unique" do
    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion9 do
                          use DiscUnion
                          defunion Asd | Asd
                        end
      end)
    end
    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion10 do
                          use DiscUnion
                          defunion :asd | :asd
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion11 do
                          use DiscUnion
                          defunion Asd | Asd in any
                        end
      end)
    end
    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion12 do
                          use DiscUnion
                          defunion :asd | :asd in any
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion13 do
                          use DiscUnion
                          defunion Asd | Asd in any*any
                        end
      end)
    end
    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestUnion14 do
                          use DiscUnion
                          defunion :asd | :asd in any*any
                        end
      end)
    end
  end
end
