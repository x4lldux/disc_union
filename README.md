# DiscUnion

Discriminated unions for Elixir

## TODO

 * [x] add tests
 * [x] agree on naming convention
 * [x] split up code into seperate files
 * [ ] refactor functions
 * [x] `case` macro should throw an error if not all cases are exhausted
 * [ ] remove debuging statements
 * [ ] add constructor building for each union case and "bang" macros/functions for runtime checks

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add disc_union to your list of dependencies in `mix.exs`:

        def deps do
          [{:disc_union, "~> 0.0.1"}]
        end

  2. Ensure disc_union is started before your application:

        def application do
          [applications: [:disc_union]]
        end
