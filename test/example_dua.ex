defmodule ExampleDUa do
  use DiscUnion, named_constructors: true
  defunion :asd
  | :qwe in any
  | :rty in integer * atom
end
