package game

import "../util"
import "../engine"

// Player represents the controllable rectangle
Player :: struct {
    position: util.Vector2,
    size:     util.Vector2,
    speed:    f32,
    color:    struct { r, g, b: u8 },
}

// Create a new player
create_player :: proc(x, y, width, height, speed: f32) -> Player {
    return Player{
        position = util.vec2(x, y),
        size     = util.vec2(width, height),
        speed    = speed,
        color    = {100, 150, 255}, // Light blue
    }
}

// Update player position based on input
update_player :: proc(player: ^Player, bounds: util.Rectangle, dt: f32) {
    // Store old position
    old_pos := player.position
    
    // Handle input
    if engine.is_left_pressed() {
        player.position.x -= player.speed * dt
    }
    if engine.is_right_pressed() {
        player.position.x += player.speed * dt
    }
    if engine.is_up_pressed() {
        player.position.y -= player.speed * dt
    }
    if engine.is_down_pressed() {
        player.position.y += player.speed * dt
    }
    
    // Keep player within bounds
    player_rect := util.rect(player.position.x, player.position.y, player.size.x, player.size.y)
    util.clamp_rect_to_bounds(&player_rect, bounds)
    
    // Update position from clamped rectangle
    player.position.x = player_rect.x
    player.position.y = player_rect.y
}

// Render the player
render_player :: proc(player: ^Player) {
    player_rect := util.rect(player.position.x, player.position.y, player.size.x, player.size.y)
    engine.draw_rect(player_rect, player.color.r, player.color.g, player.color.b)
}

// Get player rectangle for collision detection
get_player_rect :: proc(player: ^Player) -> util.Rectangle {
    return util.rect(player.position.x, player.position.y, player.size.x, player.size.y)
}
