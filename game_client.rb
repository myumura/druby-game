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
  end

  def game_loop
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
    system('clear') || system('cls')
    display_map(state)
  end

  def display_map(state)    
    (@map_size-1).downto(-@map_size) do |y|
      print " |"
      (-@map_size).upto(@map_size) do |x|
        cell = get_cell_content(x, y, state)
        print cell
      end
    end
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