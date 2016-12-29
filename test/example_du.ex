defmodule ExampleDU do
  use DiscUnion, named_constructors: true
  defunion Asd
  | Qwe in any
  | Rty in integer * atom
end
