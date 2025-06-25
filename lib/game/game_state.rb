class GameState
  attr_accessor :keys_found, :total_keys, :time_remaining, :game_started, :game_over, :winner

  def initialize
    @keys_found = 0
    @total_keys = 3
    @time_remaining = 300 # 5分
    @game_started = false
    @game_over = false
    @winner = nil
  end

  def reset
    @keys_found = 0
    @total_keys = 3
    @time_remaining = 300
    @game_started = false
    @game_over = false
    @winner = nil
  end

  def to_hash
    {
      keys_found: @keys_found,
      total_keys: @total_keys,
      time_remaining: @time_remaining,
      game_started: @game_started,
      game_over: @game_over,
      winner: @winner
    }
  end
end
