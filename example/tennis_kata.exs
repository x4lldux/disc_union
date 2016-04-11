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
    # Player A will always win!
    # All hail the victor!

    Score.zero_score
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
    |> Tennis.score_point(Player.a)
  end

  def next_point_score(%PlayerPoints{}=point) do
    PlayerPoints.case point do
                   Love    -> PlayerPoints.fifteen
                   Fifteen -> PlayerPoints.thirty
                   Thirty  -> PlayerPoints.forty
                   Forty   -> raise "WAT?"
          end
  end

  def normalize_score(%Score{}=score) do
    case score do               # defualt case (_) is not implemented yet, need to be a regular `case` here
      Score.points(PlayerPoints.forty, PlayerPoints.forty) -> Score.duce
      _ -> score
    end
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
end
