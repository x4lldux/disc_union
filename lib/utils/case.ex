defmodule DiscUnion.Utils.Case do

  @spec map_reduce_clauses(DiscUnion.case_clauses, (list(Macro.expr), any -> {Macro.expr, any}), any) :: {DiscUnion.case_clauses, any}
  def map_reduce_clauses(clauses, f, acc) do
    {clauses, {_, acc}} = clauses |> map_reduce_clause({f, acc})
    {clauses, acc}
  end

  defp map_reduce_clause([{:=, ctx, [ bind, precond ]} | rest_of_union_args], {f, acc}) do
    {[precond|_], f_acc} = [precond | rest_of_union_args]
    |> map_reduce_clause({f, acc})

    {[{:=, ctx, [ bind, precond ]}], f_acc}
  end

  defp map_reduce_clause([{:when, ctx, [ precond | guards_and_union_args ]}], {f, acc}) do
    guard = guards_and_union_args |> List.last
    union_arg = guards_and_union_args |> List.delete_at(-1)

    {[precond|_], f_acc} = [precond | union_arg]
    |> map_reduce_clause({f, acc})

    {[{:when, ctx, [ precond, guard ]}], f_acc}
  end

  defp map_reduce_clause(elem, {f, acc}) do
    {new_elem, f_acc}=f.(elem, acc)
    {new_elem, {f, f_acc}}
  end


  def raise_undefined_union_case(c, at: when?) do
    try do
      raise "oops"
    rescue
      exception ->
        stacktrace = System.stacktrace
        if Exception.message(exception) == "oops" do

          case when? do
            :runtime     ->
              stacktrace = stacktrace |> Enum.drop(2)
            :compiletime ->
              stacktrace = stacktrace
              |> Enum.drop_while(
                fn {_, _, _, o} ->
                  Keyword.get(o, :file)
                  |> to_string
                  |> String.contains?(__ENV__.file |> Path.basename)
                end)
              |> Enum.drop(1)
          end

          {_, union_args_count, str_form} = c |> DiscUnion.Utils.canonical_form_of_union_case
          union_tag = case str_form do
                        x when is_tuple(x) -> x |> elem(0)
                        x  -> x
                      end
          reraise UndefinedUnionCaseError, [case: union_tag, case_args_count: union_args_count], stacktrace
        end
    end
  end

  def raise_missing_union_case(all_cases) do
    try do
      raise "oops"
    rescue
      exception ->
        stacktrace = System.stacktrace
        if Exception.message(exception) == "oops" do
          stacktrace = stacktrace
          |> Enum.drop_while(
            fn {_, _, _, o} ->
              Keyword.get(o, :file)
              |> to_string
              |> String.contains?(__ENV__.file |> Path.basename)
            end)
          cases = all_cases |> Enum.map(&elem(&1, 2))
          reraise MissingUnionCaseError, [cases: cases], stacktrace
        end
    end
  end
end
