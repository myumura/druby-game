# DRuby Cooperative Game

A cooperative game built with Ruby, DRb, and WebSocket where players work together to find treasures and clear obstacles.

## Features

- Real-time multiplayer gameplay
- Two player roles: Explorer and Engineer
- Explorers can find treasures
- Engineers can clear obstacles
- Web-based interface
- WebSocket for real-time updates
- Customizable avatars
- Special items (speed boost, time boost, treasure radar, obstacle breaker)
- Timer feature (5-minute gameplay)
- Score system

## Requirements

- Ruby 3.4.0 or later
- Bundler

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

1. Start the game server:
```bash
ruby game_server.rb
```

2. In a new terminal, start the web server:
```bash
bundle exec rackup -s puma -p 4567
```

3. Open your browser and navigate to:
```
http://localhost:4567
```

4. (Optional) To use the console client, run in another terminal:
```bash
ruby game_client.rb
```

## How to Play

### Web Interface
1. Enter your name and choose a role (Explorer or Engineer)
2. Select an avatar
3. Click the "Join Game" button to enter the game
4. Use the arrow buttons on screen to move around the map
5. Explorers can find treasures (💎)
6. Engineers can clear obstacles (🪨, 🌳, 💧)
7. Collect special items (⚡, ⏰, 🔍, 💥) for bonuses

### Console Client
1. Enter your name and choose a role (explorer/engineer)
2. Use the arrow keys to move around the map
3. Press 'q' to quit the game

## Game Rules

- The game map is a 21x21 grid (coordinates from -10 to 10)
- Players start at position [0, 0]
- Treasures can only be found by Explorers
- Obstacles can only be cleared by Engineers
- The game progresses with a 5-minute timer
- The map contains 5 treasures and 8 obstacles
- Special items provide bonus effects when collected:
  - ⚡ Speed Boost: Move twice as fast for 10 seconds
  - ⏰ Time Boost: Add 30 seconds to the timer
  - 🔍 Treasure Radar: See all treasures on the map for 15 seconds
  - 💥 Obstacle Breaker: Clear all obstacles in a 3x3 area at once
- The game is won when all treasures are found and all obstacles are cleared
- The game is over when the timer reaches zero

## Libraries Used

- drb: Distributed Ruby object system
- colorize: Add colors to console output
- sinatra: Web application framework
- faye-websocket: WebSocket support
- json: JSON data processing
- puma: Web server

## License

MIT License
