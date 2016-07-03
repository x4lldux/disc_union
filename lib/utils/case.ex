defmodule DiscUnion.Utils.Case do
  @moduledoc false

  @type case_clause :: {:->, [{atom, any}], [any]}
  @type case_clauses :: [case_clause]

  @spec transform_case_clauses(case_clauses, term, boolean) :: case_clauses
  def transform_case_clauses(clauses, all_union_cases, allow_underscore) do
    underscore_canonical_case = Macro.var(:_, nil) |> DiscUnion.Utils.canonical_form_of_union_case
    underscore_semicanonical_case = cond do
      {a, b, _} = underscore_canonical_case -> {a, b}
    end

    all_union_cases = if allow_underscore == true do
      all_union_cases ++ [underscore_canonical_case]
    else
      all_union_cases
    end

    {clauses, acc} = clauses
    |> Enum.map_reduce([],
      fn {:->, ctx, [clause | clause_body]}, acc ->
        {transformed_clause, _} = clause
        |> DiscUnion.Utils.Case.map_reduce_clauses(&transform_case_clause/2, [])

        _ = transformed_clause
        |> DiscUnion.Utils.Case.map_reduce_clauses(&check_for_unknown_case_clauses/2, {ctx, all_union_cases})

        {_, acc}=transformed_clause
        |> DiscUnion.Utils.Case.map_reduce_clauses(&extract_used_case_clauses/2, acc)

        {{:->, ctx, [ transformed_clause | clause_body]}, acc}
    end)

    if (length all_union_cases) > (length acc) && not underscore_semicanonical_case in acc do
      DiscUnion.Utils.Case.raise_missing_union_case all_union_cases
    end

    clauses
  end

  # transforms case macro clauses to a common format, if they are in `in` format or they are 2-tuples
  defp transform_case_clause([{:in, ctx, [union_tag | [union_arg] ]} | rest_of_union_args], acc) do
    elems = [union_tag, union_arg | rest_of_union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause([{union_tag={_, ctx, _}, union_args}], acc) do
    elems = [union_tag, union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause(c, acc) do
    {c, acc}
  end

  @spec check_for_unknown_case_clauses(Macro.t, any) :: {Macro.t, any}
  defp check_for_unknown_case_clauses([c], acc={_ctx, all_cases}) do
    known? = c
    |> DiscUnion.Utils.canonical_form_of_union_case
    |> is_case_clause_known?(all_cases)
    if known? do
      :ok
    else
      DiscUnion.Utils.Case.raise_undefined_union_case(c, at: :compiletime)
    end

    {[c], acc}
  end

  defp is_case_clause_known?(canonical_union, all_cases) do
    {canonical_union_tag, canonical_union_args_count, _} = canonical_union
    all_cases |> Enum.any?(fn {tag, args_count, _} ->
      {canonical_union_tag, canonical_union_args_count} == {tag, args_count}
    end)
  end

  defp extract_used_case_clauses([c], used_cases) do
    {canonical_union_tag, canonical_union_args_count, _} = c |> DiscUnion.Utils.canonical_form_of_union_case
    cc={canonical_union_tag, canonical_union_args_count}
    used_cases = case cc in used_cases do
      false -> [cc | used_cases]
      true  -> used_cases
    end

    {[c], used_cases}
  end

  @spec map_reduce_clauses(DiscUnion.Utils.Case.case_clauses, (list(Macro.expr), any -> {Macro.expr, any}), any) :: {DiscUnion.Utils.Case.case_clauses, any}
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

          stacktrace = case when? do
            :runtime     ->
              stacktrace |> Enum.drop(2)
            :compiletime ->
              stacktrace
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
