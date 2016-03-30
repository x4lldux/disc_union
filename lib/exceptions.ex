defmodule UndefinedUnionCaseError do
  defexception [case: nil, case_args_count: 0, line: 0]

  def message(exception=%{case_args_count: 0}) do
    "undefined union case: #{inspect(exception.case)} at line #{exception.line}"
  end
  def message(exception) do
    case_args = 0..exception.case_args_count-1
    |> Enum.map(fn _ -> "_" end)
    |> Enum.join(" * ")
    "undefined union case: #{inspect(exception.case)} in #{case_args} at line #{exception.line}"
  end
end

defmodule MissingUnionCaseError do
  defexception [cases: nil, line: 0]

  defp format_case(c) when is_atom(c) do
    inspect c
  end
  defp format_case(c) when is_tuple(c) do
    [tag | args] = c
    |> Tuple.to_list

    args = args |> Enum.join(" * ")
    "#{inspect tag} in #{args}"
  end
  def message(exception) do
    cases = exception.cases
    |> Enum.map(&format_case/1)
    |> Enum.join(", ")
    "not all defined union cases are used, should be all of: #{inspect(exception.cases)}"
  end
end
