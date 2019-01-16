defmodule DiscUnionTest.Case do
  use ExUnit.Case, async: true

  test "discriminated union's `case` macro should riase when condition is not evaluated to this discriminated union" do
    assert_raise BadStructError, "expected a struct named ExampleDU, got: nil", fn ->
      use ExampleDU
      ExampleDU.case nil do
               Asd -> :asd
               Qwe in _ -> :qwe
               Rty in _, _ -> :rty
             end
    end
    assert_raise BadStructError, "expected a struct named ExampleDUa, got: nil", fn ->
      use ExampleDUa
      ExampleDUa.case nil do
               :asd -> :asd
               :qwe in _ -> :qwe
               :rty in _, _ -> :rty
             end
    end
  end

  test "discriminated union's `case` macro accepts the `in` format for case arguments" do
    use ExampleDU

    x = ExampleDU.from Asd
    res = ExampleDU.case x do
                 Asd -> :asd
                 Qwe in _ -> :qwe
                 Rty in _, _ -> :rty
               end
    assert res == :asd

    x = ExampleDU.from {Qwe, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 Qwe in _ -> :qwe
                 Rty in _, _ -> :rty
               end
    assert res == :qwe

    x = ExampleDU.from {Rty, 1, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 Qwe in _ -> :qwe
                 Rty in _, _ -> :rty
               end
    assert res == :rty

    # tests for pure atoms
    use ExampleDUa

    x = ExampleDUa.from :asd
    res = ExampleDUa.case x do
                 :asd -> :asd
                 :qwe in _ -> :qwe
                 :rty in _, _ -> :rty
               end
    assert res == :asd

    x = ExampleDUa.from {:qwe, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 :qwe in _ -> :qwe
                 :rty in _, _ -> :rty
               end
    assert res == :qwe

    x = ExampleDUa.from {:rty, 1, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 :qwe in _ -> :qwe
                 :rty in _, _ -> :rty
               end
    assert res == :rty

  end

  test "discriminated union's `case` macro accepts the tuple format for case arguments" do
    use ExampleDU

    x = ExampleDU.from Asd
    res = ExampleDU.case x do
                 Asd -> :asd
                 {Qwe, _} -> :qwe
                 {Rty, _, _} -> :rty
               end
    assert res == :asd

    x = ExampleDU.from {Qwe, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 {Qwe, _} -> :qwe
                 {Rty, _, _} -> :rty
               end
    assert res == :qwe

    x = ExampleDU.from {Rty, 1, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 {Qwe, _} -> :qwe
                 {Rty, _, _} -> :rty
               end
    assert res == :rty

    # tests for pure atoms
    use ExampleDUa

    x = ExampleDUa.from :asd
    res = ExampleDUa.case x do
                 :asd -> :asd
                 {:qwe, _} -> :qwe
                 {:rty, _, _} -> :rty
               end
    assert res == :asd

    x = ExampleDUa.from {:qwe, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 {:qwe, _} -> :qwe
                 {:rty, _, _} -> :rty
               end
    assert res == :qwe

    x = ExampleDUa.from {:rty, 1, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 {:qwe, _} -> :qwe
                 {:rty, _, _} -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the `in` format for case arguments" do
    use ExampleDU

    c = Asd
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = Qwe in _ -> z
                 z = Rty in _, _ -> z
               end
    assert res == c

    c = {Qwe, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = Qwe in _ -> z
                 z = Rty in _, _ -> z
               end
    assert res == c

    c = {Rty, 1, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = Qwe in _ -> z
                 z = Rty in _, _ -> z
               end
    assert res == c

    # tests for pure atoms
    use ExampleDUa

    c = :asd
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = :qwe in _ -> z
                 z = :rty in _, _ -> z
               end
    assert res == c

    c = {:qwe, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = :qwe in _ -> z
                 z = :rty in _, _ -> z
               end
    assert res == c

    c = {:rty, 1, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = :qwe in _ -> z
                 z = :rty in _, _ -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the tuple format for case arguments" do
    use ExampleDU

    c = Asd
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = {Qwe, _} -> z
                 z = {Rty, _, _} -> z
               end
    assert res == c

    c = {Qwe, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = {Qwe, _} -> z
                 z = {Rty, _, _} -> z
               end
    assert res == c

    c = {Rty, 1, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = {Qwe, _} -> z
                 z = {Rty, _, _} -> z
               end
    assert res == c

    # tests for pure atoms
    use ExampleDUa

    c = :asd
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = {:qwe, _} -> z
                 z = {:rty, _, _} -> z
               end
    assert res == c

    c = {:qwe, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = {:qwe, _} -> z
                 z = {:rty, _, _} -> z
               end
    assert res == c

    c = {:rty, 1, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = {:qwe, _} -> z
                 z = {:rty, _, _} -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro accepts the `in` format for case arguments with guard present" do
    use ExampleDU

    x = ExampleDU.from Asd
    res = ExampleDU.case x do
                 Asd -> :asd
                 Qwe in x when x > 0 -> :qwe
                 Rty in x, _ when x > 0 -> :rty
               end
    assert res == :asd

    x = ExampleDU.from {Qwe, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 Qwe in x when x > 0 -> :qwe
                 Rty in x, _ when x > 0 -> :rty
               end
    assert res == :qwe

    x = ExampleDU.from {Rty, 1, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 Qwe in x when x > 0 -> :qwe
                 Rty in x, _ when x > 0 -> :rty
               end
    assert res == :rty

    # tests for pure atoms
    use ExampleDUa

    x = ExampleDUa.from :asd
    res = ExampleDUa.case x do
                 :asd -> :asd
                 :qwe in x when x > 0 -> :qwe
                 :rty in x, _ when x > 0 -> :rty
               end
    assert res == :asd

    x = ExampleDUa.from {:qwe, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 :qwe in x when x > 0 -> :qwe
                 :rty in x, _ when x > 0 -> :rty
               end
    assert res == :qwe

    x = ExampleDUa.from {:rty, 1, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 :qwe in x when x > 0 -> :qwe
                 :rty in x, _ when x > 0 -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro accepts the tuple format for case arguments with guard present" do
    use ExampleDU

    x = ExampleDU.from Asd
    res = ExampleDU.case x do
                 Asd -> :asd
                 {Qwe, x} when x > 0 -> :qwe
                 {Rty, x, _} when x > 0 -> :rty
               end
    assert res == :asd

    x = ExampleDU.from {Qwe, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 {Qwe, x} when x > 0 -> :qwe
                 {Rty, x, _} when x > 0 -> :rty
               end
    assert res == :qwe

    x = ExampleDU.from {Rty, 1, 1}
    res = ExampleDU.case x do
                 Asd -> :asd
                 {Qwe, x} when x > 0 -> :qwe
                 {Rty, x, _} when x > 0 -> :rty
               end
    assert res == :rty

    # tests for pure atoms
    use ExampleDUa

    x = ExampleDUa.from :asd
    res = ExampleDUa.case x do
                 :asd -> :asd
                 {:qwe, x} when x > 0 -> :qwe
                 {:rty, x, _} when x > 0 -> :rty
               end
    assert res == :asd

    x = ExampleDUa.from {:qwe, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 {:qwe, x} when x > 0 -> :qwe
                 {:rty, x, _} when x > 0 -> :rty
               end
    assert res == :qwe

    x = ExampleDUa.from {:rty, 1, 1}
    res = ExampleDUa.case x do
                 :asd -> :asd
                 {:qwe, x} when x > 0 -> :qwe
                 {:rty, x, _} when x > 0 -> :rty
               end
    assert res == :rty
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the `in` format for case arguments with guard present" do
    use ExampleDU

    c = Asd
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = Qwe in x when x > 0 -> z
                 z = Rty in x, _ when x > 0 -> z
               end
    assert res == c

    c = {Qwe, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = Qwe in x when x > 0 -> z
                 z = Rty in x, _ when x > 0 -> z
               end
    assert res == c

    c = {Rty, 1, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = Qwe in x when x > 0 -> z
                 z = Rty in x, _ when x > 0 -> z
               end
    assert res == c

    # tests for pure atoms
    use ExampleDUa

    c = :asd
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = :qwe in x when x > 0 -> z
                 z = :rty in x, _ when x > 0 -> z
               end
    assert res == c

    c = {:qwe, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = :qwe in x when x > 0 -> z
                 z = :rty in x, _ when x > 0 -> z
               end
    assert res == c

    c = {:rty, 1, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = :qwe in x when x > 0 -> z
                 z = :rty in x, _ when x > 0 -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro cases can have a pattern match for whole case expression in the tuple format for case arguments with guard present" do
    use ExampleDU

    c = Asd
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = {Qwe, x} when x > 0 -> z
                 z = {Rty, x, _} when x > 0 -> z
               end
    assert res == c

    c = {Qwe, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = {Qwe, x} when x > 0 -> z
                 z = {Rty, x, _}when x > 0  -> z
               end
    assert res == c

    c = {Rty, 1, 1}
    x = ExampleDU.from! c
    res = ExampleDU.case x do
                 z = Asd -> z
                 z = {Qwe, x} when x > 0 -> z
                 z = {Rty, x, _} when x > 0 -> z
               end
    assert res == c

    # tests for pure atoms
    use ExampleDUa

    c = :asd
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = {:qwe, x} when x > 0 -> z
                 z = {:rty, x, _} when x > 0 -> z
               end
    assert res == c

    c = {:qwe, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = {:qwe, x} when x > 0 -> z
                 z = {:rty, x, _}when x > 0  -> z
               end
    assert res == c

    c = {:rty, 1, 1}
    x = ExampleDUa.from! c
    res = ExampleDUa.case x do
                 z = :asd -> z
                 z = {:qwe, x} when x > 0 -> z
                 z = {:rty, x, _} when x > 0 -> z
               end
    assert res == c
  end

  test "discriminated union's `case` macro should riase on unknow tags and cases" do
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDU
                        x = struct ExampleDU, case: Qqq
                        ExampleDU.case x do
                                 Qwe -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :qqq
                        ExampleDUa.case x do
                                 :qwe -> :ok
                               end
      end)
    end
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDU
                        x = struct ExampleDU, case: Qqq
                        ExampleDU.case x do
                                 Wat -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :qqq
                        ExampleDUa.case x do
                                 :wat -> :ok
                               end
      end)
    end
  end

  test "discriminated union's `case` macro should riase on unknow tags and cases even whet `allow_underscore` is true" do
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDU
                        x = struct ExampleDU, case: Qqq
                        ExampleDU.case x, allow_underscore: true do
                                 Qwe -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :qqq
                        ExampleDUa.case x, allow_underscore: true do
                                 :qwe -> :ok
                               end
      end)
    end
    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDU
                        x = struct ExampleDU, case: Qqq
                        ExampleDU.case x, allow_underscore: true do
                                 Wat -> :ok
                               end
      end)
    end

    assert_raise UndefinedUnionCaseError, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :qqq
                        ExampleDUa.case x, allow_underscore: true do
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
                        use ExampleDU
                        x = struct ExampleDU, case: Asd
                        ExampleDU.case x do
                                 Asd -> :asd
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdu_msg, fn ->
      Code.eval_quoted(quote do
                        use ExampleDU
                        x = struct ExampleDU, case: Asd
                        ExampleDU.case x do
                                 Asd -> :asd
                                 Qwe in 1 -> :qwe
                                 Qwe in x when x > 1 -> :qwe
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :asd
                        ExampleDUa.case x do
                                 :asd -> :asd
                                 :qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :asd
                        ExampleDUa.case x do
                                 :asd -> :asd
                                 :qwe in 1 -> :qwe
                                 :qwe in x when x > 2 -> :qwe
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
                        use ExampleDU
                        x = struct ExampleDU, case: Asd
                        ExampleDU.case x, allow_underscore: true do
                                 Asd -> :asd
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdu_msg, fn ->
      Code.eval_quoted(quote do
                        use ExampleDU
                        x = struct ExampleDU, case: Asd
                        ExampleDU.case x, allow_underscore: true do
                                 Asd -> :asd
                                 Qwe in 1 -> :qwe
                                 Qwe in x when x > 1 -> :qwe
                                 Qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :asd
                        ExampleDUa.case x, allow_underscore: true do
                                 :asd -> :asd
                                 :qwe in _ -> :qwe
                               end
      end)
    end
    assert_raise MissingUnionCaseError, testdua_msg, fn ->
      Code.eval_quoted(quote do
                        use ExampleDUa
                        x = struct ExampleDUa, case: :asd
                        ExampleDUa.case x, allow_underscore: true do
                                 :asd -> :asd
                                 :qwe in 1 -> :qwe
                                 :qwe in x when x > 2 -> :qwe
                                 :qwe in _ -> :qwe
                               end
      end)
    end
  end
end
