defmodule TestDU do
  require DiscUnion
  DiscUnion.defunion Asd
  | Qwe in any
  | Rty in integer * atom
  | :qqq
end

defmodule DiscUnionTest do
  use ExUnit.Case, async: true
  doctest DiscUnion

  test "discriminated union can have many case tags" do
    Code.eval_quoted(quote do
                      defmodule TestA do
                        require DiscUnion
                        DiscUnion.defunion Asd | Qwe
                      end
    end)
    Code.eval_quoted(quote do
                      defmodule TestB do
                        require DiscUnion
                        DiscUnion.defunion Asd
                        | Qwe
                        | Rty
                        | Zxc
                      end
    end)
    Code.eval_quoted(quote do
                      defmodule TestC do
                        require DiscUnion
                        DiscUnion.defunion :asd
                        | :qwe
                        | :rtyq
                        | :zxc
                      end
    end)
  end

  test "discriminated union case tags can have multiple arguments" do
    Code.eval_quoted(quote do
                      defmodule TestA do
                        require DiscUnion
                        DiscUnion.defunion Asd
                        | Qwe in any
                        | Rty in integer * atom
                        | Zxc in integer * String.t * String.t
                        | Vbn in {int, int}
                        | Fgh in {int, int} * {any, any, any}
                      end
    end)
  end

  test "discriminated union case tags must be an atom" do
    assert_raise ArgumentError, "union case tag must be an atom", fn ->
      Code.eval_quoted(quote do
                        defmodule TestA do
                          require DiscUnion
                          DiscUnion.defunion 1 | 2 in any
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be an atom", fn ->
      Code.eval_quoted(quote do
                        defmodule TestB do
                          require DiscUnion
                          DiscUnion.defunion 1 | 2 in any
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be an atom", fn ->
      Code.eval_quoted(quote do
                        defmodule TestC do
                          require DiscUnion
                          DiscUnion.defunion 1 | 2 in any*any
                        end
      end)
    end
  end

  test "discriminated union case tags must be unique" do
    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestA do
                          require DiscUnion
                          DiscUnion.defunion Asd | Asd
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestB do
                          require DiscUnion
                          DiscUnion.defunion Asd | Asd in any
                        end
      end)
    end

    assert_raise ArgumentError, "union case tag must be unique", fn ->
      Code.eval_quoted(quote do
                        defmodule TestC do
                          require DiscUnion
                          DiscUnion.defunion Asd | Asd in any*any
                        end
      end)
    end
  end

  test "discriminated union can be constructed from valid cases" do
    asd_case = struct TestDU, %{case: Asd}
    assert TestDU.from(Asd) == asd_case
    assert TestDU.from!(Asd) == asd_case
    assert TestDU.from({Rty, 1, :ok}) != asd_case
    assert TestDU.from!({Rty, 1, :ok}) != asd_case
  end

  test "discriminated union cannot be constructed from invalid cases" do
    assert TestDU.from(Qqq) == nil
    assert TestDU.from(Qqq, :no_such_case) == :no_such_case
    assert_raise FunctionClauseError, "no function clause matching in TestDU.from!/1", fn ->
      TestDU.from!(Qqq)
    end
  end

  test "discriminated union's `case` macro should riase when condition is not evaluated to this discriminated union" do
    assert_raise BadStructError, "expected a struct named TestDU, got: nil", fn ->
      require TestDU
      TestDU.case nil do
               Asd -> :asd
               Qwe in _ -> :qwe
               Rty in _, _ -> :rty
             end
    end
  end

  test "discriminated union's `case` macro accepts the `in` format for case arguments" do
    require TestDU

    x=TestDU.from Asd
    res=TestDU.case x do
                 Asd -> :asd
                 Qwe in _ -> :qwe
                 Rty in _, _ -> :rty
               end
    assert res == :asd

    x=TestDU.from {Qwe, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 Qwe in _ -> :qwe
                 Rty in _, _ -> :rty
               end
    assert res == :qwe

    x=TestDU.from {Rty, 1, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 Qwe in _ -> :qwe
                 Rty in _, _ -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro accepts the tuple format for case arguments" do
    require TestDU

    x=TestDU.from Asd
    res=TestDU.case x do
                 Asd -> :asd
                 {Qwe, _} -> :qwe
                 {Rty, _, _} -> :rty
               end
    assert res == :asd

    x=TestDU.from {Qwe, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 {Qwe, _} -> :qwe
                 {Rty, _, _} -> :rty
               end
    assert res == :qwe

    x=TestDU.from {Rty, 1, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 {Qwe, _} -> :qwe
                 {Rty, _, _} -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the `in` format for case arguments" do
    require TestDU

    c=Asd
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in _ -> z
                 z=Rty in _, _ -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in _ -> z
                 z=Rty in _, _ -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in _ -> z
                 z=Rty in _, _ -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the tuple format for case arguments" do
    require TestDU

    c=Asd
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, _} -> z
                 z={Rty, _, _} -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, _} -> z
                 z={Rty, _, _} -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, _} -> z
                 z={Rty, _, _} -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro accepts the `in` format for case arguments with guard present" do
    require TestDU

    x=TestDU.from Asd
    res=TestDU.case x do
                 Asd -> :asd
                 Qwe in x when x>0 -> :qwe
                 Rty in x, _ when x>0 -> :rty
               end
    assert res == :asd

    x=TestDU.from {Qwe, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 Qwe in x when x>0 -> :qwe
                 Rty in x, _ when x>0 -> :rty
               end
    assert res == :qwe

    x=TestDU.from {Rty, 1, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 Qwe in x when x>0 -> :qwe
                 Rty in x, _ when x>0 -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro accepts the tuple format for case arguments with guard present" do
    require TestDU

    x=TestDU.from Asd
    res=TestDU.case x do
                 Asd -> :asd
                 {Qwe, x} when x>0 -> :qwe
                 {Rty, x, _} when x>0 -> :rty
               end
    assert res == :asd

    x=TestDU.from {Qwe, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 {Qwe, x} when x>0 -> :qwe
                 {Rty, x, _} when x>0 -> :rty
               end
    assert res == :qwe

    x=TestDU.from {Rty, 1, 1}
    res=TestDU.case x do
                 Asd -> :asd
                 {Qwe, x} when x>0 -> :qwe
                 {Rty, x, _} when x>0 -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the `in` format for case arguments with guard present" do
    require TestDU

    c=Asd
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in x when x>0 -> z
                 z=Rty in x, _ when x>0 -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in x when x>0 -> z
                 z=Rty in x, _ when x>0 -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in x when x>0 -> z
                 z=Rty in x, _ when x>0 -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the tuple format for case arguments with guard present" do
    require TestDU

    c=Asd
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, x} when x>0 -> z
                 z={Rty, x, _} when x>0 -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, x} when x>0 -> z
                 z={Rty, x, _}when x>0  -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, x} when x>0 -> z
                 z={Rty, x, _} when x>0 -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro should riase on unknow tags and cases" do
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Qqq
                        TestDU.case x do
                                 Qwe -> :ok
                               end
      end)
    end
  end

  test "discriminated union's `case` macro should riase when not all cases are exhausted" do
    assert_raise MissingUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Asd
                        TestDU.case x do
                                 Asd -> :asd
                                 Qwe in _ -> :qwe
                               end
      end
    end)
  end

end
