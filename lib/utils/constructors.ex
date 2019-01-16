defmodule DiscUnion.Utils.Constructors do
  @moduledoc false

  alias DiscUnion.Utils
  alias DiscUnion.Utils.{Constructors, Case}

  defmacro build_constructor_functions(mod, cases) do
    from_constructors = build_from_constructors(cases, mod)
    c_constructors = build_c_constructors(cases, mod)
    named_constructors = build_named_constructors(cases, mod)

    [from_constructors, c_constructors, named_constructors]
  end

  def build_from_constructors(cases, mod) do
    quote bind_quoted: [cases: cases, mod: mod] do
      ext_cases = Enum.map(cases, &Constructors.extended_case_tag_definition/1)
      for {variant_case, case_tag, case_tag_match_ast, _case_tag_str, count} <- ext_cases do
        case_tuple_match_ast = Constructors.case_tuple_match_ast variant_case
        case_tuple_spec_ast = Constructors.case_tuple_spec_ast variant_case

        @spec from!(unquote(case_tuple_spec_ast)) :: %__MODULE__{
          case: unquote(case_tuple_spec_ast)
        }
        @doc """
        Constructs a valid case for `#{Utils.module_name mod}` discriminated
        union. This works at run-time, to have a compile-time guarantees, use
        `#{mod}.from/1` macro.  When an undefined union case is supplied it will
        raise an error at run-time.
        """
        def from!(case_tuple = unquote(case_tuple_match_ast) ) do
          %__MODULE__{case: case_tuple}
        end

        @spec from!(unquote(case_tuple_spec_ast), any) :: %__MODULE__{
          case: unquote(case_tuple_spec_ast)
        }
        @doc """
        Constructs a valid case for `#{Utils.module_name mod}` discriminated
        union. This works at run-time, to have a compile-time guarantees, use
        `#{Utils.module_name mod}.from/1` macro.  When an undefined union case
        is supplied it will return second argument.
        """
        def from!(case_tuple = unquote(case_tuple_match_ast), _) do
          %__MODULE__{case: case_tuple}
        end

        case count do
          0 ->
            defmacro from(unquote(case_tag_match_ast)) do
              case_clause = unquote(case_tag)
              mod = unquote(mod)
              quote do: %{__struct__: unquote(mod), case: unquote(case_clause)}
            end

          1 ->
            defmacro from({unquote(case_tag_match_ast), arg}) do
              case_clause = {unquote(case_tag), arg}
              mod = unquote(mod)
              quote do: %{__struct__: unquote(mod), case: unquote(case_clause)}
            end

          _ ->
            args = for i <- 1..count, do: Macro.var(:"v#{i}", nil)
            defmacro from(case_tuple = {:{}, _, [unquote(case_tag_match_ast) | args]})
            when length(args) == unquote(count) do
              case_clause = case_tuple
              mod = unquote(mod)
              quote do: %{__struct__: unquote(mod), case: unquote(case_clause)}
            end
        end
      end

      # default fallbacks raising errors
      def from!(case_tuple, ret), do: ret
      def from!(case_tuple) do
        Case.raise_undefined_union_case case_tuple, at: :runtime
      end

      defmacro from(case_tag) do
        Case.raise_undefined_union_case case_tag, at: :compiletime
      end
    end
  end

  defp build_c_constructors(cases, mod) do
    quote bind_quoted: [cases: cases, mod: mod] do
      # construct `c` and `from` macros and `c!` functions

      ext_cases = Enum.map(cases, &Constructors.extended_case_tag_definition/1)
      for {variant_case, case_tag, case_tag_match_ast, case_tag_str, 0} <- ext_cases do
        case_params_spec_ast = Constructors.case_spec_ast_params_list variant_case

        @doc """
        Constructs a valid `#{case_tag_str}` case for `#{Utils.module_name mod}`
        discriminated union.  Works at compile-time and will raise an error when
        unknown union case is used.
        """
        defmacro c(unquote(case_tag_match_ast)) do
          case_clause = unquote(case_tag)
          mod = unquote(mod)
          quote do
            %{__struct__: unquote(mod), case: unquote(case_clause)}
          end
        end

        @spec c!(unquote_splicing(case_params_spec_ast)) :: %__MODULE__{
          case: (unquote_splicing(case_params_spec_ast))
        }
        def c!(case_tag = unquote(case_tag)) do
          %__MODULE__{case: case_tag}
        end
      end

      for {variant_case, case_tag, case_tag_match_ast, case_tag_str, count} <- ext_cases,
      count > 0 do
        case_params_spec_ast = Constructors.case_spec_ast_params_list variant_case
        args = for i <- 1..count, do: Macro.var(:"v#{i}", nil)

        defmacro c(unquote(case_tag_match_ast), unquote_splicing(args)) do
          case_tag = unquote(case_tag)
          args = unquote(args)
          mod = unquote(mod)
          quote do: %{__struct__: unquote(mod),
                      case: {unquote(case_tag), unquote_splicing(args)}}
        end

        @spec c!(unquote_splicing(case_params_spec_ast)) :: %__MODULE__{
          case: {unquote_splicing(case_params_spec_ast)}
        }
        def c!(case_tag = unquote(case_tag), unquote_splicing(args)) do
          %__MODULE__{case: {case_tag, unquote_splicing(args)}}
        end
      end

      # default fallbacks raising errors
      ext_cases_grouped_by_arity = Enum.group_by(ext_cases, &elem(&1, 4))
      for {0, _} <- ext_cases_grouped_by_arity do
        @doc """
        Constructs a valid case for `#{Utils.module_name mod}` discriminated
        union.  Works at compile-time and will raise an error when unknown union
        case is used.
        """
        defmacro c(case_tag) do
          Case.raise_undefined_union_case case_tag, at: :compiletime
        end

        @doc """
        Constructs a valid case for `#{Utils.module_name mod}` discriminated
        union.  Works at runtime-time and will raise an error when unknown union
        case is used.
        """
        def c!(case_tag) do
          Case.raise_undefined_union_case case_tag, at: :compiletime
        end
      end

      for {count, _} <- ext_cases_grouped_by_arity, count > 0 do
        args = for i <- 1..count, do: Macro.var(:"v#{i}", nil)

        @doc """
        Constructs a valid case for `#{Utils.module_name mod}` discriminated
        union.  Works at compile-time and will raise an error when unknown union
        case is used.
        """
        defmacro c(case_tag, unquote_splicing(args)) do
          args = unquote(args)
          case_tuple = quote do: {unquote(case_tag), unquote_splicing(args)}
          Case.raise_undefined_union_case case_tuple, at: :compiletime
        end

        @doc """
        Constructs a valid case for `#{Utils.module_name mod}` discriminated
        union.  Works at runtime-time and will raise an error when unknown union
        case is used.
        """
        def c!(case_tag, unquote_splicing(args)) do
          args = unquote(args)
          case_tuple = quote do: {unquote(case_tag), unquote_splicing(args)}
          Case.raise_undefined_union_case case_tuple, at: :compiletime
        end
      end
    end
  end

  def build_named_constructors(cases, mod) do
    quote bind_quoted: [cases: cases, mod: mod] do
      if true == Module.get_attribute __MODULE__, :named_constructors do
        ext_cases = Enum.map(cases, &Constructors.extended_case_tag_definition/1)

        for {_variant_case, case_tag, _case_tag_match_ast, case_tag_str, 0} <- ext_cases do
          named_constructors_name = Constructors.named_constructors_name(case_tag)

          @doc """
          Constructs a valid `#{case_tag_str}` case for
          `#{Utils.module_name mod}` discriminated union.  Works at
          compile-time and will raise an error when unknown union case is used.
          """
          defmacro unquote(named_constructors_name)() do
            # {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: unquote(case_tag)]}]}
            mod = unquote(mod)
            case_tag = unquote(case_tag)
            quote do: %{__struct__: unquote(mod), case: unquote(case_tag)}
          end
        end

        for {_variant_case, case_tag, _case_tag_match_ast, case_tag_str, count} <- ext_cases,
          count > 0 do
          args = for i <- 1..count, do: Macro.var(:"v#{i}", nil)
          named_constructors_name = Constructors.named_constructors_name(case_tag)

          @doc """
          Constructs a valid `#{case_tag_str}` case for
          `#{Utils.module_name mod}` discriminated union.  Works at compile-time
          and will raise an error when unknown union case is used.
          """
          defmacro unquote(named_constructors_name)(unquote_splicing(args)) do
            mod = unquote(mod)
            args = unquote(args)
            case_tag = unquote(case_tag)
            quote do: %{__struct__: unquote(mod), case: {unquote(case_tag), unquote_splicing(args)}}
          end
        end
      end
    end
  end

  @doc """
  Builds AST for matching a case.  When is a single atom, AST looks the
  same. For tuples, first argument (union tag) is saved, but rest is replaced
  with underscore `_` to match anything.
  """
  @spec case_tuple_match_ast(Macro.expr) :: Macro.expr
  def case_tuple_match_ast(union_case) do
    union_case = union_case |> Macro.escape
    case union_case do
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
    end
  end

  def case_spec_ast_params_list(union_case) do
    union_case = union_case |> Macro.escape
    case union_case do
      x when is_atom(x) ->
        [x]
      {op, ctx, [c | cs]} when op in [:{}, :__aliases__] and is_atom(c) ->
        cs = cs |> Enum.map(fn arg ->
          "quote do #{arg} end"
          |> Code.eval_string([], ctx)
          |> elem(0)
        end)
        [c | cs]
      {c, cs} when c |> is_atom -> # 2-tuple
        cs =
          "quote do #{cs} end"
          |> Code.eval_string([], __ENV__)
          |> elem(0)
        [c, cs]
    end

  end

  @spec case_tuple_spec_ast(Macro.expr) :: Macro.expr
  def case_tuple_spec_ast(union_case) do
    specs = union_case |> case_spec_ast_params_list
    case specs do
      [x] ->
        x
      _ -> # 2-tuple
        {:{}, [], specs}
    end
  end

  def named_constructors_name(variant_case) do
    case_tag = case variant_case |> to_string do
                 "Elixir." <> case_tag -> case_tag
                 case_tag              -> case_tag
               end

    case_tag
    |> Macro.underscore
    |> String.to_atom
  end

  def extended_case_tag_definition(variant_case) do
    {case_tag, count} = case variant_case do
                          variant_case when is_atom variant_case ->
                            {variant_case, 0}
                          variant_case when is_tuple(variant_case)
                            and is_atom(elem variant_case, 0) ->
                            {variant_case |> elem(0), tuple_size(variant_case) - 1 }
                        end
    case_tag_str = case_tag |> Macro.to_string
    case_tag_match_ast = case case_tag |> to_string do
                           "Elixir." <> m ->
                             {:{}, [], [:__aliases__,
                                        {:_, [], Elixir},
                                        [m |> String.to_atom]]}
                           _ -> case_tag
                         end
    {variant_case, case_tag, case_tag_match_ast, case_tag_str, count}
  end
end
