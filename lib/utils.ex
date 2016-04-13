defmodule DiscUnion.Utils do
  def canonical_form_of_union_case(c) do
    case c do
      {:{}, _ctx, [union_tag | union_args]} ->
        str_case = [union_tag | union_args]
        |> Enum.map(&Macro.to_string/1)
        |> List.to_tuple
        {union_tag |> canonical_union_tag, union_args |> length, str_case}
      {union_tag, union_arg} ->
        str_case = [union_tag, union_arg]
        |> Enum.map(&Macro.to_string/1)
        |> List.to_tuple
        {union_tag |> canonical_union_tag, 1, str_case}
      union_tag ->
        {union_tag |> canonical_union_tag, 0, c |> Macro.to_string}
    end
  end

  defp canonical_union_tag({:_, _, _}), do: {:_, 0}
  defp canonical_union_tag({:__aliases__, _, union_tag}), do: {:__aliases__, union_tag}
  defp canonical_union_tag(union_tag), do: union_tag

  def extract_union_case_definitions(x) do
    extract_union_case_definitions(x, []) |> Enum.reverse
  end
  def extract_union_case_definitions({:in, _, [left, right]}, acc) do
    vars = right |> unstar

    [ {:{}, [], [left | vars]} | acc]
  end
  def extract_union_case_definitions({:|, _, [left, right]}, acc) do
    extract_union_case_definitions(right, extract_union_case_definitions(left, acc) )
  end
  def extract_union_case_definitions(other, acc) do
    [other | acc]
  end

  defp unstar(expr) do
    unstar(expr, []) |> Enum.reverse
  end
  defp unstar({:*, _, [left, right]}, acc) do
    unstar(right, unstar(left, acc))
  end
  defp unstar(other, acc) do
    [other |> Macro.to_string | acc]
  end


  def is_cases_valid?(cases) do
    cond do
      not is_only_atoms? cases -> {:error, :not_atoms}
      not is_unique? cases -> {:error, :not_unique}
      true -> :ok
    end
  end

  def is_only_atoms?(cases) do
    cases
    |> Enum.all?(
                 fn
                   {:__aliases__, _, [x|_]} when is_atom x               -> true
                   {:{}, _, [{:__aliases__, _, [x|_]}|_]} when is_atom x -> true
                   {:{}, _, [x|_]} when is_atom x                        -> true
                   {{:__aliases__, _, [x|_]}, _} when is_atom x          -> true
                   {x, _} when is_atom x                                 -> true
                   x when is_atom x                                      -> true
                   _                                                     -> false
                 end
    )
  end

  def is_unique?(cases) do
    unique_cases = cases
    |> Enum.map(
                fn
                  {:__aliases__, _, [x|_]} when is_atom x                                    -> x
                  {:{}, _, [{:__aliases__, _, [x|_]}|_]} when is_atom x                      -> x
                  {:{}, _, [x|_]} when is_atom x                                             -> x
                  {{:__aliases__, _, [x|_]}, _} when is_tuple(x) and x |> elem(0) |> is_atom -> x |> elem(0)
                  {x, _} when is_atom x                                                      -> x # not really needed,
                    # after transormation of cases, 2-tuples are converted in to n-tuples with two elemtns (in AST terms)
                    # it's here just for symmetry with `is_only_atoms?/1`, which needs it, cause it's used in one other
                    # place also.
                  x when is_atom x                                                           -> x
                end)
    |> Enum.uniq

    length(cases) == length(unique_cases)
  end

  @doc """
  Builds AST for matching a case.
  When is a single atom, AST looks the same. For tuples, first argument (union tag) is saved, but rest is replaced
  with underscore `_` to match anything.
  """
  def build_match_ast(cases) do
    # cases=cases |> Macro.escape
    # cases |> IO.inspect
    cases
    |> Enum.map(&Macro.escape/1)
    |> Enum.map(fn
      x when is_atom(x) ->
        x
      {op, ctx, [c | cs]} when op in [:{}, :__aliases__] and is_atom(c) ->
        cs = cs |> Enum.map(fn _ ->
        quote do: _
      end)
      {:{}, ctx, [c |cs]}
      {c, _} when c |> is_atom -> # 2-tuple
        cs = [quote do: _]
      {:{}, [], [c | cs ]}
    end)
  end
end
