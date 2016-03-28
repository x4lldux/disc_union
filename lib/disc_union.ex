defmodule UndefinedUnionCaseError do
  defexception [case: nil, case_args_count: 0, line: 0]

  def message(exception=%{case_args_count: 0}) do
    "undefined union case: #{inspect(exception.case)} at line #{exception.line}"
  end
  def message(exception) do
    case_args = 0..exception.case_args_count-1
    |> Enum.map(fn _ -> "_" end)
    |> Enum.join(" * ")
    "undefined union case: #{inspect(exception.case)} in #{case_args} at line #{exception.line}"
  end
end

defmodule MissingUnionCaseError do
  defexception [cases: nil, line: 0]

  defp format_case(c) when is_atom(c) do
    inspect c
  end
  defp format_case(c) when is_tuple(c) do
    [tag | args] = c
    |> Tuple.to_list

    args = args |> Enum.join(" * ")
    "#{inspect tag} in #{args}"
  end
  def message(exception) do
    cases = exception.cases
    |> Enum.map(&format_case/1)
    |> Enum.join(", ")
    "not all defined union cases are used, should be all of: #{inspect(exception.cases)}"
  end
end


defmodule DiscUnion do

  defmacro defunion(expr) do
    # IO.inspect expr
    cases = unpipe(expr)
    IO.puts cases |> Macro.to_string
    # IO.inspect Macro.to_string expr

    case is_cases_valid cases do
      {:error, :not_atoms} -> raise ArgumentError, "union case tag must be an atom"
      {:error, :not_unique} -> raise ArgumentError, "union case tag must be unique"
      :ok -> build_union cases
    end
  end

  defp build_union(cases) do
    quote location: :keep, bind_quoted: [all_cases: cases] do
      defstruct case: [], cases: all_cases

      defimpl Inspect do
        import Inspect.Algebra

        def inspect(union, opts) do
          mod=@for |> Module.split
          concat ["##{mod}<", Inspect.inspect(union.case, opts), ">"]
        end
      end

      # accept only %__MODULE__{}
      # check if cases are known (including number of arguments)
      # when no gaurd* is used, check if all union cases are exhausted or _ is used
      # if not, err "not all union cases are covered"
      # if _ is used, warn "fallback (_) is used instead of covering every union case separatly"
      # when gaurd* is used, check if _ is used
      # if not, err "you're using gaurds - can't trace if all paths are covered, fallback (_) is needed"
      # * guard means `when` gaurd or a binding
      defmacro case(expr, do: block) do
                 # IO.inspect expr
                 # IO.inspect block

                 mod = __MODULE__
                 block = block
                 |> DiscUnion.transform_case_clauses(%__MODULE__{}.cases)

                 block |> Macro.to_string |> IO.inspect

                 quote location: :keep do
                   precond = unquote expr
                   mod = unquote mod
                   if not match?(%{__struct__: mod}, precond) do
                     raise BadStructError, struct: mod, term: precond
                   end
                   case precond.case do
                                  unquote(block)
                                end
                 end
               end

      DiscUnion.build_from_functions __MODULE__, all_cases
    end
  end

  def transform_case_clauses(clauses, all_cases) do
    clauses
    |> Enum.map(fn {:->, ctx, [clause | clause_body]}->
      IO.puts "\n\ntransformed"
      IO.puts "\tfrom: #{inspect clause |> Macro.to_string}"
      transformed_clause = transform_case_clause(clause, all_cases)
      # IO.puts "\t  to: #{inspect transformed_clause |> Macro.to_string}"
      {:->, ctx, [ transformed_clause | clause_body]}
    end)
  end

  defp transform_case_clause([{:=, ctx, [ bind, precond ]} | rest_of_union_args], all_cases) do
    # IO.puts "bind: #{inspect bind}"
    # IO.puts "bind: #{bind |> Macro.to_string}"

    precond = [precond | rest_of_union_args]
    |> transform_case_clause(all_cases)
    |> hd

    # IO.puts "bind_out: #{inspect bind}"
    # IO.puts "bind_out: #{bind |> Macro.to_string}"

    [{:=, ctx, [ bind, precond ]}]
  end

  defp transform_case_clause([{:when, ctx, [ precond | guards_and_union_args ]}], all_cases) do
    IO.puts "precond: #{inspect precond}"
    IO.puts "precond: #{precond |> Macro.to_string}"

    guard = guards_and_union_args |> List.last
    union_arg = guards_and_union_args |> List.delete_at(-1)

    precond = [precond | union_arg]
    |> transform_case_clause(all_cases)
    |> hd

    # IO.puts "precond_out: #{inspect precond}"
    # IO.puts "precond_out: #{precond |> Macro.to_string}"

    [{:when, ctx, [ precond, guard ]}]
  end

  defp transform_case_clause([{:in, ctx, [union_tag | [union_arg] ]} | rest_of_union_args], all_cases) do
    IO.puts ":in: #{inspect union_tag}"
    IO.puts ":in: #{inspect union_tag |> Macro.to_string}"
    elems = [union_tag, union_arg | rest_of_union_args]
    IO.puts ":in: #{inspect elems}"
    IO.puts ":in: #{inspect elems |> Macro.to_string}"

    line = ctx |> Keyword.get(:line, nil)
    rais_if_clause_valid(union_tag, (elems|>length)-1, line, all_cases)


    [{:{}, ctx, elems}]
    # [{:in, ctx, tuple_form }]p
  end

  defp transform_case_clause([{union_tag={_, ctx, _}, union_args}], all_cases) do
    IO.puts ":in: #{inspect union_tag}"
    IO.puts ":in: #{inspect union_tag |> Macro.to_string}"
    elems = [union_tag, union_args]
    IO.puts ":in: #{inspect elems}"
    IO.puts ":in: #{inspect elems |> Macro.to_string}"

    line = ctx |> Keyword.get(:line, nil)
    rais_if_clause_valid(union_tag, (elems|>length)-1, line, all_cases)


    [{:{}, ctx, elems}]
    # [{:in, ctx, tuple_form }]p
  end

  defp transform_case_clause([{:{}, ctx, [union_tag | union_args] }], all_cases) do
    IO.puts ":in: #{inspect union_tag}"
    IO.puts ":in: #{inspect union_tag |> Macro.to_string}"
    elems = [union_tag | union_args]
    IO.puts ":in: #{inspect elems}"
    IO.puts ":in: #{inspect elems |> Macro.to_string}"

    line = ctx |> Keyword.get(:line, nil)
    rais_if_clause_valid(union_tag, (elems|>length)-1, line, all_cases)


    [{:{}, ctx, elems}]
    # [{:in, ctx, tuple_form }]p
  end

  # TUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU
  defp transform_case_clause(c, all_cases) do
    # IO.puts "fallback: #{inspect all_cases |> DiscUnion.build_match_ast |> List.last |> Macro.escape }"
    IO.puts "fallback: #{inspect c}"
    # IO.puts "fallback: #{inspect c |> hd |> Macro.escape}"
    all_cases |> DiscUnion.build_match_ast |> List.last |> Macro.escape
    c
  end

  defp rais_if_clause_valid(union_tag, union_args_count, line, all_cases) do
    {evaled_case_tag, _} = Code.eval_quoted(union_tag)
    if is_case_clause_valid(evaled_case_tag, union_args_count, all_cases) do
      :ok
    else
      try do
        raise "oops"
      rescue
        exception ->
          stacktrace = System.stacktrace
        if Exception.message(exception) == "oops" do
          IO.inspect stacktrace
          stacktrace = stacktrace |> Enum.drop(6)
          reraise UndefinedUnionCaseError, [case: evaled_case_tag, case_args_count: union_args_count, line: line], stacktrace
        end
      end
    end
  end
  defp is_case_clause_valid(union_tag, union_args_count, all_cases) do
    IO.puts "is_case: #{inspect union_tag} #{inspect union_args_count} #{inspect all_cases}"
    all_cases
    |> Enum.any?(
      fn c when is_atom(c)  -> c==union_tag && 0==union_args_count
      c when is_tuple(c) -> elem(c, 0)==union_tag && tuple_size(c)==union_args_count+1
      _ -> false
    end)
  end

  defmacro build_from_functions(mod, cases) do
    quote bind_quoted: [cases: cases, mod: mod] do
      def from(_case, _ret \\ nil)

      cases
      |> DiscUnion.build_match_ast
      |> Enum.each(fn c ->
      def from!( x=unquote(c) ) do
        # check if case is known (including number of arguments)
        # return %__MODULE__{case: potential_case}

        %__MODULE__{case: x}
      end

        def from(x=unquote(c), _) do
          from! x
        end
      end)

      def from(_case, ret), do: ret
    end
  end

  def build_match_ast(cases) do
    # cases=cases |> Macro.escape
    # cases |> IO.inspect
    cases
    |> Enum.map(&Macro.escape/1)
    |> Enum.map(fn
      x when is_atom(x) ->
        x
      {op, ctx, [c | cs]} when op in [:{}, :__aliases__] and is_atom(c) ->
        cs = cs
      |> Enum.map(fn _ ->
        quote do: _
      end)
      {:{}, ctx, [c |cs]}
      {c, _} when c |> is_atom -> # 2-tuple
        cs = [quote do: _]
      {:{}, [], [c | cs ]}
    end)
  end

  def unpipe(x) do
    unpipe(x, []) |> Enum.reverse
  end
  def unpipe({:in, _, [left, right]}, acc) do
    vars = right |> unstar

    [ {:{}, [], [left | vars]} | acc]
  end
  def unpipe({:|, _, [left, right]}, acc) do
    unpipe(right, unpipe(left, acc) )
  end
  def unpipe(other, acc) do
    [other | acc]
  end

  def unstar(expr) do
    unstar(expr, []) |> Enum.reverse
  end
  def unstar({:*, _, [left, right]}, acc) do
    unstar(right, unstar(left, acc))
  end
  def unstar(other, acc) do
    [other |> Macro.to_string | acc]
  end

  defp is_cases_valid(cases) do
    cond do
      not is_only_atoms cases -> {:error, :not_atoms}
      not is_unique cases -> {:error, :not_unique}
      true -> :ok
    end
  end

  defp is_only_atoms(cases) do
    # cases |> Enum.each(&IO.inspect/1)
    cases
    |> Enum.all?(
                 fn
                   {:__aliases__, _, [x|_]} when is_atom x -> true
                 {:{}, _, [x|_]} when is_atom x          -> true
                 x when is_tuple x and x |> elem(0) |> is_atom -> true
                 x when is_atom x                        -> true
                 _                                       -> false
                 end
    )
  end

  defp is_unique(cases) do
    unique_cases = cases
    |> Enum.map(
                fn
                  {:__aliases__, _, [x|_]} when is_atom x -> x
                  {:{}, _, [{:__aliases__, _, [x|_]}|_]} when is_atom x -> x
                  {:{}, _, [x|_]} when is_atom x          -> x
                  {{:__aliases__, _, [x|_]}, _} when is_tuple x and x |> elem(0) |> is_atom -> x |> elem(0)
                  {x, _} when is_tuple x and x |> elem(0) |> is_atom -> x |> elem(0)
                  x when is_atom x                        -> x
                end)
    |> Enum.uniq

    length(cases) == length(unique_cases)
  end

end


# defmodule Asd do
#   require DiscUnion

#   DiscUnion.defunion :aasd | :zxc in integer()*String.t | :qwe | :x
# end

defmodule Maybe do
  require DiscUnion

  DiscUnion.defunion Nothing
  | Just in any*any

  # DiscUnion.defunion :Nothing | :Just in any
end

defmodule Test do
  require Maybe

  def test do
    x=Maybe.from {Just, 2}
    Maybe.case x do
            Nothing -> :buu
            :Nothing -> :buu
            z=Nothing -> :buu
            # Just in 2 -> :ined
            # Just in 2, 2 -> :ined
#            z=Just in x -> :ined_when
#            z=Just in x when x<2 and x>0 -> :ined_when
            z=Just in x, x -> :ined_when
            z=Just in x, x when x<2 and x>0 -> :ined_when
            # {Just, x} when x<2 and x>0 -> :tupled_when
            # {Just, x} -> :tupled
            # {Just, x, x} -> :tupled
#            z={Just, x} when x<2 and x>0 -> :tupled
            z={Just, x, x} -> :tupled
            z={Just, x, x} when x<2 and x>0 -> :tupled_when
          end
  end
end

# [{:__aliases__, [counter: 0, line: 103], [:Nothing]}]
# [{{:__aliases__, [counter: 0, line: 104], [:Just]}, {:x, [line: 104], nil}}]
# [{:in, [line: 105], [{:__aliases__, [counter: 0, line: 105], [:Just]}, 2]}]
# [{:in, [line: 106], [{:__aliases__, [counter: 0, line: 106], [:Just]}, 2]}, 2]
# [{:when, [line: 107],
#   [{:in, [line: 107], [{:__aliases__, [counter: 0, line: 107], [:Just]}, 2]},
#    {:<, [line: 107], [{:x, [line: 107], nil}, 2]}]}]
# [{:when, [line: 108],
#   [{:in, [line: 108], [{:__aliases__, [counter: 0, line: 108], [:Just]}, 2]}, 2,
#    {:<, [line: 108], [{:x, [line: 108], nil}, 2]}]}]
# [{:when, [line: 109],
#   [{{:__aliases__, [counter: 0, line: 109], [:Just]}, {:x, [line: 109], nil}},
#    {:<, [line: 109], [{:x, [line: 109], nil}, 2]}]}]

# [{:when, [line: 233],
#   [{:in, [line: 233], [{:__aliases__, [counter: 0, line: 233], [:Just]}, 2]},
#    {:and, [line: 233],
#     [{:<, [line: 233], [{:x, [line: 233], nil}, 2]},
#      {:>, [line: 233], [{:x, [line: 233], nil}, 0]}]}]}]
# "[Just in 2 when x < 2 and x > 0]"

# [{:when, [line: 234],
#   [{:in, [line: 234], [{:__aliases__, [counter: 0, line: 234], [:Just]}, 2]}, 2,
#    {:and, [line: 234],
#     [{:<, [line: 234], [{:x, [line: 234], nil}, 2]},
#      {:>, [line: 234], [{:x, [line: 234], nil}, 0]}]}]}]
# "[(Just in 2, 2) when x < 2 and x > 0]"

# [{:when, [line: 235],
#   [{{:__aliases__, [counter: 0, line: 235], [:Just]}, {:x, [line: 235], nil}},
#    {:and, [line: 235],
#     [{:<, [line: 235], [{:x, [line: 235], nil}, 2]},
#      {:>, [line: 235], [{:x, [line: 235], nil}, 0]}]}]}]
# "[{Just, x} when x < 2 and x > 0]"

# [{:=, [line: 239],
#   [{:z, [line: 239], nil},
#    {:{}, [line: 239], [{:__aliases__, [counter: 0, line: 239], [:Just]}, {:x, [line: 239], nil}, {:x, [line: 239], nil}]}
#   ]}]
