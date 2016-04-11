defmodule DiscUnion do

  defmacro __using__(opts) do
    if true==Keyword.get opts, :constructors do
      Module.put_attribute(__CALLER__.module, :constructors, true)
    end

    quote do
      require DiscUnion
      import DiscUnion, only: [defunion: 1]
    end
  end

  defmacro defunion(expr) do
    # IO.inspect expr
    cases = unpipe(expr)
    # IO.puts cases |> Macro.to_string
    # IO.inspect Macro.to_string expr

    Module.register_attribute __CALLER__.module, :cases_canonical, persist: true
    Module.put_attribute(__CALLER__.module,
                         :cases_canonical,
                         cases |> Enum.map(&canonical_form_of_case/1))

    case is_cases_valid cases do
      {:error, :not_atoms} -> raise ArgumentError, "union case tag must be an atom"
      {:error, :not_unique} -> raise ArgumentError, "union case tag must be unique"
      :ok -> build_union cases
    end
  end

  def canonical_form_of_case(c) do
    case c do
      {:{}, _ctx, [union_tag | union_args]} ->
        str_case = [union_tag | union_args]
        |> Enum.map(&Macro.to_string/1)
        |> List.to_tuple
        {union_tag |> canonical_union_tag, union_args |> length, str_case}
      {union_tag, union_arg}              ->
        str_case = [union_tag, union_arg]
        |> Enum.map(&Macro.to_string/1)
        |> List.to_tuple
        {union_tag |> canonical_union_tag, 1, str_case}
      union_tag                             -> {union_tag |> canonical_union_tag, 0, c |> Macro.to_string}
    end
  end
  defp canonical_union_tag({:__aliases__, _, union_tag}), do: {:__aliases__, union_tag}
  defp canonical_union_tag(union_tag), do: union_tag

  def build_union(cases) do
    # quote location: :keep, bind_quoted: [all_cases: cases] do
    quote location: :keep, unquote: true do
      all_cases=unquote(cases)

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
        mod = __MODULE__
        block = block
        |> DiscUnion.transform_case_clauses(@cases_canonical)

        IO.puts "################################"
        IO.inspect expr
        block |> Macro.to_string |> IO.inspect
        IO.puts "################################%"

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
    {clauses, acc} = clauses
    |> Enum.map_reduce([], fn {:->, ctx, [clause | clause_body]}, acc ->
      # IO.puts "\n\ntransformed"
      # IO.puts "\tfrom: #{inspect clause |> Macro.to_string}"
      # transformed_clause = transform_case_clause(clause, all_cases)
      {transformed_clause, _acc} = clause
      |> DiscUnion.Util.Case.map_reduce_clauses(&transform_case_clause/2, [])

      transformed_clause |> DiscUnion.Util.Case.map_reduce_clauses(&check_for_unknown_case_clauses/2, {ctx, all_cases})
      {_, acc}=transformed_clause |> check_for_missing_case_clauses(acc)

      # IO.puts "\t  to: #{inspect transformed_clause |> Macro.to_string}"
      {{:->, ctx, [ transformed_clause | clause_body]}, acc}
    end)

    if (length all_cases) > (length acc) do
      IO.inspect all_cases
      cases = all_cases
      |> Enum.map(&elem(&1, 2))
      cases |> IO.inspect
      raise MissingUnionCaseError, cases: cases
    end

    clauses
  end

  defp transform_case_clause([{:in, ctx, [union_tag | [union_arg] ]} | rest_of_union_args], acc) do
    elems = [union_tag, union_arg | rest_of_union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause([{union_tag={_, ctx, _}, union_args}], acc) do
    elems = [union_tag, union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause([{:{}, ctx, [union_tag | union_args] }], acc) do
    elems = [union_tag | union_args]
    {[{:{}, ctx, elems}], acc}
  end
  defp transform_case_clause(c, acc) do
    {c, acc}
  end

  defp check_for_unknown_case_clauses([c], acc={ctx, all_cases}) do
    if c |> canonical_form_of_case |> is_case_clause_known(all_cases) do
      :ok
    else
      try do
        raise "oops"
      rescue
        exception ->
          line = ctx |> Keyword.get(:line, nil)
          stacktrace = System.stacktrace
          if Exception.message(exception) == "oops" do
            stacktrace = stacktrace |> Enum.drop(7)
            {_, union_args_count, str_form} = c |> canonical_form_of_case
            union_tag = case str_form do
                          x when is_tuple(x) -> x |> elem(0)
                          x  -> x
                        end
            reraise UndefinedUnionCaseError, [case: union_tag, case_args_count: union_args_count, line: line], stacktrace
          end
      end
    end

    {[c], acc}
  end

  defp is_case_clause_known(canonical_union_tag, all_cases) do
    {canonical_union_tag, canonical_union_args_count, _} = canonical_union_tag
    IO.puts "is_case: #{inspect canonical_union_tag} #{inspect all_cases}"
    all_cases |> Enum.any?(fn {tag, args_count, _} ->
      {canonical_union_tag, canonical_union_args_count} == {tag, args_count}
    end)
  end

  defp check_for_missing_case_clauses([c], used_cases) do
    cc=c |> canonical_form_of_case
    unless cc in used_cases do
      used_cases = [cc | used_cases]
    end

    {[c], used_cases}
  end

  defmacro build_from_functions(mod, cases) do
    quote bind_quoted: [cases: cases, mod: mod] do
      cases
      |> DiscUnion.build_match_ast
      |> Enum.each(fn c ->
        def from!( x=unquote(c) ) do
          # check if case is known (including number of arguments)
          %__MODULE__{case: x}
        end
        def from!( x=unquote(c), _) do
          %__MODULE__{case: x}
        end
      end)

      defmacro from(c) do
        case [c] |> DiscUnion.is_only_atoms do
          true ->
            {c, _}=Code.eval_quoted c
            from!(c) |> Macro.escape
          false ->
            c |> Macro.to_string |> from!
        end
      end

      def from!(_, ret), do: ret
      def from!(c) do
        try do
          raise "oops"
        rescue
          exception ->
            stacktrace = System.stacktrace
            if Exception.message(exception) == "oops" do
              # IO.inspect stacktrace
              stacktrace = stacktrace |> Enum.drop(1)
              # {union_tag, union_args_count, _} = c |> DiscUnion.canonical_form_of_case
              {_, union_args_count, str_form} = c |> DiscUnion.canonical_form_of_case
              union_tag = case str_form do
                            x when is_tuple(x) -> x |> elem(0)
                            x  -> x
                          end
              reraise UndefinedUnionCaseError, [case: union_tag, case_args_count: union_args_count], stacktrace
            end
        end
      end

      cases
      |> Enum.map(fn
        x when is_atom x ->
          {x, 0}
        x when is_tuple(x) and x |> elem(0) |> is_atom ->
          {x |> elem(0), tuple_size(x)-1 }
      end)
      |> Enum.map(fn {c, count} ->
        case c |> to_string do
          "Elixir." <> m ->
            c={:__aliases__,  [], [m |> String.to_atom]} |> Macro.escape
            {m |> Macro.underscore |> String.to_atom, c, count}
          _ ->
            {c |> to_string |> Macro.underscore |> String.to_atom, c, count}
        end
      end)
      |> Enum.map(fn            # HACK: too many quotes and unquotes. only solutions I could up to combine quoted and unquoted expression
        {c, orig_c, 0} ->
          defmacro unquote(c)() do
            # from!(unquote(orig_c))
            # |> Macro.expand(__ENV__)
            # |> Macro.escape
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: unquote(orig_c)]}]}
          end

        {c, orig_c, count} ->
          args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))
          defmacro unquote(c)(unquote_splicing(args)) do
            tuple = {:{}, [], [unquote(orig_c)  | unquote(args)]}
            # __MODULE__.from!(tuple)
            # |> Macro.expand(__ENV__)
            # |> Macro.escape
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
          end
      end)
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
        cs = cs |> Enum.map(fn _ ->
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

  def is_only_atoms(cases) do
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

  # TODO: check why guards in is_only_atoms and is_unique are different!
  defp is_unique(cases) do
    unique_cases = cases
    |> Enum.map(
                fn
                  {:__aliases__, _, [x|_]} when is_atom x                                    -> x
                  {:{}, _, [{:__aliases__, _, [x|_]}|_]} when is_atom x                      -> x
                  {:{}, _, [x|_]} when is_atom x                                             -> x
                  {{:__aliases__, _, [x|_]}, _} when is_tuple(x) and x |> elem(0) |> is_atom -> x |> elem(0)
                  {x, _} when is_tuple(x) and x |> elem(0) |> is_atom                        -> x |> elem(0)
                  x when is_atom x                                                           -> x
                end)
    |> Enum.uniq

    length(cases) == length(unique_cases)
  end

end
