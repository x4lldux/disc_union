# DiscUnion

Discriminated unions for Elixir

## TODO

 * [ ] add tests
 * [x] agree on naming convention
 * [ ] split up code into seperate files
 * [ ] refactor functions
 * [ ] `case` macro should warnin if not all cases are exhausted
 * [ ] remove debuging statements

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
