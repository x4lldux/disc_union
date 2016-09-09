defmodule DiscUnion do
  @moduledoc """
  Discriminated unions for Elixir.

  Allows for building data structure with a closed set of representations/cases as an alternative for a tuple+atom combo.
  Provides macros and functions for creating and matching on datastructres which throw compile-time and run-time
  exceptions if an unknow case was used or not all cases were covered in a match. It's inspired by ML/OCaml/F# way of
  building discriminated unions. Unfortunately, Elixir does not support such a strong typing and this library will not
  solve this. This library allows to easly catch common mistakes at compile-time instead of run-time (those can be
  sometimes hard to detect).

  To use it, you need to add:  `use DiscUnion` to your module.
  """

  @type canonical_union_tag :: {:_, 0} | {:__aliases__, atom} | atom

  defmacro __using__(opts) do
    opts = opts ++ [dyn_constructors: true]
    if true == Keyword.get opts, :dyn_constructors do
      Module.put_attribute(__CALLER__.module, :dyn_constructors, true)
    end

    quote do
      require DiscUnion
      require DiscUnion.Utils.Constructors

      import DiscUnion, only: [defunion: 1]
    end
  end

  @doc """

  Defines a discriminated union.

  Use `|` to separate union cases from each other. Union cases can have arguments and a
  `*` can be used to combine several arguments. Underneath, it's just a struct with union cases represented as atoms and
  tuples.
  Type specs in definitions are only for description and have no influance on code nor are they used for any type
  checking - there is no typchecking other then checking if correct cases were used!


  ## Usage
  To define a discriminated union `Shape` with cases of `Point`, `Circle` and `Rectangle`:
  ``` elixir
  defmodule Shape do
    use DiscUnion

    defunion Point
    | Circle in float()
    | Rectangle in any * any
  end
  ```

  When constructing a case (an union tag), you have three options:

  * `from/1` macro (compile-time checking),
  * `from!/` or `from!/2` functions (only run-time checking).
  * a dynamicaly built macro named after union tag (in a camalized form, i.e. `Shape`'s `Circle` case, would be
  available as `Shape.circle/1` macro and also with compile-time checking),

  If you would do `use DiscUnion, dyn_constructors: false`, dynamic constructos would not be built.


  ## How it works

  Underneath, it's just a module containg a struct with tuples and some dynamicly built macros. This property can be used
  for matching in function deffinitions, altough it will not look as clearly as a `case` macro built for a discriminated
  union.


  The `Shape` union creates a `%Shape{}` struct with current active case held in `case` field and all possible
  cases can be get by `Shape.__union_cases__/0` function:

  ``` elixir
  %Shape{case: Point} = Shape.point
  %Shape{case: {Circle, :foo}} = Shape.circle(:foo)
  ```

  Cases that have arguments are just tuples; *n*-argument union case is a *n+1*-tuple with a case tag as it's first element.
  This should work seamlessly with existing convections:

  ``` elixir
  defmodule Result do
    use DiscUnion

    defunion :ok in any | :error in String.t
  end

  defmodule Test do
    require Result

    def run(file) do
      res = Result.from! File.open(file)
      Result.case res do
        r={:ok, io_dev}                       -> {:yey, r, io_dev}
        :error in reason when reason==:eacces -> :too_much_protections
        :error in :enoent                     -> :why_no_file
        :error in _reason                     -> :ney
      end
    end
  end
  ```
  Since cases are just a tuples, they can be used also used as a clause for `case` macro. Matching and gaurds also works!
  """
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

  defp build_union(cases) do
    union_typespec = DiscUnion.Utils.build_union_cases_specs(cases)
    main_body = quote location: :keep, unquote: true do
      all_cases = unquote(cases)
      @enforce_keys [:case]

      @type t :: %__MODULE__{case: union_cases}
      defstruct case: []

      defimpl Inspect do
        import Inspect.Algebra

        def inspect(union, opts) do
          mod=@for |> Module.split
          concat ["##{mod}<", Inspect.inspect(union.case, opts), ">"]
        end
      end

      @doc "Returns a list with all acceptable union cases."
      def __union_cases__ do
        unquote(cases)
      end

      @doc """
      Matches the given expression against the given clauses. The expressions needs to be evaluate to
      `%#{DiscUnion.Utils.module_name __MODULE__}{}`.
      """
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
        |> DiscUnion.Utils.Case.transform_case_clauses(@cases_canonical, allow_underscore)
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

      DiscUnion.Utils.Constructors.build_constructor_functions __MODULE__, all_cases
    end

    [union_typespec, main_body]
  end
end
