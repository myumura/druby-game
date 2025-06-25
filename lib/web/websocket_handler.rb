require 'json'

class WebSocketHandler
  def initialize(game_server)
    @game_server = game_server
    @sockets = []
  end

  def add_socket(socket)
    @sockets << socket
  end

  def remove_socket(socket)
    @sockets.delete(socket)
  end

  def handle_message(socket, data)
    case data['type']
    when 'register'
      handle_register(socket, data)
    when 'move'
      handle_move(data)
    when 'collect_key'
      handle_collect_key(data)
    when 'escape'
      handle_escape(data)
    when 'reset'
      handle_reset
    end
  end

  def broadcast_game_state
    return if @game_server.nil?
    
    state = @game_server.get_game_state
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
    
    @sockets.each do |socket|
      socket.send(message)
    end
  end

  private

  def handle_register(socket, data)
    name = data['name']
    role = data['role']
    avatar = data['avatar']
    
    if @game_server.register_player(name, role, avatar)
      socket.send(JSON.generate({
        type: 'register_success',
        role: role
      }))
    else
      socket.send(JSON.generate({
        type: 'register_failed',
        message: 'Name already taken'
      }))
    end
  end

  def handle_move(data)
    name = data['name']
    position = data['position']
    rotation = data['rotation']
    @game_server.move_player(name, position, rotation)
  end

  def handle_collect_key(data)
    name = data['name']
    key_id = data['key_id']
    @game_server.collect_key(name, key_id)
  end

  def handle_escape(data)
    name = data['name']
    position = data['position']
    @game_server.escape(name, position)
  end

  def handle_reset
    @game_server.reset
  end
end
