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
    
    # 外周の壁
    (-8..8).each do |x|
      (-8..8).each do |y|
        if x.abs == 8 || y.abs == 8
          obstacles << { position: [x, y], type: 'wall' }
        end
      end
    end
    
    # 複雑な迷路パターンの生成
    generate_maze_pattern(obstacles)
    
    obstacles
  end

  def generate_maze_pattern(obstacles)
    # 大きな部屋を作る（中央エリア）
    create_central_rooms(obstacles)
    
    # 十字型の主要通路
    create_cross_corridors(obstacles)
    
    # L字型の複雑な通路
    create_l_shaped_corridors(obstacles)
    
    # 行き止まりの作成
    create_dead_ends(obstacles)
    
    # ランダムな追加障害物
    add_random_obstacles(obstacles)
  end

  def create_central_rooms(obstacles)
    # 中央に2つの部屋を作る
    # 部屋1: (-2,-2) to (0,0)
    (-2..0).each do |x|
      obstacles << { position: [x, -2], type: 'wall' }
      obstacles << { position: [x, 0], type: 'wall' }
    end
    [-2, 0].each do |y|
      obstacles << { position: [-2, y], type: 'wall' }
      obstacles << { position: [0, y], type: 'wall' }
    end
    
    # 部屋2: (1,1) to (3,3)
    (1..3).each do |x|
      obstacles << { position: [x, 1], type: 'wall' }
      obstacles << { position: [x, 3], type: 'wall' }
    end
    [1, 3].each do |y|
      obstacles << { position: [1, y], type: 'wall' }
      obstacles << { position: [3, y], type: 'wall' }
    end
  end

  def create_cross_corridors(obstacles)
    # 垂直な壁（通路を作る）
    [-5, -3, 2, 5].each do |x|
      (-6..6).each do |y|
        next if y.abs <= 1 # 中央は通路として残す
        next if near_escape_point?([x, y], 2)
        obstacles << { position: [x, y], type: 'wall' }
      end
    end
    
    # 水平な壁（通路を作る）
    [-4, 4].each do |y|
      (-6..6).each do |x|
        next if x.abs <= 2 # 中央は通路として残す
        next if near_escape_point?([x, y], 2)
        obstacles << { position: [x, y], type: 'wall' }
      end
    end
  end

  def create_l_shaped_corridors(obstacles)
    # L字型の障害物パターン
    l_patterns = [
      # パターン1: 左上のL字
      [[-6, -5], [-6, -4], [-6, -3], [-5, -3], [-4, -3]],
      # パターン2: 右下のL字
      [[4, 4], [5, 4], [6, 4], [6, 5], [6, 6]],
      # パターン3: 左下のL字
      [[-6, 5], [-6, 6], [-5, 6], [-4, 6], [-3, 6]],
      # パターン4: 右上のL字
      [[6, -6], [6, -5], [5, -5], [4, -5], [3, -5]]
    ]
    
    l_patterns.each do |pattern|
      pattern.each do |pos|
        next if near_escape_point?(pos, 2)
        obstacles << { position: pos, type: 'wall' }
      end
    end
  end

  def create_dead_ends(obstacles)
    # 行き止まりを作る
    dead_end_patterns = [
      # 上部の行き止まり
      [[-1, -6], [0, -6], [1, -6], [0, -5]],
      # 下部の行き止まり
      [[-1, 6], [0, 6], [1, 6], [0, 5]],
      # 左側の行き止まり
      [[-7, -1], [-7, 0], [-7, 1], [-6, 0]],
      # 右側の行き止まり
      [[7, -1], [7, 0], [7, 1], [6, 0]]
    ]
    
    dead_end_patterns.each do |pattern|
      pattern.each do |pos|
        next if near_escape_point?(pos, 1)
        obstacles << { position: pos, type: 'wall' }
      end
    end
  end

  def add_random_obstacles(obstacles)
    # 追加のランダム障害物（密度を上げる）
    50.times do
      x = rand(-7..7)
      y = rand(-7..7)
      
      # 既存の障害物と重複しないかチェック
      next if obstacles.any? { |obs| obs[:position] == [x, y] }
      # 脱出地点の近くは避ける
      next if near_escape_point?([x, y], 2)
      # スタート地点の近くは避ける
      next if x.abs <= 1 && y.abs <= 1
      
      # 30%の確率で配置
      if rand < 0.3
        obstacles << { position: [x, y], type: 'wall' }
      end
    end
  end

  def near_escape_point?(position, distance)
    return false unless @escape_point
    dx = (@escape_point[0] - position[0]).abs
    dy = (@escape_point[1] - position[1]).abs
    dx <= distance && dy <= distance
  end

  def generate_keys
    keys = []
    
    # 戦略的な鍵の配置位置を定義
    strategic_positions = [
      # 行き止まりの奥
      [-1, -5], [1, 5], [-6, -1], [6, 1],
      # 部屋の中
      [-1, -1], [2, 2],
      # 角の近く（危険な場所）
      [-6, -6], [6, 6], [-6, 6], [6, -6],
      # 通路の途中（見つけやすいが危険）
      [0, -3], [0, 3], [-4, 0], [4, 0],
      # L字コーナーの内側
      [-5, -4], [5, 5], [-5, 5], [5, -4]
    ]
    
    # 利用可能な位置をフィルタリング
    available_positions = strategic_positions.select do |pos|
      # 障害物と重複しない
      !@obstacles.any? { |obs| obs[:position] == pos } &&
      # 脱出地点と重複しない
      pos != @escape_point &&
      # 脱出地点から適度に離れている
      !near_escape_point?(pos, 1)
    end
    
    # 戦略的位置から鍵を配置
    @game_state[:total_keys].times do |i|
      if available_positions.any?
        # 戦略的位置から選択
        position = available_positions.sample
        available_positions.delete(position)
        keys << { id: i, position: position, found: false }
      else
        # 戦略的位置が足りない場合はランダム配置
        loop do
          x = rand(-7..7)
          y = rand(-7..7)
          position = [x, y]
          
          next if keys.any? { |k| k[:position] == position }
          next if position == @escape_point
          next if @obstacles.any? { |obs| obs[:position] == position }
          next if near_escape_point?(position, 1)
          next if x.abs <= 1 && y.abs <= 1 # スタート地点から離す
          
          keys << { id: i, position: position, found: false }
          break
        end
      end
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
