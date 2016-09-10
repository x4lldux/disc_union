# Example is uses both `c` and named constructors. But because named constructors
# are camelized, they may sometimes be less readable than `c` constructors

defmodule Player do
  use DiscUnion, named_constructors: true

  defunion A | B
end

defmodule PlayerPoints do
  use DiscUnion, named_constructors: true

  defunion Love | Fifteen | Thirty | Forty
end

defmodule Score do
  use DiscUnion
  require PlayerPoints

  defunion Points in PlayerPoints.t * PlayerPoints.t
  | Advantage in Player.t
  | Deuce
  | Game in Player.t

  def zero_score do
    love=PlayerPoints.c Love
    c Points, love, love
  end
end

defmodule Tennis do
  require Player
  require PlayerPoints
  require Score

  def run_test_match do
    # Player A will always wins!
    # All hail the victor!

    # Score.c! Pointz, 1, 2
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
      Advantage in ^point_player                                  -> Score.c Game, point_player
      Advantage in _                                              -> Score.c Deuce
      Deuce                                                       -> Score.c Advantage, point_player
      Points in PlayerPoints.forty, _ when point_player==Player.a -> Score.c Game, Player.a
      Points in _, PlayerPoints.forty when point_player==Player.b -> Score.c Game, Player.b
      Points in a, b when point_player==Player.a                  -> Score.c(Points, next_point_score(a), b) |> normalize_score
      Points in a, b when point_player==Player.b                  -> Score.c(Points, a, next_point_score(b)) |> normalize_score
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
  def score_point2(Score.c(Advantage, point_player), point_player),           do: Score.c Game, point_player
  def score_point2(Score.c(Advantage, _), _point_player),                     do: Score.c Deuce
  def score_point2(Score.c(Deuce),  point_player),                            do: Score.c Advantage, point_player
  def score_point2(Score.c(Points, PlayerPoints.c(Forty), _), _point_player), do: Score.c Game, Player.a
  def score_point2(Score.c(Points, _, PlayerPoints.c(Forty)), _point_player), do: Score.c Game, Player.b
  def score_point2(Score.c(Points, a, b), Player.a),                          do: Score.c(Points, next_point_score(a), b) |> normalize_score
  def score_point2(Score.c(Points, a, b), Player.b),                          do: Score.c(Points, a, next_point_score(b)) |> normalize_score
  def score_point2(score=Score.c(Game, _), _point_player),                    do: IO.puts "Game is over #{inspect score}"


  defp next_point_score(%PlayerPoints{}=point) do
    PlayerPoints.case point do
      Love    -> PlayerPoints.c Fifteen
      Fifteen -> PlayerPoints.c Thirty
      Thirty  -> PlayerPoints.c Forty
      Forty   -> raise "WAT?"
    end
  end

  defp normalize_score(%Score{}=score) do
    Score.case score, allow_underscore: true do
      Points in PlayerPoints.c(Forty), PlayerPoints.c(Forty) -> Score.c(Deuce)
      _ -> score
    end
  end
end
