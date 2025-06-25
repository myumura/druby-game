require 'sinatra'
require 'faye/websocket'
require 'drb/drb'
require 'json'
require_relative '../../lib/web/websocket_handler'

class WebApplication < Sinatra::Base
  set :server, 'puma'
  set :game_server, nil
  set :websocket_handler, nil
  set :views, File.join(File.dirname(__FILE__), '..', 'views')

  def self.initialize_game_connection
    settings.game_server = DRbObject.new_with_uri('druby://localhost:8787')
    settings.websocket_handler = WebSocketHandler.new(settings.game_server)
  end

  get '/' do
    erb :index
  end

  get '/websocket' do
    if Faye::WebSocket.websocket?(request.env)
      ws = Faye::WebSocket.new(request.env)

      ws.on :open do |event|
        # ゲームサーバーに接続（初回のみ）
        if settings.game_server.nil?
          self.class.initialize_game_connection
        end
        
        settings.websocket_handler.add_socket(ws)
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)
        settings.websocket_handler.handle_message(ws, data)
      end

      ws.on :close do |event|
        settings.websocket_handler.remove_socket(ws)
      end

      # Return async Rack response
      ws.rack_response
    end
  end

  # 定期的にゲーム状態を更新
  Thread.new do
    loop do
      if settings.websocket_handler
        settings.websocket_handler.broadcast_game_state
      end
      sleep 0.1
    end
  end
end
