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
        def from!( x=unquote(c) ) do
          %__MODULE__{case: x}
        end
        @spec from!(unquote(s), any) :: %__MODULE__{case: unquote(s)}
        @doc """
        Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. This works at run-time, to
        have a compile-time guarantees, use `#{DiscUnion.Utils.module_name mod}.from/1` macro.
        When an undefined union case is supplied it will return second argument.
        """
        def from!( x=unquote(c), _) do
          %__MODULE__{case: x}
        end
      end)

      @doc """
      Constructs a valid case for `#{DiscUnion.Utils.module_name mod}` discriminated union. Works at compile-time and
      will raise an error when unknown union case is used.
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
            Constructs a valid `#{case_tag_str}` case for `#{DiscUnion.Utils.module_name mod}` discriminated union.
            Works at compile-time and will raise an error when unknown union case is used.
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
