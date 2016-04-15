defmodule Player do
  use DiscUnion

  defunion A | B
end

defmodule PlayerPoints do
  use DiscUnion

  defunion Love | Fifteen | Thirty | Forty
end

defmodule Score do
  use DiscUnion
  require PlayerPoints

  defunion Points in PlayerPoints * PlayerPoints
  | Advantage in Player
  | Deuce
  | Game in Player

  def zero_score do
    love=PlayerPoints.love
  # Score.points love, love     # TODO: investigate why function is unknown
    Score.from! {Points, love, love}
  end
end

defmodule Tennis do
  require Player
  require PlayerPoints
  require Score

  def run_test_match do
    # Player A will always wins!
    # All hail the victor!

    # Score.from! {Pointz, 1, 2}
    Score.zero_score
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
  end

  def score_point(%Score{}=score, %Player{}=point_player) do
    IO.puts "Point for player #{inspect point_player} @ #{inspect score}"
    Score.case score do
      Advantage in ^point_player                                  -> Score.game point_player
      Advantage in _                                              -> Score.deuce
      Deuce                                                       -> Score.advantage point_player
      Points in PlayerPoints.forty, _ when point_player==Player.a -> Score.game Player.a
      Points in _, PlayerPoints.forty when point_player==Player.b -> Score.game Player.b
      Points in a, b when point_player==Player.a                  -> Score.points(next_point_score(a), b) |> normalize_score
      Points in a, b when point_player==Player.b                  -> Score.points(a, next_point_score(b)) |> normalize_score
      Game in _                                                   -> IO.puts "Game is over #{inspect score}"
    end
  end

  def run_test_match2 do
    # Player A will always wins!
    # All hail the victor!

    # Score.from! {Pointz, 1, 2}
    Score.zero_score
    |> Tennis.score_point2(Player.a)
    |> Tennis.score_point2(Player.a)
    |> Tennis.score_point2(Player.a)
    |> Tennis.score_point2(Player.a)
    |> Tennis.score_point2(Player.a)
  end

  # NOTE: Works too, but nothing ensures you covered all possible cases for Score type! So don't use this way of
  # building logic too often, or unicorns will cry ;)
  def score_point2(Score.advantage(point_player), point_player),        do: Score.game point_player
  def score_point2(Score.advantage(_), _point_player),                  do: Score.deuce
  def score_point2(Score.deuce, point_player),                          do: Score.advantage point_player
  def score_point2(Score.points(PlayerPoints.forty, _), _point_player), do: Score.game Player.a
  def score_point2(Score.points(_, PlayerPoints.forty), _point_player), do: Score.game Player.b
  def score_point2(Score.points(a, b), Player.a),                       do: Score.points(next_point_score(a), b) |> normalize_score
  def score_point2(Score.points(a, b), Player.b),                       do: Score.points(a, next_point_score(b)) |> normalize_score
  def score_point2(score=Score.game(_), _point_player),                 do: IO.puts "Game is over #{inspect score}"


  defp next_point_score(%PlayerPoints{}=point) do
    PlayerPoints.case point do
      Love    -> PlayerPoints.fifteen
      Fifteen -> PlayerPoints.thirty
      Thirty  -> PlayerPoints.forty
      Forty   -> raise "WAT?"
    end
  end

  defp normalize_score(%Score{}=score) do
    Score.case score, allow_underscore: true do
      Points in PlayerPoints.forty, PlayerPoints.forty -> Score.duce
      _ -> score
    end
  end
end
