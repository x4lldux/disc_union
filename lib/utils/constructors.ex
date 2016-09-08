defmodule DiscUnion.Utils.Constructors do
  @moduledoc false

  defmacro build_constructor_functions(mod, cases) do
    from_constructors = build_from_constructors(cases, mod)
    c_constructors = build_c_constructors(cases, mod)
    dyn_constructors = build_dyn_constructors(cases, mod)

    [from_constructors, c_constructors, dyn_constructors]
  end

  def build_from_constructors(cases, mod) do
    quote bind_quoted: [cases: cases, mod: mod] do
      cases
      |> Enum.map(&DiscUnion.Utils.Constructors.extended_case_tag_definition/1)
      |> Enum.map(fn
        {variant_case, case_tag, case_tag_match_ast, _case_tag_str, count} ->
          case_tuple_match_ast =
            variant_case |> DiscUnion.Utils.Constructors.case_tuple_match_ast
          case_tuple_spec_ast =
            variant_case |> DiscUnion.Utils.Constructors.case_tuple_spec_ast

          @spec from!(unquote(case_tuple_spec_ast)) :: %__MODULE__{case: unquote(case_tuple_spec_ast)}
          @doc """
          Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to
          have a compile-time guarantees, use `#{mod}.from/1` macro.
          When an undefined union case is supplied it will raise an error at run-time.
          """
          def from!(case_tuple=unquote(case_tuple_match_ast) ) do
            %__MODULE__{case: case_tuple}
          end
          @spec from!(unquote(case_tuple_spec_ast), any) :: %__MODULE__{case: unquote(case_tuple_spec_ast)}
          @doc """
          Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to
          have a compile-time guarantees, use `#{DiscUnion.Utils.module_name mod}.from/1` macro.
          When an undefined union case is supplied it will return second argument.
          """
          def from!(case_tuple=unquote(case_tuple_match_ast), _) do
            %__MODULE__{case: case_tuple}
          end

          case count do
            0 ->
              defmacro from(unquote(case_tag_match_ast)) do
                case_tag = unquote(case_tag)
                {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: case_tag]}]}
              end

            1 ->
              defmacro from({unquote(case_tag_match_ast), arg}) do
                tuple = {unquote(case_tag), arg}
                {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
              end

            _ ->
              args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))
              defmacro from(case_tuple={:{}, _, [unquote(case_tag_match_ast) | args]}) when length(args)==unquote(count) do
                tuple = case_tuple
                {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
              end
          end
      end)

      # default fallbacks raising errors
      def from!(case_tuple, ret), do: ret
      def from!(case_tuple) do
        DiscUnion.Utils.Case.raise_undefined_union_case case_tuple, at: :runtime
      end

      defmacro from(case_tag) do
        DiscUnion.Utils.Case.raise_undefined_union_case case_tag, at: :compiletime
      end
    end
  end

  defp build_c_constructors(cases, mod) do
    quote bind_quoted: [cases: cases, mod: mod] do

      # construct `c` and `from` macros and `c!` functions
      cases
      |> Enum.map(&DiscUnion.Utils.Constructors.extended_case_tag_definition/1)
      |> Enum.map(fn           # HACK: too many quotes and unquotes. only solutions I came up with to combine quoted and
                               # unquoted expression
        {variant_case, case_tag, case_tag_match_ast, case_tag_str, 0} ->
          @doc """
          Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
          Works at compile-time and will raise an error when unknown union case is used.
          """
          defmacro c(unquote(case_tag_match_ast)) do
            case_tag = unquote(case_tag)
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: case_tag]}]}
          end

       {_variant_case, case_tag, case_tag_match_ast, case_tag_str, count} ->
          args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))

          # @doc """
          # Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
          # Works at compile-time and will raise an error when unknown union case is used.
          # """
          defmacro c(unquote(case_tag_match_ast), unquote_splicing(args)) do
            tuple = {:{}, [], [unquote(case_tag) | unquote(args)]}
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
          end
      end)

      # default fallbacks raising errors
      cases
      |> Enum.map(&DiscUnion.Utils.Constructors.extended_case_tag_definition/1)
      |> Enum.group_by(&elem(&1, 4))
      |> Enum.map(fn
        {0, _} ->
          defmacro c(case_tag) do
            DiscUnion.Utils.Case.raise_undefined_union_case case_tag, at: :compiletime
          end

        {count, _} ->
          args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))
          defmacro c(case_tag, unquote_splicing(args)) do
            case_tuple = {:{}, [], [case_tag | unquote(args)]}
            DiscUnion.Utils.Case.raise_undefined_union_case case_tuple, at: :compiletime
          end
      end)
    end
  end

  def build_dyn_constructors(cases, mod) do
    quote bind_quoted: [cases: cases, mod: mod] do
      if true == Module.get_attribute __MODULE__, :dyn_constructors do
       cases
       |> Enum.map(&DiscUnion.Utils.Constructors.extended_case_tag_definition/1)
       |> Enum.map(fn           # HACK: too many quotes and unquotes. only solutions I could up to combine quoted and
                                # unquoted expression
         {_variant_case, case_tag, _case_tag_match_ast, case_tag_str, 0} ->
           dyn_constructors_name = DiscUnion.Utils.Constructors.dyn_constructors_name(case_tag)

           @doc """
           Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
           Works at compile-time and will raise an error when unknown union case is used.
           """
           defmacro unquote(dyn_constructors_name)() do
             {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: unquote(case_tag)]}]}
           end

         {_variant_case, case_tag, _case_tag_match_ast, case_tag_str, count} ->
           args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))
           dyn_constructors_name = DiscUnion.Utils.Constructors.dyn_constructors_name(case_tag)

            @doc """
            Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
            Works at compile-time and will raise an error when unknown union case is used.
            """
            defmacro unquote(dyn_constructors_name)(unquote_splicing(args)) do
              tuple = {:{}, [], [unquote(case_tag)  | unquote(args)]}
              # __MODULE__.from!(tuple)
              # |> Macro.expand(__ENV__)
              # |> Macro.escape
              {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
            end
        end)
      end
    end
  end

  @doc """
  Builds AST for matching a case.
  When is a single atom, AST looks the same. For tuples, first argument (union tag) is saved, but rest is replaced
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

  @spec case_tuple_spec_ast(Macro.expr) :: Macro.expr
  def case_tuple_spec_ast(union_case) do
    union_case = union_case |> Macro.escape
    case union_case do
      x when is_atom(x) ->
        x
      {op, ctx, [c | cs]} when op in [:{}, :__aliases__] and is_atom(c) ->
        cs = cs |> Enum.map(fn _ ->
          quote do: any
        end)
        {:{}, ctx, [c |cs]}
      {c, _} when c |> is_atom -> # 2-tuple
        cs = [quote do: any]
        {:{}, [], [c | cs ]}
    end
  end


  def dyn_constructors_name(variant_case) do
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
                          variant_case when is_tuple(variant_case) and variant_case |> elem(0) |> is_atom ->
                            {variant_case |> elem(0), tuple_size(variant_case)-1 }
                        end
    case_tag_str = case_tag |> Macro.to_string
    case_tag_match_ast = case case_tag |> to_string do
                           "Elixir." <> m ->
                             {:{}, [], [:__aliases__, {:_, [], Elixir}, [m |> String.to_atom]]}
                           _ -> case_tag
                         end
    {variant_case, case_tag, case_tag_match_ast, case_tag_str, count}
  end
end
