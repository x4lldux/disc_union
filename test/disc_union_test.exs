defmodule TestDU do
  use DiscUnion
  defunion Asd
  | Qwe in any
  | Rty in integer * atom
end
defmodule TestDUa do
  use DiscUnion
  defunion :asd
  | :qwe in any
  | :rty in integer * atom
end
defmodule TestDUdc do
  use DiscUnion, dyn_constructors: false

  defunion A | B | C
end

defmodule DiscUnionTest do
  use ExUnit.Case, async: true
  doctest DiscUnion

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
                        | Vbn in {int, int}
                        | Fgh in {int, int} * {any, any, any}
                      end
    end)
    Code.eval_quoted(quote do
                      defmodule TestUnion5 do
                        use DiscUnion
                        defunion :asd
                        | :qwe in any
                        | :rty in integer * atom
                        | :zxc in integer * String.t * String.t
                        | :vbn in {int, int}
                        | :fgh in {int, int} * {any, any, any}
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

  test "discriminated union can be constructed via `from/1` and `from!/1` from valid cases" do
    require TestDU
    require TestDUa

    asd_case = struct TestDU, %{case: Asd}
    rty_case = struct TestDU, %{case: {Rty, 1, :ok}}
    assert TestDU.from(Asd) == asd_case
    assert TestDU.from({Rty, 1, :ok}) == rty_case
    assert TestDU.from!(Asd) == asd_case
    assert TestDU.from!({Rty, 1, :ok}) == rty_case

    asd_case = struct TestDUa, %{case: :asd}
    rty_case = struct TestDUa, %{case: {:rty, 1, :ok}}
    assert TestDUa.from(:asd) == asd_case
    assert TestDUa.from({:rty, 1, :ok}) == rty_case
    assert TestDUa.from!(:asd) == asd_case
    assert TestDUa.from!({:rty, 1, :ok}) == rty_case
  end

  test "discriminated union can be constructed via `c/1` from valid cases" do
    require TestDU
    require TestDUa

    asd_case = struct TestDU, %{case: Asd}
    rty_case = struct TestDU, %{case: {Rty, 1, :ok}}
    assert TestDU.c(Asd) == asd_case
    assert TestDU.c(Rty, 1, :ok) == rty_case

    asd_case = struct TestDUa, %{case: :asd}
    rty_case = struct TestDUa, %{case: {:rty, 1, :ok}}
    assert TestDUa.c(:asd) == asd_case
    assert TestDUa.c(:rty, 1, :ok) == rty_case
  end

  test "discriminated union can be constructed via dynamic constructors that construct at compile-time from valid cases" do
    require TestDU
    require TestDUa

    asd_case = struct TestDU, %{case: Asd}
    rty_case = struct TestDU, %{case: {Rty, 1, :ok}}
    assert TestDU.asd == asd_case
    assert TestDU.asd == TestDU.from(Asd)
    assert TestDU.asd == TestDU.from!(Asd)
    assert TestDU.rty(1, :ok) == rty_case
    assert TestDU.rty(1, :ok) == TestDU.from({Rty, 1, :ok})
    assert TestDU.rty(1, :ok) == TestDU.from!({Rty, 1, :ok})

    asd_case = struct TestDUa, %{case: :asd}
    rty_case = struct TestDUa, %{case: {:rty, 1, :ok}}
    assert TestDUa.asd == asd_case
    assert TestDUa.rty(1, :ok) == rty_case
    assert TestDUa.rty(1, :ok) == TestDUa.from({:rty, 1, :ok})
    assert TestDUa.rty(1, :ok) == TestDUa.from!({:rty, 1, :ok})
  end

  test "discriminated union's dynamic constructors should not be created when `dyn_constructors` is false" do
    assert_raise UndefinedFunctionError, fn ->
      Code.eval_quoted(quote do
                        require TestDUdc
                        TestDUdc.a
      end)
    end
  end

  test "discriminated union's `from` constructor rises at compile-time for invalid cases" do
    assert_raise UndefinedUnionCaseError, "undefined union case: Qqq", fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        TestDU.from Qqq
      end)
    end
    assert_raise UndefinedUnionCaseError, "undefined union case: Qqq in _", fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        TestDU.from {Qqq, 123}
      end)
    end
    assert_raise UndefinedUnionCaseError, "undefined union case: :qqq", fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        TestDUa.from :qqq
      end)
    end
    assert_raise UndefinedUnionCaseError, "undefined union case: :qqq in _", fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        TestDUa.from {:qqq, 123}
      end)
    end
  end

  test "discriminated union's `from!` constructor rises at run-time for invalid cases" do
    assert_raise UndefinedUnionCaseError, fn ->
      require TestDU
      TestDU.from! Qqq
    end
    assert TestDU.from!(Qqq, :no_such_case) == :no_such_case

    assert_raise UndefinedUnionCaseError, fn ->
      require TestDUa
      TestDUa.from! :qqq
    end
    assert TestDUa.from!(:qqq, :no_such_case) == :no_such_case
  end

  test "discriminated union's `c` constructor rises at compile-time for invalid cases" do
    assert_raise UndefinedUnionCaseError, "undefined union case: Qqq", fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        TestDU.c Qqq
      end)
    end
    assert_raise UndefinedUnionCaseError, "undefined union case: Qqq in _", fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        TestDU.c Qqq, 123
      end)
    end
    assert_raise UndefinedUnionCaseError, "undefined union case: :qqq", fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        TestDUa.c :qqq
      end)
    end
    assert_raise UndefinedUnionCaseError, "undefined union case: :qqq in _", fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        TestDUa.c :qqq, 123
      end)
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
    assert_raise BadStructError, "expected a struct named TestDUa, got: nil", fn ->
      require TestDUa
      TestDUa.case nil do
               :asd -> :asd
               :qwe in _ -> :qwe
               :rty in _, _ -> :rty
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

    # tests for pure atoms
    require TestDUa

    x=TestDUa.from :asd
    res=TestDUa.case x do
                 :asd -> :asd
                 :qwe in _ -> :qwe
                 :rty in _, _ -> :rty
               end
    assert res == :asd

    x=TestDUa.from {:qwe, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 :qwe in _ -> :qwe
                 :rty in _, _ -> :rty
               end
    assert res == :qwe

    x=TestDUa.from {:rty, 1, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 :qwe in _ -> :qwe
                 :rty in _, _ -> :rty
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

    # tests for pure atoms
    require TestDUa

    x=TestDUa.from :asd
    res=TestDUa.case x do
                 :asd -> :asd
                 {:qwe, _} -> :qwe
                 {:rty, _, _} -> :rty
               end
    assert res == :asd

    x=TestDUa.from {:qwe, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 {:qwe, _} -> :qwe
                 {:rty, _, _} -> :rty
               end
    assert res == :qwe

    x=TestDUa.from {:rty, 1, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 {:qwe, _} -> :qwe
                 {:rty, _, _} -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the `in` format for case arguments" do
    require TestDU

    c=Asd
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in _ -> z
                 z=Rty in _, _ -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in _ -> z
                 z=Rty in _, _ -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in _ -> z
                 z=Rty in _, _ -> z
               end
    assert res == c

    # tests for pure atoms
    require TestDUa

    c=:asd
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z=:qwe in _ -> z
                 z=:rty in _, _ -> z
               end
    assert res == c

    c={:qwe, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z=:qwe in _ -> z
                 z=:rty in _, _ -> z
               end
    assert res == c

    c={:rty, 1, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z=:qwe in _ -> z
                 z=:rty in _, _ -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the tuple format for case arguments" do
    require TestDU

    c=Asd
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, _} -> z
                 z={Rty, _, _} -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, _} -> z
                 z={Rty, _, _} -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, _} -> z
                 z={Rty, _, _} -> z
               end
    assert res == c

    # tests for pure atoms
    require TestDUa

    c=:asd
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z={:qwe, _} -> z
                 z={:rty, _, _} -> z
               end
    assert res == c

    c={:qwe, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z={:qwe, _} -> z
                 z={:rty, _, _} -> z
               end
    assert res == c

    c={:rty, 1, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z={:qwe, _} -> z
                 z={:rty, _, _} -> z
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

    # tests for pure atoms
    require TestDUa

    x=TestDUa.from :asd
    res=TestDUa.case x do
                 :asd -> :asd
                 :qwe in x when x>0 -> :qwe
                 :rty in x, _ when x>0 -> :rty
               end
    assert res == :asd

    x=TestDUa.from {:qwe, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 :qwe in x when x>0 -> :qwe
                 :rty in x, _ when x>0 -> :rty
               end
    assert res == :qwe

    x=TestDUa.from {:rty, 1, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 :qwe in x when x>0 -> :qwe
                 :rty in x, _ when x>0 -> :rty
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

    # tests for pure atoms
    require TestDUa

    x=TestDUa.from :asd
    res=TestDUa.case x do
                 :asd -> :asd
                 {:qwe, x} when x>0 -> :qwe
                 {:rty, x, _} when x>0 -> :rty
               end
    assert res == :asd

    x=TestDUa.from {:qwe, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 {:qwe, x} when x>0 -> :qwe
                 {:rty, x, _} when x>0 -> :rty
               end
    assert res == :qwe

    x=TestDUa.from {:rty, 1, 1}
    res=TestDUa.case x do
                 :asd -> :asd
                 {:qwe, x} when x>0 -> :qwe
                 {:rty, x, _} when x>0 -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the `in` format for case arguments with guard present" do
    require TestDU

    c=Asd
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in x when x>0 -> z
                 z=Rty in x, _ when x>0 -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in x when x>0 -> z
                 z=Rty in x, _ when x>0 -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z=Qwe in x when x>0 -> z
                 z=Rty in x, _ when x>0 -> z
               end
    assert res == c

    # tests for pure atoms
    require TestDUa

    c=:asd
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z=:qwe in x when x>0 -> z
                 z=:rty in x, _ when x>0 -> z
               end
    assert res == c

    c={:qwe, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z=:qwe in x when x>0 -> z
                 z=:rty in x, _ when x>0 -> z
               end
    assert res == c

    c={:rty, 1, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z=:qwe in x when x>0 -> z
                 z=:rty in x, _ when x>0 -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the tuple format for case arguments with guard present" do
    require TestDU

    c=Asd
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, x} when x>0 -> z
                 z={Rty, x, _} when x>0 -> z
               end
    assert res == c

    c={Qwe, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, x} when x>0 -> z
                 z={Rty, x, _}when x>0  -> z
               end
    assert res == c

    c={Rty, 1, 1}
    x=TestDU.from! c
    res=TestDU.case x do
                 z=Asd -> z
                 z={Qwe, x} when x>0 -> z
                 z={Rty, x, _} when x>0 -> z
               end
    assert res == c

    # tests for pure atoms
    require TestDUa

    c=:asd
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z={:qwe, x} when x>0 -> z
                 z={:rty, x, _} when x>0 -> z
               end
    assert res == c

    c={:qwe, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z={:qwe, x} when x>0 -> z
                 z={:rty, x, _}when x>0  -> z
               end
    assert res == c

    c={:rty, 1, 1}
    x=TestDUa.from! c
    res=TestDUa.case x do
                 z=:asd -> z
                 z={:qwe, x} when x>0 -> z
                 z={:rty, x, _} when x>0 -> z
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

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :qqq
                        TestDUa.case x do
                                 :qwe -> :ok
                               end
      end)
    end
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Qqq
                        TestDU.case x do
                                 Wat -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :qqq
                        TestDUa.case x do
                                 :wat -> :ok
                               end
      end)
    end
  end

  test "discriminated union's `case` macro should riase on unknow tags and cases even whet `allow_underscore` is true" do
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Qqq
                        TestDU.case x, allow_underscore: true do
                                 Qwe -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :qqq
                        TestDUa.case x, allow_underscore: true do
                                 :qwe -> :ok
                               end
      end)
    end
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Qqq
                        TestDU.case x, allow_underscore: true do
                                 Wat -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :qqq
                        TestDUa.case x, allow_underscore: true do
                                 :wat -> :ok
                               end
      end)
    end
  end

  test "discriminated union's `case` macro should riase when not all cases are exhausted" do
    testdu_msg = "not all defined union cases are used, should be all of: Asd, Qwe in \"any\", Rty in \"integer\" * \"atom\""
    testdua_msg = "not all defined union cases are used, should be all of: :asd, :qwe in \"any\", :rty in \"integer\" * \"atom\""

    assert_raise MissingUnionCaseError, testdu_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Asd
                        TestDU.case x do
                                 Asd -> :asd
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdu_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Asd
                        TestDU.case x do
                                 Asd -> :asd
                                 Qwe in 1 -> :qwe
                                 Qwe in x when x > 1 -> :qwe
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :asd
                        TestDUa.case x do
                                 :asd -> :asd
                                 :qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :asd
                        TestDUa.case x do
                                 :asd -> :asd
                                 :qwe in 1 -> :qwe
                                 :qwe in x when x >2 -> :qwe
                                 :qwe in _ -> :qwe
                               end
      end)
    end
  end

  test "discriminated union's `case` macro should riase when not all cases are exhausted unless `allow_underscore` is set to true" do
    testdu_msg = "not all defined union cases are used, should be at least a catch all statement (_) and any combination of: Asd, Qwe in \"any\", Rty in \"integer\" * \"atom\""
    testdua_msg = "not all defined union cases are used, should be at least a catch all statement (_) and any combination of: :asd, :qwe in \"any\", :rty in \"integer\" * \"atom\""

    assert_raise MissingUnionCaseError, testdu_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Asd
                        TestDU.case x, allow_underscore: true do
                                 Asd -> :asd
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdu_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDU
                        x=struct TestDU, case: Asd
                        TestDU.case x, allow_underscore: true do
                                 Asd -> :asd
                                 Qwe in 1 -> :qwe
                                 Qwe in x when x > 1 -> :qwe
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :asd
                        TestDUa.case x, allow_underscore: true do
                                 :asd -> :asd
                                 :qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        require TestDUa
                        x=struct TestDUa, case: :asd
                        TestDUa.case x, allow_underscore: true do
                                 :asd -> :asd
                                 :qwe in 1 -> :qwe
                                 :qwe in x when x >2 -> :qwe
                                 :qwe in _ -> :qwe
                               end
      end)
    end
  end

end
