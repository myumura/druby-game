require 'drb/drb'
require 'colorize'
require 'io/console'

class GameClient
  def initialize
    @server = DRbObject.new_with_uri('druby://localhost:8787')
    @name = nil
    @role = nil
    @map_size = 10  # マップのサイズ
  end

  def start
    puts "Welcome to the Cooperative Game!".green
    register_player
    game_loop
  end

  private

  def register_player
    print "Enter your name: "
    @name = gets.chomp
    print "Choose your role (explorer/engineer): "
    @role = gets.chomp.downcase

    until ['explorer', 'engineer'].include?(@role)
      print "Invalid role. Choose explorer or engineer: "
      @role = gets.chomp.downcase
    end

    if @server.register_player(@name, @role)
      puts "Successfully registered as #{@role}!".green
    else
      puts "Registration failed. Name might be taken.".red
      exit
    end
  end

  def game_loop
    puts "\nUse arrow keys to move, 'q' to quit".yellow
    loop do
      display_game_state
      input = get_arrow_key
      break if input == 'q'

      if ['up', 'down', 'left', 'right'].include?(input)
        @server.move_player(@name, input)
      end
    end
  end

  def get_arrow_key
    char = STDIN.getch
    case char
    when "\e"  # Escape sequence
      case STDIN.getch
      when "["
        case STDIN.getch
        when "A" then "up"
        when "B" then "down"
        when "C" then "right"
        when "D" then "left"
        end
      end
    when "q" then "q"
    end
  end

  def display_game_state
    state = @server.get_game_state
    system('clear') || system('cls')  # 画面をクリア
    puts "\nCurrent Game State:".blue
    display_map(state)
    puts "\nPlayers:"
    state[:players].each do |name, player|
      puts "  #{name} (#{player[:role]}) at position #{player[:position]}"
    end
    puts "\nGame Progress:"
    puts "  Treasure found: #{state[:game_state][:treasure_found]}"
    puts "  Obstacles cleared: #{state[:game_state][:obstacles_cleared]}/#{state[:game_state][:total_obstacles]}"
    puts "\nUse arrow keys to move, 'q' to quit".yellow
  end

  def display_map(state)
    puts "\nMap:".yellow
    puts "  " + "=" * (@map_size * 2 + 1)
    
    (@map_size-1).downto(-@map_size) do |y|
      print " |"
      (-@map_size).upto(@map_size) do |x|
        cell = get_cell_content(x, y, state)
        print cell
      end
      puts "|"
    end
    
    puts "  " + "=" * (@map_size * 2 + 1)
    puts "\nLegend:"
    puts "  P: Player"
    puts "  T: Treasure"
    puts "  O: Obstacle"
    puts "  .: Empty space"
  end

  def get_cell_content(x, y, state)
    # プレイヤーの位置をチェック
    state[:players].each do |name, player|
      if player[:position] == [x, y]
        return "P".green
      end
    end

    # 宝の位置
    if [x, y] == [5, 5]
      return "T".yellow
    end

    # 障害物の位置
    if state[:obstacles] && state[:obstacles].any? { |obs| obs[:position] == [x, y] && !obs[:cleared] }
      return "O".red
    end

    # 空のマス
    " ."
  end
end

# クライアントの起動
client = GameClient.new
client.start 