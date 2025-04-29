require 'drb/drb'
require 'colorize'
require 'json'

class GameServer
  def initialize
    @players = {}
    @game_state = {
      treasures_found: 0,
      total_treasures: 5,
      obstacles_cleared: 0,
      total_obstacles: 8,
      time_remaining: 300, # 5分
      game_started: false, # 最初はfalse
      game_over: false
    }
    @treasures = generate_treasures
    @obstacles = generate_obstacles
    @special_items = generate_special_items

    # タイマースレッドの開始
    @timer_thread = start_timer
  end

  def register_player(name, role, avatar)
    return false if @players[name]
    @players[name] = { 
      role: role, 
      position: [0, 0], 
      avatar: avatar,
      score: 0,
      items: [],
      power_ups: []
    }
    # 最初のプレイヤーが登録された時にゲームを開始
    if @players.size == 1
      @game_state[:game_started] = true
      @game_state[:time_remaining] = 300 # タイマーをリセット
      broadcast_update
    end
    true
  end

  def move_player(name, direction)
    return false unless @players[name]
    
    # 移動前の位置を保存
    current_position = @players[name][:position].dup
    
    # 移動方向に応じて位置を更新
    case direction
    when 'up'
      new_position = [current_position[0], current_position[1] + 1]
    when 'down'
      new_position = [current_position[0], current_position[1] - 1]
    when 'left'
      new_position = [current_position[0] - 1, current_position[1]]
    when 'right'
      new_position = [current_position[0] + 1, current_position[1]]
    end

    # 障害物のチェック
    @obstacles.each do |obstacle|
      if obstacle[:position] == new_position && !obstacle[:cleared]
        return false
      end
    end

    # 障害物がない場合のみ移動を許可
    @players[name][:position] = new_position
    check_game_state
    broadcast_update
    true
  end

  def get_game_state
    state = {
      players: @players,
      game_state: {
        treasures_found: @game_state[:treasures_found],
        total_treasures: @game_state[:total_treasures],
        obstacles_cleared: @game_state[:obstacles_cleared],
        total_obstacles: @game_state[:total_obstacles],
        time_remaining: @game_state[:time_remaining],
        game_started: @game_state[:game_started],
        game_over: @game_state[:game_over]
      },
      obstacles: @obstacles,
      treasures: @treasures,
      special_items: @special_items
    }
    state
  end

  def reset
    @players = {}
    @game_state = {
      treasures_found: 0,
      total_treasures: 5,
      obstacles_cleared: 0,
      total_obstacles: 8,
      time_remaining: 300,
      game_started: false,
      game_over: false
    }
    @treasures = generate_treasures
    @obstacles = generate_obstacles
    @special_items = generate_special_items
    broadcast_update
    true
  end

  def start_timer
    puts "Starting timer thread..."
    Thread.new do
      while true
        if @game_state[:game_started] && !@game_state[:game_over]
          @game_state[:time_remaining] -= 1
          if @game_state[:time_remaining] <= 0
            @game_state[:game_over] = true
          end
          # WebSocketを通じてクライアントに状態を送信
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

  private

  def generate_treasures
    treasures = []
    while treasures.size < @game_state[:total_treasures]
      x = rand(-8..8)
      y = rand(-8..8)
      # 他の宝と重ならないようにする
      next if treasures.any? { |t| t[:position] == [x, y] }
      treasures << { position: [x, y], found: false, value: rand(100..500) }
    end
    treasures
  end

  def generate_obstacles
    obstacles = []
    while obstacles.size < @game_state[:total_obstacles]
      x = rand(-8..8)
      y = rand(-8..8)
      # 宝の位置と重ならないようにする
      next if @treasures.any? { |t| t[:position] == [x, y] }
      # 他の障害物と重ならないようにする
      next if obstacles.any? { |obs| obs[:position] == [x, y] }
      obstacles << { position: [x, y], cleared: false, type: ['rock', 'tree', 'water'].sample }
    end
    obstacles
  end

  def generate_special_items
    items = []
    item_types = [
      { type: 'speed_boost', duration: 10, effect: 'Move twice as fast' },
      { type: 'time_boost', duration: 30, effect: 'Add 30 seconds to the timer' },
      { type: 'treasure_radar', duration: 15, effect: 'See all treasures on the map' },
      { type: 'obstacle_breaker', duration: 1, effect: 'Clear all obstacles in a 3x3 area' }
    ]
    
    5.times do
      x = rand(-8..8)
      y = rand(-8..8)
      # 他のアイテムと重ならないようにする
      next if items.any? { |i| i[:position] == [x, y] }
      # 宝や障害物と重ならないようにする
      next if @treasures.any? { |t| t[:position] == [x, y] }
      next if @obstacles.any? { |o| o[:position] == [x, y] }
      
      item = item_types.sample.merge(position: [x, y], collected: false)
      items << item
    end
    items
  end

  def check_game_state
    # プレイヤーが宝の位置にいるかチェック
    @players.each do |name, player|
      if player[:role] == 'explorer'
        @treasures.each do |treasure|
          if treasure[:position] == player[:position] && !treasure[:found]
            treasure[:found] = true
            @game_state[:treasures_found] += 1
            player[:score] += treasure[:value]
          end
        end
      end
    end

    # 障害物がクリアされたかチェック
    @players.each do |name, player|
      if player[:role] == 'engineer'
        @obstacles.each do |obstacle|
          if obstacle[:position] == player[:position] && !obstacle[:cleared]
            obstacle[:cleared] = true
            @game_state[:obstacles_cleared] += 1
            player[:score] += 50
          end
        end
      end
    end

    # 特殊アイテムの取得をチェック
    @players.each do |name, player|
      @special_items.each do |item|
        if item[:position] == player[:position] && !item[:collected]
          item[:collected] = true
          player[:items] << item
          player[:score] += 100
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