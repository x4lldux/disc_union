# DiscUnion

## Description

Discriminated unions for Elixir.

Allows for building data structure with a closed set of representations/cases as an alternative for a tuple+atom combo. Provides macros and functions for creating and matching on datastructres which throw compile-time and run-time exceptions if an unknow case was used or not all cases were covered in a match.
It's inspired by ML/OCaml/F# way of building discriminated unions. Unfortunately, Elixir does not support such a strong typing and this library will not solve this. This library allows to easly catch common mistakes at compile-time instead of run-time (those can be sometimes hard to detect).

In `example` folder, there is a tennis kata example, a simple coding excercise, that shows exactly how to use this library. If `Game in _`, in `Tennis.score_point/2` functions, would be commented compiler would throw and error with


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
