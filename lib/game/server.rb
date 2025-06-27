require 'drb/drb'
require 'colorize'
require 'json'
require_relative 'game_logic'

class GameServer
  def initialize
    @game_logic = GameLogic.new
    @timer_thread = start_timer
  end

  def register_player(name, role, avatar)
    result = @game_logic.register_player(name, role, avatar)
    result
  end

  def move_player(name, position, rotation)
    result = @game_logic.move_player(name, position, rotation)
    result
  end

  def get_game_state
    @game_logic.get_game_state
  end

  def reset
    @timer_thread&.exit
    @game_logic.reset
    @timer_thread = start_timer
    true
  end

  def collect_key(name, key_id)
    result = @game_logic.collect_key(name, key_id)
    result
  end

  def escape(name, position = nil)
    result = @game_logic.escape(name, position)
    result
  end

  private

  def start_timer
    Thread.new do
      while true
        @game_logic.update_timer
        broadcast_game_state
        sleep 1
      end
    end.tap { |t| t.abort_on_exception = true }
  end

  def broadcast_game_state
    state = get_game_state
    message = JSON.generate({
      type: 'game_state',
      state: state
    })
  end
end
