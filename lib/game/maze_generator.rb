class MazeGenerator
  def self.generate_escape_point
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

  def self.generate_obstacles
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

  def self.generate_keys(total_keys, obstacles, escape_point)
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
      !obstacles.any? { |obs| obs[:position] == pos } &&
      # 脱出地点と重複しない
      pos != escape_point &&
      # 脱出地点から適度に離れている
      !near_escape_point?(pos, escape_point, 1)
    end
    
    # 戦略的位置から鍵を配置
    total_keys.times do |i|
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
          next if position == escape_point
          next if obstacles.any? { |obs| obs[:position] == position }
          next if near_escape_point?(position, escape_point, 1)
          next if x.abs <= 1 && y.abs <= 1 # スタート地点から離す
          
          keys << { id: i, position: position, found: false }
          break
        end
      end
    end
    
    keys
  end

  private

  def self.generate_maze_pattern(obstacles)
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

  def self.create_central_rooms(obstacles)
    # 中央に2つの部屋を作る
    # プレイヤーの初期位置[0,0]周辺は空けておく
    
    # 部屋1: (-3,-3) to (-1,-1) - 初期位置から離れた場所
    (-3..-1).each do |x|
      obstacles << { position: [x, -3], type: 'wall' }
      obstacles << { position: [x, -1], type: 'wall' }
    end
    [-3, -1].each do |y|
      obstacles << { position: [-3, y], type: 'wall' }
      obstacles << { position: [-1, y], type: 'wall' }
    end
    
    # 部屋2: (2,2) to (4,4) - 初期位置から離れた場所
    (2..4).each do |x|
      obstacles << { position: [x, 2], type: 'wall' }
      obstacles << { position: [x, 4], type: 'wall' }
    end
    [2, 4].each do |y|
      obstacles << { position: [2, y], type: 'wall' }
      obstacles << { position: [4, y], type: 'wall' }
    end
  end

  def self.create_cross_corridors(obstacles)
    # 垂直な壁（通路を作る）
    [-5, -3, 2, 5].each do |x|
      (-6..6).each do |y|
        next if y.abs <= 1 # 中央は通路として残す
        obstacles << { position: [x, y], type: 'wall' }
      end
    end
    
    # 水平な壁（通路を作る）
    [-4, 4].each do |y|
      (-6..6).each do |x|
        next if x.abs <= 2 # 中央は通路として残す
        obstacles << { position: [x, y], type: 'wall' }
      end
    end
  end

  def self.create_l_shaped_corridors(obstacles)
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
        obstacles << { position: pos, type: 'wall' }
      end
    end
  end

  def self.create_dead_ends(obstacles)
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
        obstacles << { position: pos, type: 'wall' }
      end
    end
  end

  def self.add_random_obstacles(obstacles)
    # 追加のランダム障害物（密度を上げる）
    50.times do
      x = rand(-7..7)
      y = rand(-7..7)
      
      # 既存の障害物と重複しないかチェック
      next if obstacles.any? { |obs| obs[:position] == [x, y] }
      # スタート地点[0,0]の近くは確実に避ける（より広い範囲）
      next if x.abs <= 1 && y.abs <= 1
      # 初期位置[0,0]そのものは絶対に避ける
      next if x == 0 && y == 0
      
      # 30%の確率で配置
      if rand < 0.3
        obstacles << { position: [x, y], type: 'wall' }
      end
    end
  end

  def self.near_escape_point?(position, escape_point, distance)
    return false unless escape_point
    dx = (escape_point[0] - position[0]).abs
    dy = (escape_point[1] - position[1]).abs
    dx <= distance && dy <= distance
  end
end
