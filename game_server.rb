require 'drb/drb'
require 'colorize'
require 'json'

class GameServer
  def initialize
    @players = {}
    @game_state = {
      keys_found: 0,
      total_keys: 3,
      time_remaining: 300, # 5分
      game_started: false,
      game_over: false,
      winner: nil
    }
    @escape_point = generate_escape_point
    @obstacles = generate_obstacles
    @keys = generate_keys

    # タイマースレッドの開始
    @timer_thread = start_timer
  end

  def register_player(name, role, avatar)
    return false if @players[name]
    @players[name] = { 
      role: role, 
      position: [0.0, 0.0], 
      rotation: 0.0,
      avatar: avatar,
      caught: false,
      escaped: false,
      keys_collected: 0
    }
    # 最初のプレイヤーが登録された時にゲームを開始
    if @players.size == 1
      @game_state[:game_started] = true
      @game_state[:time_remaining] = 300
      broadcast_update
    end
    true
  end

  def move_player(name, position, rotation)
    return false unless @players[name]
    return false if @players[name][:caught] || @players[name][:escaped]
    
    # 移動範囲の制限
    return false if position[0].abs > 8 || position[1].abs > 8

    # 障害物との衝突チェック
    return false if @obstacles.any? do |obs|
      dx = position[0] - obs[:position][0]
      dz = position[1] - obs[:position][1]
      Math.sqrt(dx * dx + dz * dz) < 0.5 # プレイヤーと障害物の距離が0.5未満なら衝突
    end

    @players[name][:position] = position
    @players[name][:rotation] = rotation
    check_game_state
    broadcast_update
    true
  end

  def get_game_state
    state = {
      players: @players,
      game_state: {
        keys_found: @game_state[:keys_found],
        total_keys: @game_state[:total_keys],
        time_remaining: @game_state[:time_remaining],
        game_started: @game_state[:game_started],
        game_over: @game_state[:game_over],
        winner: @game_state[:winner]
      },
      keys: @keys,
      obstacles: @obstacles,
      escape_point: @escape_point
    }
    state
  end

  def reset
    @players = {}
    @game_state = {
      keys_found: 0,
      total_keys: 3,
      time_remaining: 300,
      game_started: false,
      game_over: false,
      winner: nil
    }
    @escape_point = generate_escape_point
    @obstacles = generate_obstacles
    @keys = generate_keys

    # タイマースレッドを再起動
    @timer_thread&.exit
    @timer_thread = start_timer

    broadcast_update
    true
  end

  def start_timer
    Thread.new do
      while true
        if @game_state[:game_started] && !@game_state[:game_over]
          @game_state[:time_remaining] -= 1
          if @game_state[:time_remaining] <= 0
            @game_state[:game_over] = true
            @game_state[:winner] = 'hunter'
          end
          broadcast_game_state
        end
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
    broadcast_update
  end

  def collect_key(name, key_id)
    return false unless @players[name]
    return false if @players[name][:caught] || @players[name][:escaped]
    return false if @players[name][:role] != 'survivor'

    key = @keys.find { |k| k[:id] == key_id }
    return false unless key
    return false if key[:found]

    key[:found] = true
    @players[name][:keys_collected] += 1
    @game_state[:keys_found] += 1
    broadcast_update
    true
  end

  def escape(name, position = nil)
    return false unless @players[name]
    return false if @players[name][:caught] || @players[name][:escaped]
    return false if @players[name][:role] != 'survivor'
    return false if @players[name][:keys_collected] < @game_state[:total_keys]

    # 脱出地点との距離をチェック
    pos = position || @players[name][:position]
    dx = pos[0].to_f - @escape_point[0].to_f
    dz = pos[1].to_f - @escape_point[1].to_f
    distance = Math.sqrt(dx * dx + dz * dz)
    
    return false if distance >= 1.0

    @players[name][:escaped] = true
    check_win_condition
    broadcast_update
    true
  end

  def check_win_condition
    survivors = @players.select { |_, p| p[:role] == 'survivor' }
    escaped = survivors.count { |_, p| p[:escaped] }
    caught = survivors.count { |_, p| p[:caught] }
    
    if escaped > 0
      @game_state[:game_over] = true
      @game_state[:winner] = 'survivors'
      broadcast_game_state
    elsif caught == survivors.size
      @game_state[:game_over] = true
      @game_state[:winner] = 'hunter'
      broadcast_game_state
    end
  end

  private

  def generate_escape_point
    # 外周の位置からランダムに選択（角を除く）
    positions = []
    (-7..7).each do |x|
      positions << [x, 7]  # 上辺
      positions << [x, -7] # 下辺
      positions << [7, x]  # 右辺
      positions << [-7, x] # 左辺
    end
    positions.sample
  end

  def generate_obstacles
    obstacles = []
    # 壁の生成
    (-8..8).each do |x|
      (-8..8).each do |y|
        # 外周の壁
        if x.abs == 8 || y.abs == 8
          obstacles << { position: [x, y], type: 'wall' }
        # ランダムな内部の壁（脱出地点の周りは障害物を配置しない）
        elsif rand < 0.1 && (x.abs < 7 && y.abs < 7)
          # 脱出地点の周り3マス以内には障害物を配置しない
          next if (@escape_point[0] - x).abs <= 3 && (@escape_point[1] - y).abs <= 3
          obstacles << { position: [x, y], type: 'wall' }
        end
      end
    end
    obstacles
  end

  def generate_keys
    keys = []
    while keys.size < @game_state[:total_keys]
      x = rand(-8..8)
      y = rand(-8..8)
      next if keys.any? { |k| k[:position] == [x, y] }
      next if [x, y] == @escape_point
      next if @obstacles.any? { |obs| obs[:position] == [x, y] }
      keys << { id: keys.size, position: [x, y], found: false }
    end
    keys
  end

  def check_game_state
    # 鍵の収集チェック
    @players.each do |name, player|
      next if player[:role] != 'survivor' || player[:caught] || player[:escaped]
      
      @keys.each do |key|
        if !key[:found]
          dx = player[:position][0] - key[:position][0]
          dz = player[:position][1] - key[:position][1]
          if Math.sqrt(dx * dx + dz * dz) < 0.5 # プレイヤーと鍵の距離が0.5未満なら取得
            key[:found] = true
            player[:keys_collected] += 1
            @game_state[:keys_found] += 1
          end
        end
      end

      # 脱出チェック
      dx = player[:position][0] - @escape_point[0]
      dz = player[:position][1] - @escape_point[1]
      if Math.sqrt(dx * dx + dz * dz) < 0.5 && player[:keys_collected] >= @game_state[:total_keys]
        player[:escaped] = true
        check_win_condition
      end
    end

    # 鬼が捕まえたかチェック
    @players.each do |hunter_name, hunter|
      next if hunter[:role] != 'hunter'
      
      @players.each do |survivor_name, survivor|
        next if survivor[:role] != 'survivor' || survivor[:caught] || survivor[:escaped]
        
        dx = hunter[:position][0] - survivor[:position][0]
        dz = hunter[:position][1] - survivor[:position][1]
        if Math.sqrt(dx * dx + dz * dz) < 0.5 # プレイヤー間の距離が0.5未満なら捕まえた
          survivor[:caught] = true
          check_win_condition
        end
      end
    end
  end

  def broadcast_update
    # 実際の実装では、ここでクライアントに更新を通知
  end
end

# DRubyサーバーの起動
server = GameServer.new
DRb.start_service('druby://localhost:8787', server)
puts "Game server started on druby://localhost:8787".green
DRb.thread.join 