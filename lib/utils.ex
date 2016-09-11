defmodule DiscUnion.Utils do
  @moduledoc false

  @spec canonical_form_of_union_case(Macro.expr) :: {DiscUnion.canonical_union_tag, non_neg_integer, any}
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

  @spec canonical_union_tag(Macro.expr) :: DiscUnion.canonical_union_tag
  defp canonical_union_tag({:_, _, _}), do: {:_, 0}
  defp canonical_union_tag({:__aliases__, _, union_tag}), do: {:__aliases__, union_tag}
  defp canonical_union_tag(union_tag), do: union_tag

  @spec extract_union_case_definitions(Macro.expr) :: [Macro.t]
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

  @spec unstar(Macro.expr) :: [Macro.t]
  defp unstar(expr) do
    unstar(expr, []) |> Enum.reverse
  end
  defp unstar({:*, _, [left, right]}, acc) do
    unstar(right, unstar(left, acc))
  end
  defp unstar(other, acc) do
    [other |> Macro.to_string | acc]
  end

  @spec is_cases_valid?([Macro.expr]) :: :ok | {:error, :not_atoms} | {:error, :not_unique}
  def is_cases_valid?(cases) do
    cond do
      not is_only_atoms? cases -> {:error, :not_atoms}
      not is_unique? cases -> {:error, :not_unique}
      true -> :ok
    end
  end

  @spec is_only_atoms?([Macro.expr]) :: boolean
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

  @spec is_unique?([Macro.expr]) :: boolean
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

  @spec module_name(atom) :: String.t
  def module_name(module) do
    case module |> to_string do
      "Elixir." <> m -> m
      m              -> m
    end
  end

  @spec build_union_case_spec(Macro.t) :: Macro.t
  def build_union_case_spec(variant_case) do
    canonical_case =
      variant_case
      |> DiscUnion.Utils.canonical_form_of_union_case

    case canonical_case do
      {_tag, _count, str} when  is_tuple(str) ->
        tuple_elems =
          str
          |> Tuple.to_list
          |> Enum.map(& String.replace(&1, "\"", "") )
          |> Enum.map(fn e -> Code.eval_string("quote do #{e} end", [], __ENV__) |> elem(0) end)
        quote do {unquote_splicing(tuple_elems)} end
      {_tag, _count, str} ->
        str
        |> Code.eval_string([], __ENV__)
        |> elem(0)
    end
  end

  @spec build_union_cases_specs(Macro.t) :: Macro.t
  def build_union_cases_specs(cases) do
    specs = cases
    |> Enum.map(&build_union_case_spec/1)
    |> Enum.reverse
    |> Enum.reduce(fn e, acc ->
        quote do unquote(e) | unquote(acc) end
    end)
    quote do
      @type t() :: %__MODULE__{case: unquote(specs)}
    end
  end
end
