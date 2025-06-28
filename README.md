# dRuby Maze Game

A real-time 3D multiplayer maze game built with Ruby, DRb, WebSocket, and Three.js. Players take on the roles of Hunters and Survivors in a thrilling chase game.

## Game Rules

- **Survivors**: Collect 3 keys（🔑） and escape through the exit point
- **Hunters**: Catch survivors before they escape
- **Controls**: Use arrow keys to move around the maze
- **Timer**: 5-minute game sessions

## Requirements

- Ruby 3.4.0 or later
- Bundler
- Modern web browser with WebGL support

## Installation

1. Clone the repository:
```bash
git clone https://github.com/myumura/druby-game.git
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
