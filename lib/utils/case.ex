defmodule DiscUnion.Utils.Case do
  @moduledoc false

  alias DiscUnion.Utils

  @type case_clause :: {:->, [{atom, any}], [any]}
  @type case_clauses :: [case_clause]

  defmacro raise_undefined_union_case(c, at: :runtime) do
    quote location: :keep, bind_quoted: [c: c] do
      try do
        raise "oops"
      rescue
        exception ->
          stacktrace = System.stacktrace() |> Enum.drop(1)

          {_, union_args_count, str_form} = c |> Utils.canonical_form_of_union_case
          union_tag = case str_form do
                        x when is_tuple(x) -> x |> elem(0)
                        x  -> x
                      end
          reraise UndefinedUnionCaseError, [case: union_tag, case_args_count: union_args_count], stacktrace
        end
    end
  end

  defmacro raise_undefined_union_case(c, at: :compiletime) do
    quote location: :keep, bind_quoted: [c: c] do
      try do
        raise "oops"
      rescue
        exception ->
          stacktrace = Enum.drop_while(System.stacktrace(),
            fn {_, _, _, o} ->
              file = Keyword.get(o, :file) |> to_string
              String.contains?(file, __ENV__.file |> Path.basename)
              or
              String.contains?(file, "enum.ex") # HACK: ugggh! Somebody please suggest a better way
            end)
            |> Enum.drop(1)

          {_, union_args_count, str_form} = c |> Utils.canonical_form_of_union_case
          union_tag = case str_form do
                        x when is_tuple(x) -> x |> elem(0)
                        x  -> x
                      end
          reraise UndefinedUnionCaseError, [case: union_tag, case_args_count: union_args_count], stacktrace
        end
    end
  end


  @spec raise_missing_union_case(case_clauses) :: no_return()
  def raise_missing_union_case(all_cases) do
    try do
      raise "oops"
    rescue
      exception ->
        stacktrace = System.stacktrace
        if Exception.message(exception) == "oops" do
          stacktrace = Enum.drop_while(stacktrace,
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

  @spec transform_case_clauses(case_clauses | nil, term, boolean) :: case_clauses | no_return()
  # when `:do` is empty
  def transform_case_clauses(nil, all_union_cases, _allow_underscore) do
    raise_missing_union_case all_union_cases
  end
  def transform_case_clauses(clauses, all_union_cases, allow_underscore) do
    underscore_canonical_case = Macro.var(:_, nil) |> Utils.canonical_form_of_union_case
    all_union_cases = case allow_underscore do
                        true  -> all_union_cases ++ [underscore_canonical_case]
                        false -> all_union_cases
                      end

    {clauses, simplified_used_cases} = normalize_and_simplify_used(clauses,
      all_union_cases)

    underscore_base_case_form = base_case_form underscore_canonical_case
    if (length all_union_cases) > (length simplified_used_cases) &&
      not(underscore_base_case_form in simplified_used_cases) do
      raise_missing_union_case all_union_cases
    end

    clauses
  end

  defp normalize_and_simplify_used(clauses, all_union_cases) do
    simplifier = fn {:->, ctx, [clause | clause_body]}, simplified_used_cases ->
      # normalizes format when clauses are in `in` format or are 2-tuple
      {transformed_clause, _} = map_reduce_clauses(clause, &transform_case_clause/2, [])

      # raise on unknown case clauses
      map_reduce_clauses(transformed_clause,
        &check_for_unknown_case_clauses/2,
        {ctx, all_union_cases})

      # simplified used cases for check later
      {_, simplified_used_cases} = map_reduce_clauses(transformed_clause,
        &extract_used_case_clauses/2,
        simplified_used_cases)

    {{:->, ctx, [transformed_clause | clause_body]}, simplified_used_cases}
    end

    Enum.map_reduce(clauses, [], simplifier)
  end

  # transforms case macro clauses to a common format, if they are in `in` format or they are 2-tuples
  defp transform_case_clause([{:in, ctx, [union_tag | [union_arg] ]} | rest_of_union_args], acc) do
    elems = [union_tag, union_arg | rest_of_union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause([{union_tag = {_, ctx, _}, union_args}], acc) do
    elems = [union_tag, union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause(c, acc) do
    {c, acc}
  end

  @spec check_for_unknown_case_clauses(Macro.t, any) :: {Macro.t, any}
  defp check_for_unknown_case_clauses([c], acc = {_ctx, all_cases}) do
    known? =
      c
      |> Utils.canonical_form_of_union_case
      |> is_case_clause_known?(all_cases)
    if known? do
      :ok
    else
      raise_undefined_union_case(c, at: :compiletime)
    end

    {[c], acc}
  end

  defp is_case_clause_known?(canonical_form, all_cases) do
    {canonical_union_tag, canonical_union_args_count, _} = canonical_form
    Enum.any?(all_cases, fn {tag, args_count, _} ->
      {canonical_union_tag, canonical_union_args_count} == {tag, args_count}
    end)
  end

  defp extract_used_case_clauses([c], used_cases) do
    base_case_form = base_case_form c
    used_cases = case base_case_form in used_cases do
      false -> [base_case_form | used_cases]
      true  -> used_cases
    end

    {[c], used_cases}
  end

  # case form without string representation
  defp base_case_form(c) do
    {canonical_union_tag, canonical_union_args_count, _} = Utils.canonical_form_of_union_case c
    {canonical_union_tag, canonical_union_args_count}
  end

  @spec map_reduce_clauses(case_clauses, (list(Macro.expr), any -> {Macro.expr, any}), any) :: {case_clauses, any}
  def map_reduce_clauses(clauses, f, acc) do
    {clauses, {_, acc}} = clauses |> map_reduce_clause({f, acc})
    {clauses, acc}
  end

  defp map_reduce_clause([{:=, ctx, [bind, precond]} | rest_of_union_args], {f, acc}) do
    {[precond|_], f_acc} =
      [precond | rest_of_union_args]
      |> map_reduce_clause({f, acc})

    {[{:=, ctx, [bind, precond]}], f_acc}
  end

  defp map_reduce_clause([{:when, ctx, [precond | guards_and_union_args]}], {f, acc}) do
    guard = guards_and_union_args |> List.last
    union_arg = guards_and_union_args |> List.delete_at(-1)

    {[precond|_], f_acc} =
      [precond | union_arg]
      |> map_reduce_clause({f, acc})

    {[{:when, ctx, [precond, guard]}], f_acc}
  end

  defp map_reduce_clause(elem, {f, acc}) do
    {new_elem, f_acc} = f.(elem, acc)
    {new_elem, {f, f_acc}}
  end

end
