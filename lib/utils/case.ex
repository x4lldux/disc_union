defmodule DiscUnion.Util.Case do

  @spec map_reduce_clauses(list(Macro.t), any, (list(Macro.expr), Keyword.t, any -> {Macro.t, any})) :: any
  def map_reduce_clauses(clause, f, acc) do
    # IO.inspect clause
    # block
    # |> Enum.map_reduce({f, acc}, &map_reduce_clause/2)
    {clause, {_, acc}} = clause |> map_reduce_clause({f, acc})
    {clause, acc}
  end

  defp map_reduce_clause([{:=, ctx, [ bind, precond ]} | rest_of_union_args], {f, acc}) do
    # IO.puts "bind: #{inspect bind}"
    # IO.puts "bind: #{bind |> Macro.to_string}"

    {[precond|_], f_acc} = [precond | rest_of_union_args]
    |> map_reduce_clause({f, acc})

    # IO.puts "bind_out: #{inspect bind}"
    # IO.puts "bind_out: #{bind |> Macro.to_string}"

    {[{:=, ctx, [ bind, precond ]}], {f, f_acc}}
  end

  defp map_reduce_clause([{:when, ctx, [ precond | guards_and_union_args ]}], {f, acc}) do
    # IO.puts "precond: #{inspect precond}"
    # IO.puts "precond: #{precond |> Macro.to_string}"

    guard = guards_and_union_args |> List.last
    union_arg = guards_and_union_args |> List.delete_at(-1)

    {[precond|_], f_acc} = [precond | union_arg]
    |> map_reduce_clause({f, acc})

    # IO.puts "precond_out: #{inspect precond}"
    # IO.puts "precond_out: #{precond |> Macro.to_string}"

    {[{:when, ctx, [ precond, guard ]}], {f, f_acc}}
  end

  defp map_reduce_clause(elem, {f, acc}) do
    #   # IO.puts "fallback: #{inspect all_cases |> DiscUnion.build_match_ast |> List.last |> Macro.escape }"
      # IO.puts "fallback: #{inspect elem}"
    #   # IO.puts "fallback: #{inspect c |> hd |> Macro.escape}"
    #   # IO.inspect all_cases |> DiscUnion.build_match_ast |> List.last |> Macro.escape
    {new_elem, f_acc}=f.(elem, acc)
    {new_elem, {f, f_acc}}
  end
end
