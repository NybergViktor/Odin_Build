package game

import "../util"
import "../engine"
import "core:math/rand"

// Enemy Projectile for enemy attacks
EnemyProjectile :: struct {
    position:    util.Vector2,
    velocity:    util.Vector2,
    size:        util.Vector2,
    damage:      i32,
    active:      bool,
    range:       f32,
    start_pos:   util.Vector2,
}

// Max enemy projectiles
MAX_ENEMY_PROJECTILES :: 20

// Enemy represents a hostile entity
Enemy :: struct {
    position:       util.Vector2,
    size:           util.Vector2,
    velocity:       util.Vector2,
    speed:          f32,
    hp:             i32,
    max_hp:         i32,
    color:          struct { r, g, b: u8 },
    alive:          bool,
    direction_timer: f32,
    next_direction_change: f32,
    attack_range:   f32,
    attack_cooldown: f32,
    last_attack_time: f32,
    projectiles:    [MAX_ENEMY_PROJECTILES]EnemyProjectile,
}

// Create a new enemy
create_enemy :: proc(x, y, width, height: f32) -> Enemy {
    return Enemy{
        position       = util.vec2(x, y),
        size           = util.vec2(width, height),
        velocity       = util.vec2(0, 0),
        speed          = 100.0, // pixels per second
        hp             = 10,
        max_hp         = 10,
        color          = {255, 100, 100}, // Red
        alive          = true,
        direction_timer = 0,
        next_direction_change = 2.0, // Change direction every 2 seconds
        attack_range   = 200.0, // pixels
        attack_cooldown = 1.5, // seconds between attacks
        last_attack_time = 0,
        projectiles    = {},
    }
}

// Update enemy behavior and movement  
update_enemy :: proc(enemy: ^Enemy, bounds: util.Rectangle, player: ^Player, dt: f32) {
    if !enemy.alive do return
    
    // Update attack cooldown
    enemy.last_attack_time += dt
    
    // Check if player is in range and attack if possible
    player_center_x := player.position.x + player.size.x / 2
    player_center_y := player.position.y + player.size.y / 2
    enemy_center_x := enemy.position.x + enemy.size.x / 2
    enemy_center_y := enemy.position.y + enemy.size.y / 2
    
    distance_to_player := util.sqrt((player_center_x - enemy_center_x) * (player_center_x - enemy_center_x) + 
                                   (player_center_y - enemy_center_y) * (player_center_y - enemy_center_y))
    
    // Attack player if in range and cooldown is ready
    if distance_to_player <= enemy.attack_range && enemy.last_attack_time >= enemy.attack_cooldown {
        shoot_at_player(enemy, player_center_x, player_center_y)
        enemy.last_attack_time = 0
    }
    
    // Check if enemy is rooted by player's trap
    is_rooted := is_enemy_rooted(player, enemy)
    if is_rooted {
        // Enemy cannot move while rooted
        return
    }
    
    // Update direction change timer
    enemy.direction_timer += dt
    
    // Change direction periodically
    if enemy.direction_timer >= enemy.next_direction_change {
        enemy.direction_timer = 0
        enemy.next_direction_change = rand.float32_range(1.5, 3.0) // Random between 1.5-3 seconds
        
        // Pick random direction
        angle := rand.float32_range(0, 2.0 * 3.14159) // Random angle in radians
        enemy.velocity.x = util.sqrt(enemy.speed * enemy.speed / 2) * util.cos(angle)
        enemy.velocity.y = util.sqrt(enemy.speed * enemy.speed / 2) * util.sin(angle)
    }
    
    // Update position with collision checking
    old_pos := enemy.position
    new_x := enemy.position.x + enemy.velocity.x * dt
    new_y := enemy.position.y + enemy.velocity.y * dt
    
    // Check collision with player
    player_rect := get_player_rect(player)
    test_enemy_rect := util.rect(new_x, new_y, enemy.size.x, enemy.size.y)
    
    if util.rects_overlap(test_enemy_rect, player_rect) {
        // Collision with player - bounce away
        
        // Calculate direction from player to enemy to bounce away
        player_center_x := player_rect.x + player_rect.width / 2
        player_center_y := player_rect.y + player_rect.height / 2
        enemy_center_x := enemy.position.x + enemy.size.x / 2
        enemy_center_y := enemy.position.y + enemy.size.y / 2
        
        bounce_dx := enemy_center_x - player_center_x
        bounce_dy := enemy_center_y - player_center_y
        bounce_distance := util.sqrt(bounce_dx*bounce_dx + bounce_dy*bounce_dy)
        
        if bounce_distance > 0 {
            // Normalize and apply bounce velocity
            bounce_dx /= bounce_distance
            bounce_dy /= bounce_distance
            
            enemy.velocity.x = bounce_dx * enemy.speed
            enemy.velocity.y = bounce_dy * enemy.speed
        } else {
            // If centers are exactly the same, bounce in random direction
            enemy.velocity.x = -enemy.velocity.x
            enemy.velocity.y = -enemy.velocity.y
        }
        
        // Don't move this frame to avoid overlap
        new_x = enemy.position.x
        new_y = enemy.position.y
    }
    
    // Check boundaries and bounce off walls
    enemy_rect := util.rect(new_x, new_y, enemy.size.x, enemy.size.y)
    
    if enemy_rect.x <= bounds.x || enemy_rect.x + enemy_rect.width >= bounds.x + bounds.width {
        enemy.velocity.x = -enemy.velocity.x
        new_x = old_pos.x // Revert position change
    }
    
    if enemy_rect.y <= bounds.y || enemy_rect.y + enemy_rect.height >= bounds.y + bounds.height {
        enemy.velocity.y = -enemy.velocity.y
        new_y = old_pos.y // Revert position change
    }
    
    // Apply final position
    enemy.position.x = new_x
    enemy.position.y = new_y
    
    // Clamp to bounds just in case
    enemy_rect = util.rect(enemy.position.x, enemy.position.y, enemy.size.x, enemy.size.y)
    util.clamp_rect_to_bounds(&enemy_rect, bounds)
    enemy.position.x = enemy_rect.x
    enemy.position.y = enemy_rect.y
}

// Render the enemy
render_enemy :: proc(enemy: ^Enemy) {
    if !enemy.alive do return
    
    // Calculate color based on health (more red = less health)
    health_ratio := f32(enemy.hp) / f32(enemy.max_hp)
    red := u8(255)
    green := u8(100 * health_ratio)
    blue := u8(100 * health_ratio)
    
    enemy_rect := util.rect(enemy.position.x, enemy.position.y, enemy.size.x, enemy.size.y)
    engine.draw_rect(enemy_rect, red, green, blue)
    
    // Draw HP bar above enemy
    bar_width: f32 = enemy.size.x
    bar_height: f32 = 6
    bar_x := enemy.position.x
    bar_y := enemy.position.y - bar_height - 2
    
    // Background (black)
    bg_rect := util.rect(bar_x, bar_y, bar_width, bar_height)
    engine.draw_rect(bg_rect, 0, 0, 0)
    
    // Health bar (green to red based on health)
    health_width := bar_width * health_ratio
    if health_width > 0 {
        hp_rect := util.rect(bar_x, bar_y, health_width, bar_height)
        hp_red := u8(255 * (1.0 - health_ratio))
        hp_green := u8(255 * health_ratio)
        engine.draw_rect(hp_rect, hp_red, hp_green, 0)
    }
}

// Damage the enemy
damage_enemy :: proc(enemy: ^Enemy, damage: i32) {
    if !enemy.alive do return
    
    enemy.hp -= damage
    if enemy.hp <= 0 {
        enemy.hp = 0
        enemy.alive = false
    }
}

// Get enemy rectangle for collision detection
get_enemy_rect :: proc(enemy: ^Enemy) -> util.Rectangle {
    return util.rect(enemy.position.x, enemy.position.y, enemy.size.x, enemy.size.y)
}

// Check if enemy is alive
is_enemy_alive :: proc(enemy: ^Enemy) -> bool {
    return enemy.alive
}

// Shoot projectile at player
shoot_at_player :: proc(enemy: ^Enemy, target_x, target_y: f32) {
    // Find an inactive projectile slot
    projectile_index := -1
    for i in 0..<MAX_ENEMY_PROJECTILES {
        if !enemy.projectiles[i].active {
            projectile_index = i
            break
        }
    }
    
    if projectile_index == -1 do return // No available slots
    
    // Calculate projectile start position (center of enemy)
    start_x := enemy.position.x + enemy.size.x / 2
    start_y := enemy.position.y + enemy.size.y / 2
    
    // Calculate direction to target
    dx := target_x - start_x
    dy := target_y - start_y
    distance := util.sqrt(dx*dx + dy*dy)
    
    if distance == 0 do return // Can't shoot at self
    
    projectile_speed: f32 = 300.0 // pixels per second (slower than player)
    vel_x := (dx / distance) * projectile_speed
    vel_y := (dy / distance) * projectile_speed
    
    // Create the projectile
    enemy.projectiles[projectile_index] = EnemyProjectile{
        position  = util.vec2(start_x, start_y),
        velocity  = util.vec2(vel_x, vel_y),
        size      = util.vec2(6, 6),
        damage    = 2, // Enemy damage
        active    = true,
        range     = 250.0,
        start_pos = util.vec2(start_x, start_y),
    }
}

// Update enemy projectiles
update_enemy_projectiles :: proc(enemy: ^Enemy, player: ^Player, obstacle: ^util.Obstacle, dt: f32) {
    for i in 0..<MAX_ENEMY_PROJECTILES {
        projectile := &enemy.projectiles[i]
        if !projectile.active do continue
        
        // Move projectile
        projectile.position.x += projectile.velocity.x * dt
        projectile.position.y += projectile.velocity.y * dt
        
        // Check collision with obstacle (blocks enemy projectiles too)
        projectile_rect := util.rect(projectile.position.x, projectile.position.y, projectile.size.x, projectile.size.y)
        if util.rects_overlap(projectile_rect, obstacle.rect) {
            // Hit obstacle - projectile is blocked
            projectile.active = false
            continue
        }
        
        // Check collision with player
        player_rect := get_player_rect(player)
        if util.rects_overlap(projectile_rect, player_rect) {
            // Hit player - deal damage
            damage_player(player, projectile.damage)
            projectile.active = false
            continue
        }
        
        // Check if projectile has exceeded its range
        distance_traveled := util.sqrt((projectile.position.x - projectile.start_pos.x) * 
                                      (projectile.position.x - projectile.start_pos.x) +
                                      (projectile.position.y - projectile.start_pos.y) * 
                                      (projectile.position.y - projectile.start_pos.y))
        
        if distance_traveled >= projectile.range {
            projectile.active = false
        }
    }
}

// Render enemy projectiles
render_enemy_projectiles :: proc(enemy: ^Enemy) {
    for i in 0..<MAX_ENEMY_PROJECTILES {
        projectile := &enemy.projectiles[i]
        if !projectile.active do continue
        
        // Draw enemy projectile in dark red color
        projectile_rect := util.rect(projectile.position.x, projectile.position.y, 
                                   projectile.size.x, projectile.size.y)
        engine.draw_rect(projectile_rect, 150, 0, 0) // Dark red
    }
}
