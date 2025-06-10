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
    state = settings.game_server.get_game_state
    message = JSON.generate({
      type: 'game_state',
      state: {
        players: state[:players] || {},
        game_state: {
          keys_found: state[:game_state][:keys_found] || 0,
          total_keys: state[:game_state][:total_keys] || 0,
          time_remaining: state[:game_state][:time_remaining] || 0,
          game_started: state[:game_state][:game_started] || false,
          game_over: state[:game_state][:game_over] || false,
          winner: state[:game_state][:winner] || nil
        },
        keys: state[:keys] || [],
        obstacles: state[:obstacles] || [],
        escape_point: state[:escape_point] || [8, 8]
      }
    })
    settings.sockets.each do |socket|
      socket.send(message)
    end
  end

  get '/' do
    erb :index
  end

  get '/websocket' do
    if Faye::WebSocket.websocket?(request.env)
      ws = Faye::WebSocket.new(request.env)

      ws.on :open do |event|
        settings.sockets << ws
        # ゲームサーバーに接続
        if settings.game_server.nil?
          settings.game_server = DRbObject.new_with_uri('druby://localhost:8787')
        end
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)
        case data['type']
        when 'register'
          name = data['name']
          role = data['role']
          avatar = data['avatar']
          if settings.game_server.register_player(name, role, avatar)
            ws.send(JSON.generate({
              type: 'register_success',
              role: role
            }))
          else
            ws.send(JSON.generate({
              type: 'register_failed',
              message: 'Name already taken'
            }))
          end
        when 'move'
          name = data['name']
          position = data['position']
          rotation = data['rotation']
          settings.game_server.move_player(name, position, rotation)
        when 'reset'
          settings.game_server.reset
        end
      end

      ws.on :close do |event|
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