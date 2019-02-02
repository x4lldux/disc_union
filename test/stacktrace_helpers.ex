defmodule DiscUnionTest.StacktraceHelper do
  @moduledoc false
  use ExampleDU

  # Catches exception and returns it with stacktrace and the original location.
  defmacrop rescue_me (body) do
    quote location: :keep do
      try do
        unquote(body)
      rescue
        ex ->
          stacktrace = System.stacktrace()
          {ex, stacktrace, __ENV__.file, __ENV__.line}
      end
    end
  end

  def raise_on_from! do
    rescue_me ExampleDU.from! {Qqq, 1, 2}
  end

  def raise_on_c! do
    rescue_me ExampleDU.c! Qqqq, 1, 2
  end

  def x do
    q = quote do
      use ExampleDU
      ExampleDU.c Fake, 123
    end

    rescue_me Code.eval_quoted q
  end
end
