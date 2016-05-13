defmodule DiscUnion do
  @type case_clause :: {:->, [{atom, any}], [any]}
  @type case_clauses :: [case_clause]
  @type union_tag :: {:_, 0} | {:__aliases__, atom} | atom

  defmacro __using__(opts) do
    opts = opts ++ [dyn_constructors: true]
    if true == Keyword.get opts, :dyn_constructors do
      Module.put_attribute(__CALLER__.module, :dyn_constructors, true)
    end

    quote do
      require DiscUnion
      # require __MODULE__
      import DiscUnion, only: [defunion: 1]
    end
  end

  defmacro defunion(expr) do
    cases = DiscUnion.Utils.extract_union_case_definitions(expr)

    Module.register_attribute __CALLER__.module, :cases_canonical, persist: true
    Module.put_attribute(__CALLER__.module,
                         :cases_canonical,
                         cases |> Enum.map(&DiscUnion.Utils.canonical_form_of_union_case/1))

    case DiscUnion.Utils.is_cases_valid? cases do
      {:error, :not_atoms} -> raise ArgumentError, "union case tag must be an atom"
      {:error, :not_unique} -> raise ArgumentError, "union case tag must be unique"
      :ok -> build_union cases
    end
  end

  def build_union(cases) do
    quote location: :keep, unquote: true do
      all_cases=unquote(cases)

      @opaque t :: %__MODULE__{}
      defstruct case: [], cases: all_cases

      defimpl Inspect do
        import Inspect.Algebra

        def inspect(union, opts) do
          mod=@for |> Module.split
          concat ["##{mod}<", Inspect.inspect(union.case, opts), ">"]
        end
      end

      defmacro case(expr, do: block) do
                 do_case expr, [], do: block
               end
      defmacro case(expr, [allow_underscore: true], do: block) do
                 do_case expr, [allow_underscore: true], do: block
               end
      defmacro case(expr, opts, do: block) do
                 do_case expr, [], do: block
               end

      @spec do_case(Macro.t, Keyword.t, [do: DiscUnion.case_clauses]) :: Macro.t
      defp do_case(expr, opts, do: block) do
        opts = opts ++ [allow_underscore: false]
        mod = __MODULE__
        allow_underscore = Keyword.get opts, :allow_underscore

        block = block
        |> DiscUnion.transform_case_clauses(@cases_canonical, allow_underscore)
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

      DiscUnion.build_constructor_functions __MODULE__, all_cases
    end
  end

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
    unless cc in used_cases do
      used_cases = [cc | used_cases]
    end

    {[c], used_cases}
  end

  defmacro build_constructor_functions(mod, cases) do
    quote bind_quoted: [cases: cases, mod: mod] do
      match_ast = cases
      |> DiscUnion.Utils.build_match_ast
      spec_ast = cases
      |> DiscUnion.Utils.build_spec_ast

      Enum.zip(match_ast, spec_ast)
      |> Enum.each(fn {c, s} ->
        @spec from!(unquote(s)) :: %__MODULE__{case: unquote(s)}
        @doc """
        Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to have a compile-time
        guarantees, use `#{mod}.from/1` macro.
        When an undefined union case is supplied it will raise an error at run-time.
        """
        def from!( x=unquote(c) ) do
          %__MODULE__{case: x}
        end
        @spec from!(unquote(s), any) :: %__MODULE__{case: unquote(s)}
        @doc """
        Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to have a compile-time
        guarantees, use `#{DiscUnion.Utils.module_name mod}.from/1` macro.
        When an undefined union case is supplied it will return second argument.
        """
        def from!( x=unquote(c), _) do
          %__MODULE__{case: x}
        end
      end)

      @doc """
      Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. Works at compile-time and will raise an error when
      unknown union case is used.
      """
      defmacro from(c) do
        case [c] |> DiscUnion.Utils.is_only_atoms? do
          true ->
            {c, _}=Code.eval_quoted c
            from!(c) |> Macro.escape
          false ->
            c |> from!
        end
      end

      def from!(_, ret), do: ret
      def from!(c) do
        DiscUnion.Utils.Case.raise_undefined_union_case c, at: :runtime
      end

      if true == Module.get_attribute __MODULE__, :dyn_constructors do
        cases
        |> Enum.map(fn
          x when is_atom x ->
            {x, 0}
          x when is_tuple(x) and x |> elem(0) |> is_atom ->
            {x |> elem(0), tuple_size(x)-1 }
        end)
        |> Enum.map(fn {c, count} ->
          case_tag = c
          |> Macro.to_string
          # |> DiscUnion.Utils.canonical_union_tag
          case c |> to_string do
            "Elixir." <> m ->
              c={:__aliases__,  [], [m |> String.to_atom]} |> Macro.escape
              {m |> Macro.underscore |> String.to_atom, c, count, case_tag}
            _ ->
              {c |> to_string |> Macro.underscore |> String.to_atom, c, count, case_tag}
          end
        end)
        |> Enum.map(fn           # HACK: too many quotes and unquotes. only solutions I could up to combine quoted and
                                 # unquoted expression
          {c, orig_c, 0, case_tag_str} ->
            @doc """
            Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union. Works at
            compile-time and will raise an error when unknown union case is used.
            """
            defmacro unquote(c)() do
              # from!(unquote(orig_c))
              # |> Macro.expand(__ENV__)
              # |> Macro.escape
              {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: unquote(orig_c)]}]}
            end

          {c, orig_c, count, case_tag_str} ->
            args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))
            @doc """
            Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union. Works at
            compile-time and will raise an error when unknown union case is used.
            """
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
  end
end
