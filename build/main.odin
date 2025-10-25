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

// Game mode enumeration
GameMode :: enum {
    PLAYING,
    VICTORY,
    DEFEAT,
}

// Game state
GameState :: struct {
    player:     game.Player,
    enemy:      game.Enemy,
    play_area:  util.Rectangle,
    obstacle:   util.Obstacle,
    running:    bool,
    last_time:  time.Time,
    mode:       GameMode,
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
    
    // Create enemy in random position
    enemy_x := f32(100)
    enemy_y := f32(100)
    game_state.enemy = game.create_enemy(enemy_x, enemy_y, 60, 40) // Slightly larger than player
    
    // Define play area (entire window)
    game_state.play_area = util.rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    
    // Create obstacle in center
    obstacle_width: f32 = 100
    obstacle_height: f32 = 100
    obstacle_x := f32(WINDOW_WIDTH/2 - obstacle_width/2)
    obstacle_y := f32(WINDOW_HEIGHT/2 - obstacle_height/2)
    game_state.obstacle = util.Obstacle{
        rect = util.rect(obstacle_x, obstacle_y, obstacle_width, obstacle_height),
        color = {100, 100, 100}, // Gray
    }
    
    game_state.running = true
    game_state.last_time = time.now()
    game_state.mode = .PLAYING
    
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
    
    switch game_state.mode {
    case .PLAYING:
        // Update player (with enemy collision)
        game.update_player(&game_state.player, game_state.play_area, &game_state.enemy, dt)
        
        // Update enemy (with player collision)
        game.update_enemy(&game_state.enemy, game_state.play_area, &game_state.player, dt)
        
        // Update enemy projectiles
        game.update_enemy_projectiles(&game_state.enemy, &game_state.player, &game_state.obstacle, dt)
        
        // Update projectiles with collision detection
        game.update_projectiles(&game_state.player, game_state.play_area, &game_state.enemy, &game_state.obstacle, dt)
        
        // Check if enemy is dead
        if !game.is_enemy_alive(&game_state.enemy) {
            game_state.mode = .VICTORY
        }
        
        // Check if player is dead
        if !game.is_player_alive(&game_state.player) {
            game_state.mode = .DEFEAT
        }
        
    case .VICTORY:
        // Check for restart (left click on restart button area)
        if engine.is_left_mouse_clicked() {
            mouse_x, mouse_y := engine.get_mouse_pos()
            button_x := f32(WINDOW_WIDTH/2 - 60)
            button_y := f32(WINDOW_HEIGHT/2 + 50)
            button_width: f32 = 120
            button_height: f32 = 40
            
            if f32(mouse_x) >= button_x && f32(mouse_x) <= button_x + button_width &&
               f32(mouse_y) >= button_y && f32(mouse_y) <= button_y + button_height {
                restart_game()
            }
        }
    
    case .DEFEAT:
        // Check for restart (left click on restart button area)
        if engine.is_left_mouse_clicked() {
            mouse_x, mouse_y := engine.get_mouse_pos()
            button_x := f32(WINDOW_WIDTH/2 - 60)
            button_y := f32(WINDOW_HEIGHT/2 + 50)
            button_width: f32 = 120
            button_height: f32 = 40
            
            if f32(mouse_x) >= button_x && f32(mouse_x) <= button_x + button_width &&
               f32(mouse_y) >= button_y && f32(mouse_y) <= button_y + button_height {
                restart_game()
            }
        }
    }
}

// Restart the game
restart_game :: proc() {
    // Reset player
    player_x := f32(WINDOW_WIDTH / 2 - PLAYER_SIZE / 2)
    player_y := f32(WINDOW_HEIGHT / 2 - PLAYER_SIZE / 2)
    game_state.player = game.create_player(player_x, player_y, PLAYER_SIZE, PLAYER_SIZE, PLAYER_SPEED)
    
    // Reset enemy
    enemy_x := f32(100)
    enemy_y := f32(100)
    game_state.enemy = game.create_enemy(enemy_x, enemy_y, 60, 40)
    
    // Reset game mode
    game_state.mode = .PLAYING
}

// Render the game
render_game :: proc() {
    // Clear screen to dark gray
    engine.clear_screen(50, 50, 50)
    
    switch game_state.mode {
    case .PLAYING:
        // Render player
        game.render_player(&game_state.player)
        
        // Render obstacle
        engine.draw_rect(game_state.obstacle.rect, game_state.obstacle.color.r, 
                        game_state.obstacle.color.g, game_state.obstacle.color.b)
        
        // Render enemy
        game.render_enemy(&game_state.enemy)
        
        // Render enemy projectiles
        game.render_enemy_projectiles(&game_state.enemy)
        
        // Render projectiles
        game.render_projectiles(&game_state.player)
        
        // Render trap
        game.render_trap(&game_state.player.abilities.trap)
        
        // Render aim arrow (on top of everything else)
        game.render_aim_arrow(&game_state.player)
        
        // Render spell UI at bottom
        game.render_spell_ui(&game_state.player, WINDOW_WIDTH, WINDOW_HEIGHT)
        
    case .VICTORY:
        // Render victory screen
        
        // Victory text (centered)
        victory_text := "VICTORY"
        text_size: f32 = 80
        text_x := f32(WINDOW_WIDTH/2 - len(victory_text) * int(text_size * 0.35))
        text_y := f32(WINDOW_HEIGHT/2 - text_size/2)
        engine.draw_text(victory_text, text_x, text_y, text_size, 255, 255, 0) // Yellow
        
        // Restart button (centered below victory text)
        button_x := f32(WINDOW_WIDTH/2 - 60)
        button_y := f32(WINDOW_HEIGHT/2 + 50)
        button_width: f32 = 120
        button_height: f32 = 40
        engine.draw_button(button_x, button_y, button_width, button_height, 
                          "RESTART", 100, 100, 100, 255, 255, 255)
    
    case .DEFEAT:
        // Render defeat screen
        
        // Defeat text (centered)
        defeat_text := "DEFEAT"
        text_size: f32 = 80
        text_x := f32(WINDOW_WIDTH/2 - len(defeat_text) * int(text_size * 0.35))
        text_y := f32(WINDOW_HEIGHT/2 - text_size/2)
        engine.draw_text(defeat_text, text_x, text_y, text_size, 255, 0, 0) // Red
        
        // Restart button (centered below defeat text)
        button_x := f32(WINDOW_WIDTH/2 - 60)
        button_y := f32(WINDOW_HEIGHT/2 + 50)
        button_width: f32 = 120
        button_height: f32 = 40
        engine.draw_button(button_x, button_y, button_width, button_height, 
                          "RESTART", 100, 100, 100, 255, 255, 255)
    }
    
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
    fmt.println("GOAL: Defeat the red enemy (10 HP) - You have 20 HP")
    fmt.println("=== ADC CONTROLS ===")
    fmt.println("Left-click: Basic Attack on enemy (1 dmg)")
    fmt.println("Right-click: Move to position")
    fmt.println("Q: Long Range Shot (3 dmg, 8s cooldown)")
    fmt.println("W: Speed Boost (3s duration, 12s cooldown)")  
    fmt.println("E: Place Trap (roots for 2s, 14s cooldown)")
    fmt.println("F: Flash teleport (10s cooldown)")
    fmt.println("Hover over ability icons for details")
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
