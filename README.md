# DRuby Cooperative Game

A cooperative game built with Ruby, DRb, and WebSocket where players work together to find treasures and clear obstacles.

## Features

- Real-time multiplayer gameplay
- Two player roles: Explorer and Engineer
- Explorers can find treasures
- Engineers can clear obstacles
- Web-based interface
- WebSocket for real-time updates

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

## How to Play

1. Enter your name and choose a role (Explorer or Engineer)
2. Use the arrow keys to move around the map
3. Explorers can find treasures (marked as 'T')
4. Engineers can clear obstacles (marked as 'O')
5. Work together to find all treasures and clear all obstacles

## Game Rules

- The game map is a 21x21 grid
- Players start at position [0, 0]
- Treasures can only be found by Explorers
- Obstacles can only be cleared by Engineers
- The game is won when all treasures are found and all obstacles are cleared

## License

MIT License 