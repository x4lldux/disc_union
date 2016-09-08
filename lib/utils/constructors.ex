defmodule DiscUnion.Utils.Constructors do
  @moduledoc false

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
        Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to
        have a compile-time guarantees, use `#{mod}.from/1` macro.
        When an undefined union case is supplied it will raise an error at run-time.
        """
        def from!(case_tuple=unquote(c) ) do
          %__MODULE__{case: case_tuple}
        end
        @spec from!(unquote(s), any) :: %__MODULE__{case: unquote(s)}
        @doc """
        Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to
        have a compile-time guarantees, use `#{DiscUnion.Utils.module_name mod}.from/1` macro.
        When an undefined union case is supplied it will return second argument.
        """
        def from!(case_tuple=unquote(c), _) do
          %__MODULE__{case: case_tuple}
        end
      end)

      def from!(case_tuple, ret), do: ret
      def from!(case_tuple) do
        DiscUnion.Utils.Case.raise_undefined_union_case case_tuple, at: :runtime
      end

      case_extended_defintion = cases
      |> Enum.map(fn
        x when is_atom x ->
          {x, 0}
        x when is_tuple(x) and x |> elem(0) |> is_atom ->
          {x |> elem(0), tuple_size(x)-1 }
      end)
      |> Enum.map(fn {c, count} ->
        case_tag =
          c
          |> Macro.to_string
        case c |> to_string do
          "Elixir." <> m ->
            # alias_c={:__aliases__,  quote do _ end, [m |> String.to_atom]} |> Macro.escape
            alias_c={:{}, [], [:__aliases__, {:_, [], Elixir}, [m |> String.to_atom]]}
            {m |> Macro.underscore |> String.to_atom, c, alias_c, count, case_tag}
          _ ->
            {c |> to_string |> Macro.underscore |> String.to_atom, c, c, count, case_tag}
        end
      end)

      # construct `c` and `from` macros and `c!` functions
      case_extended_defintion
      |> Enum.map(fn           # HACK: too many quotes and unquotes. only solutions I came up with to combine quoted and
                               # unquoted expression
        {c, orig_c, match_ast, 0, case_tag_str} ->
          defmacro from(unquote(match_ast)) do
            case_tag = unquote(orig_c)
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: case_tag]}]}
          end

          @doc """
          Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
          Works at compile-time and will raise an error when unknown union case is used.
          """
          defmacro c(unquote(match_ast)) do
            case_tag = unquote(orig_c)
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: case_tag]}]}
          end

          def c!(unquote(match_ast)) do
            case_tag = unquote(orig_c)
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: case_tag]}]}
          end

       {c, orig_c, match_ast, count, case_tag_str} ->
          args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))

          if count == 1 do
            defmacro from({unquote(match_ast), arg}) do
              tuple = {unquote(orig_c), arg}
              {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
            end
          else
            defmacro from(case_tuple={:{}, _, [unquote(match_ast) | args]}) when length(args)==unquote(count) do
              tuple = case_tuple
              {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
            end
          end

          # @doc """
          # Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
          # Works at compile-time and will raise an error when unknown union case is used.
          # """
          defmacro c(unquote(match_ast), unquote_splicing(args)) do
            tuple = {:{}, [], [unquote(orig_c) | unquote(args)]}
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
          end

          def c!(unquote(match_ast), unquote_splicing(args)) do
            tuple = {:{}, [], [unquote(orig_c) | unquote(args)]}
            {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: tuple]}]}
          end
      end)

      # default fallbacks raising errors
      case_extended_defintion
      |> Enum.group_by(&elem(&1, 3))
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

      defmacro from(case_tag) do
        DiscUnion.Utils.Case.raise_undefined_union_case case_tag, at: :compiletime
      end

      if true == Module.get_attribute __MODULE__, :dyn_constructors do
       case_extended_defintion
       |> Enum.map(fn           # HACK: too many quotes and unquotes. only solutions I could up to combine quoted and
       # unquoted expression
         {c, orig_c, match_ast, 0, case_tag_str} ->
            @doc """
            Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
            Works at compile-time and will raise an error when unknown union case is used.
            """
            defmacro unquote(c)() do
              {:%, [], [{:__aliases__, [alias: false], [__MODULE__]}, {:%{}, [], [case: unquote(orig_c)]}]}
            end

          {c, orig_c, match_ast, count, case_tag_str} ->
            args = 1..count |> Enum.map(&(Macro.var("v#{&1}" |> String.to_atom, nil)))

            @doc """
            Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
            Works at compile-time and will raise an error when unknown union case is used.
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
