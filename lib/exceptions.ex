defmodule UndefinedUnionCaseError do
  defexception [case: nil, case_args_count: 0, line: 0]

  def message(exception=%{case_args_count: 0}) do
    "undefined union case: #{exception.case}"
  end
  def message(exception=%{case_args_count: nil}) do
    message(%{exception | case_args_count: 0})
  end
  def message(exception) do
    case_args = 0..exception.case_args_count-1
    |> Enum.map(fn _ -> "_" end)
    |> Enum.join(" * ")
    "undefined union case: #{exception.case} in #{case_args}"
  end
end

defmodule MissingUnionCaseError do
  defexception [cases: nil]

  defp format_case(c) when is_atom(c) do
    inspect c
  end
  defp format_case(c) when is_tuple(c) do
    [tag | args] = c
    |> Tuple.to_list

    args = args |> Enum.join(" * ")
    "#{tag} in #{args}"
  end
  defp format_case(c), do: c |> to_string
  def message(exception) do
    cases = exception.cases
    |> Enum.map(&format_case/1)
    |> Enum.join(", ")
    "not all defined union cases are used, should be all of: #{cases}"
  end
end
