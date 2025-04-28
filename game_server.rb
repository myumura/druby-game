require 'drb/drb'
require 'colorize'

class GameServer
  def initialize
    @players = {}
    @game_state = {
      treasures_found: 0,
      total_treasures: 3,
      obstacles_cleared: 0,
      total_obstacles: 5
    }
    @treasures = generate_treasures
    @obstacles = generate_obstacles
    puts "Initial game state:".green
    puts "Treasures: #{@treasures.inspect}"
    puts "Obstacles: #{@obstacles.inspect}"
  end

  def register_player(name, role, avatar)
    return false if @players[name]
    @players[name] = { role: role, position: [0, 0], avatar: avatar }
    broadcast_update
    true
  end

  def move_player(name, direction)
    return false unless @players[name]
    
    case direction
    when 'up'
      @players[name][:position][1] += 1
    when 'down'
      @players[name][:position][1] -= 1
    when 'left'
      @players[name][:position][0] -= 1
    when 'right'
      @players[name][:position][0] += 1
    end

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
        total_obstacles: @game_state[:total_obstacles]
      },
      obstacles: @obstacles,
      treasures: @treasures
    }
    puts "Sending game state: #{state.inspect}"
    state
  end

  def reset
    @players = {}
    @game_state = {
      treasures_found: 0,
      total_treasures: 3,
      obstacles_cleared: 0,
      total_obstacles: 5
    }
    @treasures = generate_treasures
    @obstacles = generate_obstacles
    puts "Game reset:".green
    puts "Treasures: #{@treasures.inspect}"
    puts "Obstacles: #{@obstacles.inspect}"
    broadcast_update
    true
  end

  private

  def generate_treasures
    treasures = []
    while treasures.size < @game_state[:total_treasures]
      x = rand(-5..5)
      y = rand(-5..5)
      # 他の宝と重ならないようにする
      next if treasures.any? { |t| t[:position] == [x, y] }
      treasures << { position: [x, y], found: false }
    end
    treasures
  end

  def generate_obstacles
    obstacles = []
    while obstacles.size < @game_state[:total_obstacles]
      x = rand(-5..5)
      y = rand(-5..5)
      # 宝の位置と重ならないようにする
      next if @treasures.any? { |t| t[:position] == [x, y] }
      # 他の障害物と重ならないようにする
      next if obstacles.any? { |obs| obs[:position] == [x, y] }
      obstacles << { position: [x, y], cleared: false }
    end
    obstacles
  end

  def check_game_state
    # プレイヤーが宝の位置にいるかチェック
    @players.each do |name, player|
      if player[:role] == 'explorer'
        @treasures.each do |treasure|
          if treasure[:position] == player[:position] && !treasure[:found]
            treasure[:found] = true
            @game_state[:treasures_found] += 1
            puts "Treasure found by #{name} at position #{treasure[:position]}"
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
            puts "Obstacle cleared by #{name} at position #{obstacle[:position]}"
          end
        end
      end
    end
  end

  def broadcast_update
    # 実際の実装では、ここでクライアントに更新を通知
    puts "Game state updated:".green
    puts "Players: #{@players}"
    puts "Game state: #{@game_state}"
    puts "Obstacles: #{@obstacles}"
    puts "Treasures: #{@treasures}"
  end
end

# DRubyサーバーの起動
server = GameServer.new
DRb.start_service('druby://localhost:8787', server)
puts "Game server started on druby://localhost:8787".green
DRb.thread.join 