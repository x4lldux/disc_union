# DiscUnion

## Description

Discriminated unions for Elixir.

Allows for building data structure with a closed set of representations/cases as an alternative for a tuple+atom combo.
Provides macros and functions for creating and matching on datastructres which throw compile-time and run-time
exceptions if an unknow case was used or not all cases were covered in a match. It's inspired by ML/OCaml/F# way of
building discriminated unions. Unfortunately, Elixir does not support such a strong typing and this library will not
solve this. This library allows to easly catch common mistakes at compile-time instead of run-time (those can be
sometimes hard to detect).

## How to use

In `example` folder, there is a tennis kata example, a simple coding excercise, that shows exactly how to use this
library.

To define a discriminated union, `defunion` macro is used:

``` elixir
defmodule Shape do
  use DiscUnion

  defunion Point
  | Circle in float()
  | Rectangle in any * any
end
```

Type specs in `Circle` or `Rectangle` definitions are only for description and have no influance on code nor are they
used for any type checking - there is no typchecking other then checking if correct cases were used!

When constructing a case (an union tag), you have three options:

 * `from/1` macro (compile-time checking),
 * `from!/` or `from!/2` functions (only run-time checking).
 * a dynamicaly built macro named after union tag (in a camalized form, i.e. `Score`'s `Advantage` case, in tennis kata,
 would be available as `Score.advantage/2` macro and also with compile-time checking),

If you would do `use DiscUnion, dyn_constructors: false`, dynamic constructos would not be built.


If `Score.from {Pointz, 1, 2}` be placed somwhere in `run_test_match/0` function, in tennis kata, compiler would throw
this error:

``` elixir
== Compilation error on file example/tennis_kata.exs ==
** (UndefinedUnionCaseError) undefined union case: {Pointz, 1, 2}
    (disc_union) expanding macro: Score.from/1
    (disc_union) example/tennis_kata.exs:38: Tennis.run_test_match/0
```

If you would use `from!/1`, this error would be thrown at run-time, or, in the case of `from!/2`, not at all! Function
`from!/2` returns it's second argument when unknow clause is passed to the function.


For each discriminated union, a special `case` macro is created. This macro checks if all cases were covered in it's
clauses (at compile-time) and expects it's predicate to be evaluated to this discriminated union's struct (checked at
run-time).

If `Game in _`, in `Tennis.score_point/2` functions, would be commented, compiler would throw this error:

``` elixir
== Compilation error on file example/tennis_kata.exs ==
** (MissingUnionCaseError) not all defined union cases are used, should be all of: Points in "PlayerPoints" * "PlayerPoints", Advantage in "Player", Deuce, Game in "Player"
    (disc_union) expanding macro: Score.case/2
    (disc_union) example/tennis_kata.exs:64: Tennis.score_point/2

```

You can also use a catch-all statment (_), like in a regular `case` macro (`Kernel.SpecialForms.case/2`), but here, it
needs to be explicitly enabled by passing `allow_underscore: true` option to the macro:

``` elixir
Score.case score, allow_underscore: true do
  Points in PlayerPoints.forty, PlayerPoints.forty -> Score.duce
  _ -> score
end
```

Otherwise you would see a smillar error like above.


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

### Side note

It is possible to place discriminated union's constructor macros in function definition:

``` elixir
defmodule ShapeArea do
  require Shape

  def calc_area(Shape.point), do: 0
  def calc_area(Shape.circle(r)), do: :math.pi*r*r
end
```

And even use natural Elixir's multi-fun capability, to build logic, like in `score_point/2` function in tennis kata
example. Although, placing constructors inside of function definition is not a bad thing, and being able to do so is a
clear WIN! Using this technique to build business logic, instead of using discriminated union's `case` macro, is not
encouraged because nothing checks if all union cases were covered.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add disc_union to your list of dependencies in `mix.exs`:

        def deps do
          [{:disc_union, "~> 0.1.0"}]
        end

  2. Ensure disc_union is started before your application:

        def application do
          [applications: [:disc_union]]
        end
