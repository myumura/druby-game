require 'sinatra'
require 'faye/websocket'
require 'drb/drb'
require 'json'

class WebGame < Sinatra::Base
  set :server, 'puma'
  set :sockets, []
  set :game_server, nil

  # ゲーム状態の更新をクライアントに送信
  def self.broadcast_game_state
    return if settings.game_server.nil?
    begin
      state = settings.game_server.get_game_state
      puts "Broadcasting game state: #{state.inspect}"
      message = JSON.generate({
        type: 'game_state',
        state: {
          players: state[:players] || {},
          game_state: {
            treasures_found: state[:game_state][:treasures_found] || 0,
            total_treasures: state[:game_state][:total_treasures] || 0,
            obstacles_cleared: state[:game_state][:obstacles_cleared] || 0,
            total_obstacles: state[:game_state][:total_obstacles] || 0
          },
          obstacles: state[:obstacles] || [],
          treasures: state[:treasures] || []
        }
      })
      settings.sockets.each do |socket|
        socket.send(message)
      end
    rescue => e
      puts "Error broadcasting game state: #{e.message}"
      puts e.backtrace
    end
  end

  get '/' do
    erb :index
  end

  get '/websocket' do
    if Faye::WebSocket.websocket?(request.env)
      puts "New WebSocket connection request"
      ws = Faye::WebSocket.new(request.env)

      ws.on :open do |event|
        puts "WebSocket connection opened"
        settings.sockets << ws
        # ゲームサーバーに接続
        if settings.game_server.nil?
          puts "Connecting to game server..."
          settings.game_server = DRbObject.new_with_uri('druby://localhost:8787')
          puts "Connected to game server"
        end
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)
        puts "Received message: #{data.inspect}"
        case data['type']
        when 'register'
          name = data['name']
          role = data['role']
          avatar = data['avatar']
          if settings.game_server.register_player(name, role, avatar)
            puts "Player #{name} registered successfully as #{role} with avatar #{avatar}"
            ws.send(JSON.generate({
              type: 'register_success',
              role: role
            }))
          else
            puts "Player #{name} registration failed"
            ws.send(JSON.generate({
              type: 'register_failed',
              message: 'Name already taken'
            }))
          end
        when 'move'
          name = data['name']
          direction = data['direction']
          puts "Player #{name} moving #{direction}"
          settings.game_server.move_player(name, direction)
        when 'reset'
          puts "Resetting game state"
          settings.game_server.reset
        end
      end

      ws.on :close do |event|
        puts "WebSocket connection closed"
        settings.sockets.delete(ws)
      end

      # Return async Rack response
      ws.rack_response
    end
  end

  # 定期的にゲーム状態を更新
  Thread.new do
    loop do
      WebGame.broadcast_game_state
      sleep 0.1
    end
  end
end

# Sinatraアプリケーションを起動
WebGame.run! 