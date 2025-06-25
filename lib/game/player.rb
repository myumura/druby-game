class Player
  attr_accessor :name, :role, :position, :rotation, :avatar, :caught, :escaped, :keys_collected

  def initialize(name, role, avatar)
    @name = name
    @role = role
    @avatar = avatar
    @position = [0.0, 0.0]
    @rotation = 0.0
    @caught = false
    @escaped = false
    @keys_collected = 0
  end

  def reset_position
    @position = [0.0, 0.0]
    @rotation = 0.0
    @caught = false
    @escaped = false
    @keys_collected = 0
  end

  def can_move?
    !@caught && !@escaped
  end

  def is_survivor?
    @role == 'survivor'
  end

  def is_hunter?
    @role == 'hunter'
  end

  def to_hash
    {
      role: @role,
      position: @position,
      rotation: @rotation,
      avatar: @avatar,
      caught: @caught,
      escaped: @escaped,
      keys_collected: @keys_collected
    }
  end
end
