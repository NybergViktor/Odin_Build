package main

import "core:fmt"
import "core:time"
import "../src/engine"
import "../src/game"
import "../src/util"

// Game constants
WINDOW_WIDTH  :: 800
WINDOW_HEIGHT :: 600
PLAYER_SIZE   :: 50
PLAYER_SPEED  :: 300.0 // pixels per second

// Game state
GameState :: struct {
    player:     game.Player,
    play_area:  util.Rectangle,
    running:    bool,
    last_time:  time.Time,
}

game_state: GameState

// Initialize the game
init_game :: proc() -> bool {
    // Initialize renderer
    if !engine.init_renderer(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin Rectangle Game") {
        fmt.println("Failed to initialize renderer")
        return false
    }
    
    // Initialize input
    engine.init_input()
    
    // Create player in center of screen
    player_x := f32(WINDOW_WIDTH / 2 - PLAYER_SIZE / 2)
    player_y := f32(WINDOW_HEIGHT / 2 - PLAYER_SIZE / 2)
    game_state.player = game.create_player(player_x, player_y, PLAYER_SIZE, PLAYER_SIZE, PLAYER_SPEED)
    
    // Define play area (entire window)
    game_state.play_area = util.rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    game_state.running = true
    game_state.last_time = time.now()
    
    return true
}

// Update game logic
update_game :: proc() {
    // Calculate delta time
    current_time := time.now()
    dt := f32(time.duration_seconds(time.diff(game_state.last_time, current_time)))
    game_state.last_time = current_time
    
    // Cap delta time to prevent large jumps
    if dt > 1.0/30.0 { // Cap at 30 FPS minimum
        dt = 1.0/30.0
    }
    
    // Update input
    engine.update_input()
    
    // Check for exit
    if engine.is_escape_pressed() || engine.should_close() {
        game_state.running = false
        return
    }
    
    // Update player
    game.update_player(&game_state.player, game_state.play_area, dt)
}

// Render the game
render_game :: proc() {
    // Clear screen to dark gray
    engine.clear_screen(50, 50, 50)
    
    // Render player
    game.render_player(&game_state.player)
    
    // Present frame
    engine.present()
}

// Cleanup resources
cleanup_game :: proc() {
    engine.cleanup_renderer()
}

// Main entry point
main :: proc() {
    fmt.println("Starting Odin Rectangle Game...")
    
    // Initialize game
    if !init_game() {
        fmt.println("Failed to initialize game")
        return
    }
    
    defer cleanup_game()
    
    fmt.println("Game initialized successfully!")
    fmt.println("Use arrow keys to move the rectangle")
    fmt.println("Press ESC to exit")
    
    // Main game loop
    for game_state.running {
        update_game()
        render_game()
        
        // Small delay to prevent using 100% CPU
        time.sleep(time.Millisecond)
    }
    
    fmt.println("Game ended. Thanks for playing!")
}
