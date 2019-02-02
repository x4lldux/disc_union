defmodule DiscUnion do
  @moduledoc """
  Discriminated unions for Elixir - for building algebraic data types.

  Allows for building data structure with a closed set of representations/cases as
  an alternative for a set of tuple+atom combo. Elixir already had product type -
  tuples. With DiscUnion library, sum-types, types with a fixed set of values can
  be created (also called discriminated unions or disjoint unions).

  Provides macros and functions for creating and matching on datastructres which
  throw compile-time and run-time exceptions if an unknow case was used or not all
  cases were covered in a match. It's inspired by ML/OCaml/F# way of building
  discriminated unions. Unfortunately, Elixir does not support such a strong
  typing and this library will not solve this. However, it allows to easily catch
  common mistakes at compile-time instead of run-time (those can be sometimes hard
  to detect).

  To use it, you need to add:  `use DiscUnion` to your module.

  ## How it works

  Underneath, it's just a module containg a struct with tuples and some
  dynamically built macros. This property can be used for matching in function
  definitions, although it will not look as clearly as a `case` macro built for a
  discriminated union.


  The `Shape` union creates a `%Shape{}` struct with current active case held in
  `case` field and all possible cases can be get by `Shape.__union_cases__/0`
  function:

  ``` elixir
  %Shape{case: Point} = Shape.c Point
  %Shape{case: {Circle, :foo}} = Shape.c Circle, :foo
  ```

  Cases that have arguments are just tuples; *n*-argument union case is a
  *n+1*-tuple with a case tag as it's first element. This should work seamlessly
  with existing conventions:

  ``` elixir
  defmodule Result do
    use DiscUnion

    defunion :ok in any | :error in atom
  end

  defmodule Test do
    use Result

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
  Since cases are just a tuples, they can be also used as a clause for `case`
  macro. Matching and gaurds also works!
  """

  defmacro __using__(opts) do
    opts = opts ++ [named_constructors: false]
    if true == Keyword.get opts, :named_constructors do
      Module.put_attribute(__CALLER__.module, :named_constructors, true)
    end

    quote do
      require DiscUnion
      require DiscUnion.Utils.Case
      require DiscUnion.Utils.Constructors

      import DiscUnion, only: [defunion: 1]
    end
  end

  @doc """
  Defines a discriminated union.

  To define a discriminated union, `defunion` macro is used. Use `|` to separate
  union cases from each other. Union cases can have arguments and an asterisk
  `*` can be used to combine several arguments. Underneath, it's just a struct
  with union cases represented as atoms and tuples. Type specs in definitions
  are passed to `@spec` declaration, so dialyzer can be used. However, DiscUnion
  does not type-check anything by it self.

  ### Usage

  ``` elixir
  defmodule Shape do
    use DiscUnion

    defunion Point
    | Circle in float()
    | Rectangle in any * any
  end
  ```

  Type specs in `Circle` or `Rectangle` definitions are only for description and
  have no influence on code nor are they used for any type checking - there is
  no typchecking other then checking if correct cases were used!

  When constructing a case (an union tag), you have couple of options:

   * `c` macro, where arity depends on number of arguments you set for
     cases (compile-time checking),
   * `c!` function, where arity depends on number of arguments you set for
     cases (run-time checking),
   * `from/1` macro, accepts a tuple (compile-time checking),
   * `from!/` or `from!/2` functions, accepts a tuple (only run-time checking).
   * a dynamically built macro (aka "named constructors") named after union tag
     (in a camelized form, i.e. `Point`'s `Rectangle` case, would be available
     as `Point.rectangle/2` macro and also with compile-time checking),

  Preferred way to construct a variant case is via `c` macros or `c!`
  functions. `from/1` and `from!/1` construcotrs are mainly to be used when
  interacting with return values like in example with opening a file. If you'd
  like to enable named constructors do:
  `use DiscUnion, named_constructors: true`.


  If `Score.from {Pointz, 1, 2}` or `Score.c Pointz, 1, 2`, from tennis kata
  example, be placed somewhere in `run_test_match/0` function compiler would
  throw this error:

  ``` elixir
  == Compilation error on file example/tennis_kata.exs ==
  ** (UndefinedUnionCaseError) undefined union case: Pointz in _, _
      (disc_union) expanding macro: Score.from/1
      (disc_union) example/tennis_kata.exs:38: Tennis.run_test_match/0
  ```

  If you would use `from!/1` or `c!`, this error would be thrown at run-time,
  or, in the case of `from!/2`, not at all! Function `from!/2` returns it's
  second argument when unknow clause is passed to the function.


  For each discriminated union, a special `case` macro is created. This macro
  checks if all cases were covered in it's clauses (at compile-time) and expects
  it's predicate to be evaluated to this discriminated union's struct (checked
  at run-time).

  If `Game in _`, in `Tennis.score_point/2` functions, would be commented,
  compiler would throw this error:

  ``` elixir
  == Compilation error on file example/tennis_kata.exs ==
  ** (MissingUnionCaseError) not all defined union cases are used, should be all of: Points in "PlayerPoints" * "PlayerPoints", Advantage in "Player", Deuce, Game in "Player"
      (disc_union) expanding macro: Score.case/2
      (disc_union) example/tennis_kata.exs:64: Tennis.score_point/2
  ```

  You can also use a catch-all statement (_), like in a regular `case` macro
  (`Kernel.SpecialForms.case/2`), but here, it needs to be explicitly enabled by
  passing `allow_underscore: true` option to the macro:

  ``` elixir
  Score.case score, allow_underscore: true do
    Points in PlayerPoints.forty, PlayerPoints.forty -> Score.duce
    _ -> score
  end
  ```

  Otherwise you would see a smillar error like above.
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

      defstruct case: []

      defimpl Inspect do
        import Inspect.Algebra

        def inspect(union, opts) do
          mod = @for |> Module.split
          concat ["##{mod}<", Inspect.inspect(union.case, opts), ">"]
        end
      end

      @doc "Returns a list with all acceptable union cases."
      def __union_cases__ do
        unquote(cases)
      end

      def __using__(_) do
        quote do
          require unquote(__MODULE__)
        end
      end

      @doc """
      Matches the given expression against the given clauses. The expressions
      needs to be evaluate to `%#{DiscUnion.Utils.module_name __MODULE__}{}`.
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

      @spec do_case(Macro.t, Keyword.t, [do: Macro.t]) :: Macro.t
      defp do_case(expr, opts, do: block) do
        opts = opts ++ [allow_underscore: false]
        mod = __MODULE__
        allow_underscore = Keyword.get opts, :allow_underscore
        block = DiscUnion.Utils.Case.transform_case_clauses(block,
          @cases_canonical, allow_underscore)
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
