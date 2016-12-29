defmodule ExampleDUdc do
  use DiscUnion, named_constructors: false

  defunion A | B | C
end
