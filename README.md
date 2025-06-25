# 3D Maze Game

A real-time 3D multiplayer maze game built with Ruby, DRb, WebSocket, and Three.js where players take on the roles of Hunters and Survivors in a thrilling chase game.

## Features

- Real-time 3D multiplayer gameplay using Three.js
- Two player roles: Hunter and Survivor
- 3D maze environment with obstacles and walls
- Key collection and escape mechanics
- Real-time player movement and interactions
- Web-based 3D interface
- WebSocket for real-time updates
- Customizable avatars for both roles
- 5-minute gameplay timer
- Win/lose conditions for both roles

## Game Rules

### Survivors
- Collect all keys (3 keys) scattered in the maze
- Escape through the designated escape point
- Avoid being caught by the Hunter
- Win by escaping with all keys before time runs out

### Hunters
- Catch Survivors before they escape
- Win by catching all Survivors or when time runs out

### General Rules
- The game map is a 17x17 grid (coordinates from -8 to 8)
- Players start at position [0, 0]
- The game progresses with a 5-minute timer
- Players can move using arrow keys
- The map contains walls and obstacles that block movement
- The escape point is randomly placed on the outer edge of the maze

## Requirements

- Ruby 3.4.0 or later
- Bundler
- Modern web browser with WebGL support

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/druby-game.git
cd druby-game
```

2. Install dependencies:
```bash
bundle install
```

## Running the Game

1. Start the game server (DRb server on port 8787):
```bash
./bin/game_server
```

2. In a new terminal, start the web server (port 4567):
```bash
bundle exec rackup
```

3. Open your browser and navigate to:
```
http://localhost:4567
```

## How to Play

1. Enter your name
2. Choose your role:
   - Hunter: Try to catch Survivors
   - Survivor: Collect keys and escape
3. Select an avatar:
   - Hunters: Ghost, Zombie, or Vampire
   - Survivors: Person, Man, or Woman
4. Click "Join Game" to enter the game
5. Use arrow keys to move:
   - ↑: Move forward
   - ↓: Move backward
   - ←: Turn left
   - →: Turn right
6. As a Survivor:
   - Collect all 3 keys (💎)
   - Find the escape point
   - Avoid the Hunter
7. As a Hunter:
   - Catch Survivors
   - Prevent them from escaping

## Technical Details

### Libraries Used
- drb: Distributed Ruby object system for server-client communication
- sinatra: Web application framework
- sinatra-contrib: Additional Sinatra functionality
- faye-websocket: WebSocket support for real-time updates
- three.js: 3D graphics rendering
- puma: Web server
- rackup: Rack server launcher

### Architecture
- Game Server (Ruby/DRb): Manages game state, player positions, and game logic
  - Runs on port 8787
- Web Server (Sinatra): Serves the web interface and handles WebSocket connections
  - Runs on port 4567
- Client (JavaScript/Three.js): Renders 3D graphics and handles user input

## License

MIT License
