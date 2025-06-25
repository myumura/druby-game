require_relative 'player'
require_relative 'game_state'
require_relative 'maze_generator'

class GameLogic
  attr_reader :players, :game_state, :keys, :obstacles, :escape_point

  def initialize
    @players = {}
    @game_state = GameState.new
    @escape_point = MazeGenerator.generate_escape_point
    @obstacles = MazeGenerator.generate_obstacles
    @keys = MazeGenerator.generate_keys(@game_state.total_keys, @obstacles, @escape_point)
  end

  def register_player(name, role, avatar)
    return false if @players[name]
    
    @players[name] = Player.new(name, role, avatar)
    
    # 最初のプレイヤーが登録された時にゲームを開始
    if @players.size == 1
      @game_state.game_started = true
      @game_state.time_remaining = 300
    end
    
    true
  end

  def move_player(name, position, rotation)
    player = @players[name]
    return false unless player
    return false unless player.can_move?
    
    # 移動範囲の制限
    return false if position[0].abs > 8 || position[1].abs > 8

    # 障害物との衝突チェック
    return false if collision_with_obstacles?(position)

    player.position = position
    player.rotation = rotation
    check_game_state
    true
  end

  def collect_key(name, key_id)
    player = @players[name]
    return false unless player
    return false unless player.can_move?
    return false unless player.is_survivor?

    key = @keys.find { |k| k[:id] == key_id }
    return false unless key
    return false if key[:found]

    key[:found] = true
    player.keys_collected += 1
    @game_state.keys_found += 1
    true
  end

  def escape(name, position = nil)
    player = @players[name]
    return false unless player
    return false unless player.can_move?
    return false unless player.is_survivor?
    return false if player.keys_collected < @game_state.total_keys

    # 脱出地点との距離をチェック
    pos = position || player.position
    distance = calculate_distance(pos, @escape_point)
    
    return false if distance >= 1.0

    player.escaped = true
    check_win_condition
    true
  end

  def reset
    @players = {}
    @game_state.reset
    @escape_point = MazeGenerator.generate_escape_point
    @obstacles = MazeGenerator.generate_obstacles
    @keys = MazeGenerator.generate_keys(@game_state.total_keys, @obstacles, @escape_point)
    true
  end

  def get_game_state
    {
      players: @players.transform_values(&:to_hash),
      game_state: @game_state.to_hash,
      keys: @keys,
      obstacles: @obstacles,
      escape_point: @escape_point
    }
  end

  def update_timer
    if @game_state.game_started && !@game_state.game_over
      @game_state.time_remaining -= 1
      if @game_state.time_remaining <= 0
        @game_state.game_over = true
        @game_state.winner = 'hunter'
      end
    end
  end

  private

  def collision_with_obstacles?(position)
    @obstacles.any? do |obs|
      dx = position[0] - obs[:position][0]
      dz = position[1] - obs[:position][1]
      Math.sqrt(dx * dx + dz * dz) < 0.5
    end
  end

  def calculate_distance(pos1, pos2)
    dx = pos1[0].to_f - pos2[0].to_f
    dz = pos1[1].to_f - pos2[1].to_f
    Math.sqrt(dx * dx + dz * dz)
  end

  def check_game_state
    # 鍵の収集チェック
    @players.each do |name, player|
      next unless player.is_survivor? && player.can_move?
      
      @keys.each do |key|
        if !key[:found]
          distance = calculate_distance(player.position, key[:position])
          if distance < 0.5
            key[:found] = true
            player.keys_collected += 1
            @game_state.keys_found += 1
          end
        end
      end

      # 脱出チェック
      if player.keys_collected >= @game_state.total_keys
        distance = calculate_distance(player.position, @escape_point)
        if distance < 0.5
          player.escaped = true
          check_win_condition
        end
      end
    end

    # 鬼が捕まえたかチェック
    hunters = @players.select { |_, p| p.is_hunter? }
    survivors = @players.select { |_, p| p.is_survivor? }

    hunters.each do |_, hunter|
      survivors.each do |_, survivor|
        next if survivor.caught || survivor.escaped
        
        distance = calculate_distance(hunter.position, survivor.position)
        if distance < 0.5
          survivor.caught = true
          check_win_condition
        end
      end
    end
  end

  def check_win_condition
    survivors = @players.select { |_, p| p.is_survivor? }
    escaped = survivors.count { |_, p| p.escaped }
    caught = survivors.count { |_, p| p.caught }
    
    if escaped > 0
      @game_state.game_over = true
      @game_state.winner = 'survivors'
    elsif caught == survivors.size
      @game_state.game_over = true
      @game_state.winner = 'hunter'
    end
  end
end
