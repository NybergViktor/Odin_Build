package game

import "../util"
import "../engine"

// Projectile represents a fired shot
Projectile :: struct {
    position:       util.Vector2,
    velocity:       util.Vector2,
    size:           util.Vector2,
    color:          struct { r, g, b: u8 },
    start_pos:      util.Vector2,
    max_distance:   f32,
    damage:         i32,
    active:         bool,
}

// Max projectiles that can exist at once
MAX_PROJECTILES :: 100

// ADC Ability cooldowns (in seconds)
BASIC_ATTACK_CD :: 0.8   // Auto-attack speed
Q_ABILITY_CD :: 8.0      // Long range shot
W_ABILITY_CD :: 12.0     // Speed boost
E_ABILITY_CD :: 14.0     // Trap ability
F_FLASH_CD :: 10.0       // Flash

// Trap structure
Trap :: struct {
    position:     util.Vector2,
    size:         util.Vector2,
    active:       bool,
    armed_time:   f32,     // Time until trap is armed
    duration:     f32,     // How long trap lasts
    triggered:    bool,
    root_target:  ^Enemy,  // Enemy caught in trap
    root_duration: f32,    // How long root lasts
}

// ADC Abilities
ADC_Abilities :: struct {
    // Cooldowns
    basic_attack_remaining: f32,
    q_cooldown_remaining:   f32,
    w_cooldown_remaining:   f32,
    e_cooldown_remaining:   f32,
    f_cooldown_remaining:   f32,
    
    // Basic attack
    basic_attack_range:     f32,
    basic_attack_damage:    i32,
    
    // Q - Long range shot
    q_range:               f32,
    q_damage:              i32,
    
    // W - Speed boost
    w_speed_multiplier:    f32,
    w_duration:            f32,
    w_remaining:           f32,
    
    // E - Trap
    trap:                  Trap,
    
    // F - Flash
    flash_distance:        f32,
}

// Player represents the controllable rectangle
Player :: struct {
    position:      util.Vector2,
    size:          util.Vector2,
    speed:         f32,
    color:         struct { r, g, b: u8 },
    target_pos:    util.Vector2,
    is_moving:     bool,
    hp:            i32,
    max_hp:        i32,
    projectiles:   [MAX_PROJECTILES]Projectile,
    // Aiming system
    aiming:        bool,
    aim_start:     util.Vector2,
    aim_end:       util.Vector2,
    max_range:     f32,
    // ADC Abilities
    abilities:     ADC_Abilities,
}

// Create a new player
create_player :: proc(x, y, width, height, speed: f32) -> Player {
    return Player{
        position    = util.vec2(x, y),
        size        = util.vec2(width, height),
        speed       = speed,
        color       = {100, 150, 255}, // Light blue
        target_pos  = util.vec2(x, y),
        is_moving   = false,
        hp          = 20, // Player starts with 20 HP
        max_hp      = 20,
        projectiles = {},
        aiming      = false,
        aim_start   = util.vec2(0, 0),
        aim_end     = util.vec2(0, 0),
        max_range   = 200.0, // Maximum shooting range in pixels
        abilities   = ADC_Abilities{
            // Cooldowns
            basic_attack_remaining = 0,
            q_cooldown_remaining   = 0,
            w_cooldown_remaining   = 0,
            e_cooldown_remaining   = 0,
            f_cooldown_remaining   = 0,
            
            // Basic attack stats
            basic_attack_range     = 120.0,
            basic_attack_damage    = 1,
            
            // Q ability stats
            q_range               = 300.0,
            q_damage              = 3,
            
            // W ability stats
            w_speed_multiplier    = 1.8,
            w_duration            = 3.0,
            w_remaining           = 0,
            
            // E trap
            trap = Trap{
                active = false,
                size = util.vec2(30, 30),
                armed_time = 1.0,
                duration = 8.0,
                root_duration = 2.0,
            },
            
            // Flash
            flash_distance = 100.0,
        },
    }
}

// Update player position based on input
update_player :: proc(player: ^Player, bounds: util.Rectangle, enemy: ^Enemy, dt: f32) {
    // Handle right click for movement
    if engine.is_right_mouse_clicked() {
        mouse_x, mouse_y := engine.get_mouse_pos()
        
        // Convert to world coordinates and set as target
        // Offset by half player size so player centers on click point
        player.target_pos.x = f32(mouse_x) - player.size.x / 2
        player.target_pos.y = f32(mouse_y) - player.size.y / 2
        
        // Clamp target position to bounds
        target_rect := util.rect(player.target_pos.x, player.target_pos.y, player.size.x, player.size.y)
        util.clamp_rect_to_bounds(&target_rect, bounds)
        player.target_pos.x = target_rect.x
        player.target_pos.y = target_rect.y
        
        player.is_moving = true
    }
    
    // Move towards target if we have one
    if player.is_moving {
        // Store old position for collision recovery
        old_pos := player.position
        
        // Calculate direction to target
        dx := player.target_pos.x - player.position.x
        dy := player.target_pos.y - player.position.y
        distance := util.sqrt(dx*dx + dy*dy)
        
        if distance < 2.0 { // Close enough, stop moving
            player.position = player.target_pos
            player.is_moving = false
        } else {
            // Apply speed boost if W is active
            current_speed := player.speed
            if player.abilities.w_remaining > 0 {
                current_speed *= player.abilities.w_speed_multiplier
            }
            
            // Move towards target
            move_distance := current_speed * dt
            if move_distance > distance {
                move_distance = distance
            }
            
            // Normalize direction and move
            new_x := player.position.x + (dx / distance) * move_distance
            new_y := player.position.y + (dy / distance) * move_distance
            
            // Check collision with enemy before moving
            if enemy.alive {
                test_player_rect := util.rect(new_x, new_y, player.size.x, player.size.y)
                enemy_rect := get_enemy_rect(enemy)
                
                if util.rects_overlap(test_player_rect, enemy_rect) {
                    // Collision detected - try to move around enemy
                    
                    // Try moving only in X direction
                    test_x_rect := util.rect(new_x, player.position.y, player.size.x, player.size.y)
                    if !util.rects_overlap(test_x_rect, enemy_rect) {
                        player.position.x = new_x
                    } else {
                        // Try moving only in Y direction
                        test_y_rect := util.rect(player.position.x, new_y, player.size.x, player.size.y)
                        if !util.rects_overlap(test_y_rect, enemy_rect) {
                            player.position.y = new_y
                        } else {
                            // If both directions blocked, stop moving
                            player.is_moving = false
                        }
                    }
                } else {
                    // No collision, move normally
                    player.position.x = new_x
                    player.position.y = new_y
                }
            } else {
                // Enemy is dead, move normally
                player.position.x = new_x
                player.position.y = new_y
            }
        }
    }
    
    // Update all ability cooldowns
    if player.abilities.basic_attack_remaining > 0 {
        player.abilities.basic_attack_remaining -= dt
        if player.abilities.basic_attack_remaining < 0 {
            player.abilities.basic_attack_remaining = 0
        }
    }
    
    if player.abilities.q_cooldown_remaining > 0 {
        player.abilities.q_cooldown_remaining -= dt
        if player.abilities.q_cooldown_remaining < 0 {
            player.abilities.q_cooldown_remaining = 0
        }
    }
    
    if player.abilities.w_cooldown_remaining > 0 {
        player.abilities.w_cooldown_remaining -= dt
        if player.abilities.w_cooldown_remaining < 0 {
            player.abilities.w_cooldown_remaining = 0
        }
    }
    
    if player.abilities.e_cooldown_remaining > 0 {
        player.abilities.e_cooldown_remaining -= dt
        if player.abilities.e_cooldown_remaining < 0 {
            player.abilities.e_cooldown_remaining = 0
        }
    }
    
    if player.abilities.f_cooldown_remaining > 0 {
        player.abilities.f_cooldown_remaining -= dt
        if player.abilities.f_cooldown_remaining < 0 {
            player.abilities.f_cooldown_remaining = 0
        }
    }
    
    // Update W speed boost
    if player.abilities.w_remaining > 0 {
        player.abilities.w_remaining -= dt
        if player.abilities.w_remaining <= 0 {
            player.abilities.w_remaining = 0
        }
    }
    
    // Update trap
    update_trap(&player.abilities.trap, enemy, dt)
    
    // Handle right-click for basic attack or movement
    // Handle left click for basic attack
    if engine.is_left_mouse_clicked() {
        mouse_x, mouse_y := engine.get_mouse_pos()
        
        // Check if clicking on enemy for basic attack
        if enemy.alive && player.abilities.basic_attack_remaining <= 0 {
            enemy_rect := get_enemy_rect(enemy)
            mouse_pos := util.vec2(f32(mouse_x), f32(mouse_y))
            
            if util.point_in_rect(mouse_pos, enemy_rect) {
                // Try basic attack
                player_center := util.vec2(player.position.x + player.size.x/2, player.position.y + player.size.y/2)
                enemy_center := util.vec2(enemy_rect.x + enemy_rect.width/2, enemy_rect.y + enemy_rect.height/2)
                attack_distance := util.distance(player_center, enemy_center)
                
                if attack_distance <= player.abilities.basic_attack_range {
                    // Basic attack!
                    damage_enemy(enemy, player.abilities.basic_attack_damage)
                    player.abilities.basic_attack_remaining = BASIC_ATTACK_CD
                }
            }
        }
    }
    
    // Handle right click for movement only
    if engine.is_right_mouse_clicked() {
        mouse_x, mouse_y := engine.get_mouse_pos()
        // Move to position
        set_move_target(player, f32(mouse_x), f32(mouse_y), bounds)
    }
    
    // Handle Q - Long range shot
    if engine.is_q_pressed() && player.abilities.q_cooldown_remaining <= 0 {
        mouse_x, mouse_y := engine.get_mouse_pos()
        
        player_center_x := player.position.x + player.size.x / 2
        player_center_y := player.position.y + player.size.y / 2
        
        dx := f32(mouse_x) - player_center_x
        dy := f32(mouse_y) - player_center_y
        distance := util.sqrt(dx*dx + dy*dy)
        
        // Use Q ability range
        q_range := player.abilities.q_range
        if distance > q_range {
            dx = (dx / distance) * q_range
            dy = (dy / distance) * q_range
        }
        
        player.aiming = true
        player.aim_start = util.vec2(player_center_x, player_center_y)
        player.aim_end = util.vec2(player_center_x + dx, player_center_y + dy)
        
        // Shoot when left clicking while aiming
        if engine.is_left_mouse_clicked() {
            shoot_q_ability(player, player.aim_end.x, player.aim_end.y)
            player.abilities.q_cooldown_remaining = Q_ABILITY_CD
        }
    } else {
        player.aiming = false
    }
    
    // Handle W - Speed boost
    if engine.is_w_just_pressed() && player.abilities.w_cooldown_remaining <= 0 {
        player.abilities.w_remaining = player.abilities.w_duration
        player.abilities.w_cooldown_remaining = W_ABILITY_CD
    }
    
    // Handle E - Trap
    if engine.is_e_just_pressed() && player.abilities.e_cooldown_remaining <= 0 {
        mouse_x, mouse_y := engine.get_mouse_pos()
        place_trap(player, f32(mouse_x), f32(mouse_y), bounds)
        player.abilities.e_cooldown_remaining = E_ABILITY_CD
    }
    
    // Handle F - Flash
    if engine.is_f_just_pressed() && player.abilities.f_cooldown_remaining <= 0 {
        mouse_x, mouse_y := engine.get_mouse_pos()
        
        player_center_x := player.position.x + player.size.x / 2
        player_center_y := player.position.y + player.size.y / 2
        
        dx := f32(mouse_x) - player_center_x
        dy := f32(mouse_y) - player_center_y
        distance := util.sqrt(dx*dx + dy*dy)
        
        if distance > 0 {
            // Normalize direction and flash
            flash_x := (dx / distance) * player.abilities.flash_distance
            flash_y := (dy / distance) * player.abilities.flash_distance
            
            new_x := player.position.x + flash_x
            new_y := player.position.y + flash_y
            
            // Check if flash position is valid
            flash_rect := util.rect(new_x, new_y, player.size.x, player.size.y)
            util.clamp_rect_to_bounds(&flash_rect, bounds)
            
            // Check collision with enemy
            can_flash := true
            if enemy.alive {
                enemy_rect := get_enemy_rect(enemy)
                if util.rects_overlap(flash_rect, enemy_rect) {
                    can_flash = false
                }
            }
            
            if can_flash {
                player.position.x = flash_rect.x
                player.position.y = flash_rect.y
                player.abilities.f_cooldown_remaining = F_FLASH_CD
                player.is_moving = false
            }
        }
    }
    
    // Note: Projectiles are now updated in main.odin with enemy reference
}

// Render the player
render_player :: proc(player: ^Player) {
    player_rect := util.rect(player.position.x, player.position.y, player.size.x, player.size.y)
    engine.draw_rect(player_rect, player.color.r, player.color.g, player.color.b)
    
    // Draw HP bar above player
    bar_width: f32 = player.size.x
    bar_height: f32 = 8
    bar_x := player.position.x
    bar_y := player.position.y - bar_height - 4
    
    // Background (black)
    bg_rect := util.rect(bar_x, bar_y, bar_width, bar_height)
    engine.draw_rect(bg_rect, 0, 0, 0)
    
    // Health bar (green to red based on health)
    health_ratio := f32(player.hp) / f32(player.max_hp)
    health_width := bar_width * health_ratio
    if health_width > 0 {
        hp_rect := util.rect(bar_x, bar_y, health_width, bar_height)
        hp_red := u8(255 * (1.0 - health_ratio))
        hp_green := u8(255 * health_ratio)
        engine.draw_rect(hp_rect, hp_red, hp_green, 0)
    }
}

// Get player rectangle for collision detection
get_player_rect :: proc(player: ^Player) -> util.Rectangle {
    return util.rect(player.position.x, player.position.y, player.size.x, player.size.y)
}

// Damage the player
damage_player :: proc(player: ^Player, damage: i32) {
    player.hp -= damage
    if player.hp <= 0 {
        player.hp = 0
        // Player death will be handled in main game loop
    }
}

// Check if player is alive
is_player_alive :: proc(player: ^Player) -> bool {
    return player.hp > 0
}

// Shoot a projectile with limited range towards target position  
shoot_projectile_with_range :: proc(player: ^Player, target_x, target_y: f32) {
    // Find an inactive projectile slot
    projectile_index := -1
    for i in 0..<MAX_PROJECTILES {
        if !player.projectiles[i].active {
            projectile_index = i
            break
        }
    }
    
    if projectile_index == -1 do return // No available slots
    
    // Calculate projectile start position (center of player)
    start_x := player.position.x + player.size.x / 2
    start_y := player.position.y + player.size.y / 2
    
    // Calculate direction to target
    dx := target_x - start_x
    dy := target_y - start_y
    distance := util.sqrt(dx*dx + dy*dy)
    
    if distance == 0 do return // Can't shoot at same position
    
    // Normalize direction and set velocity
    projectile_speed: f32 = 600.0 // pixels per second
    vel_x := (dx / distance) * projectile_speed
    vel_y := (dy / distance) * projectile_speed
    
    // Create projectile with range limit
    player.projectiles[projectile_index] = Projectile{
        position     = util.vec2(start_x - 2, start_y - 2), // Center the 4x4 projectile
        velocity     = util.vec2(vel_x, vel_y),
        size         = util.vec2(4, 4),
        color        = {255, 255, 0}, // Yellow
        start_pos    = util.vec2(start_x, start_y),
        max_distance = distance, // Limit to aim line distance
        active       = true,
    }
}

// Update all projectiles and handle collisions
update_projectiles :: proc(player: ^Player, bounds: util.Rectangle, enemy: ^Enemy, obstacle: ^util.Obstacle, dt: f32) {
    for i in 0..<MAX_PROJECTILES {
        if !player.projectiles[i].active do continue
        
        projectile := &player.projectiles[i]
        
        // Update position
        projectile.position.x += projectile.velocity.x * dt
        projectile.position.y += projectile.velocity.y * dt
        
        // Check collision with obstacle (blocks projectiles)
        projectile_rect := util.rect(projectile.position.x, projectile.position.y, projectile.size.x, projectile.size.y)
        if util.rects_overlap(projectile_rect, obstacle.rect) {
            // Hit obstacle - projectile is blocked
            projectile.active = false
            continue
        }
        
        // Check collision with enemy
        if enemy.alive {
            enemy_rect := get_enemy_rect(enemy)
            
            if util.rects_overlap(projectile_rect, enemy_rect) {
                // Hit enemy
                damage_enemy(enemy, projectile.damage)
                projectile.active = false
                continue
            }
        }
        
        // Check distance traveled from start position
        traveled_distance := util.distance(projectile.start_pos, projectile.position)
        
        // Check if projectile should be removed
        if traveled_distance >= projectile.max_distance ||
           projectile.position.x < bounds.x - projectile.size.x ||
           projectile.position.x > bounds.x + bounds.width ||
           projectile.position.y < bounds.y - projectile.size.y ||
           projectile.position.y > bounds.y + bounds.height {
            projectile.active = false
        }
    }
}

// Render all projectiles
render_projectiles :: proc(player: ^Player) {
    for i in 0..<MAX_PROJECTILES {
        if !player.projectiles[i].active do continue
        
        projectile := &player.projectiles[i]
        projectile_rect := util.rect(projectile.position.x, projectile.position.y, projectile.size.x, projectile.size.y)
        engine.draw_rect(projectile_rect, projectile.color.r, projectile.color.g, projectile.color.b)
    }
}

// Render the aim arrow when player is aiming
render_aim_arrow :: proc(player: ^Player) {
    if !player.aiming do return
    
    // Draw the aim arrow in red
    engine.draw_arrow(
        player.aim_start.x, player.aim_start.y,
        player.aim_end.x, player.aim_end.y,
        255, 0, 0, // Red color
        2 // Thickness
    )
}

// Set movement target for click-to-move
set_move_target :: proc(player: ^Player, target_x, target_y: f32, bounds: util.Rectangle) {
    // Convert to world coordinates and set as target
    player.target_pos.x = target_x - player.size.x / 2
    player.target_pos.y = target_y - player.size.y / 2
    
    // Clamp target position to bounds
    target_rect := util.rect(player.target_pos.x, player.target_pos.y, player.size.x, player.size.y)
    util.clamp_rect_to_bounds(&target_rect, bounds)
    player.target_pos.x = target_rect.x
    player.target_pos.y = target_rect.y
    
    player.is_moving = true
}

// Shoot Q ability (long range shot with more damage)
shoot_q_ability :: proc(player: ^Player, target_x, target_y: f32) {
    // Find an inactive projectile slot
    projectile_index := -1
    for i in 0..<MAX_PROJECTILES {
        if !player.projectiles[i].active {
            projectile_index = i
            break
        }
    }
    
    if projectile_index == -1 do return
    
    // Calculate projectile start position (center of player)
    start_x := player.position.x + player.size.x / 2
    start_y := player.position.y + player.size.y / 2
    
    // Calculate direction to target
    dx := target_x - start_x
    dy := target_y - start_y
    distance := util.sqrt(dx*dx + dy*dy)
    
    if distance == 0 do return
    
    // Faster, more powerful projectile for Q ability
    projectile_speed: f32 = 800.0
    vel_x := (dx / distance) * projectile_speed
    vel_y := (dy / distance) * projectile_speed
    
    // Create Q projectile (bigger and different color)
    player.projectiles[projectile_index] = Projectile{
        position     = util.vec2(start_x - 3, start_y - 3),
        velocity     = util.vec2(vel_x, vel_y),
        size         = util.vec2(6, 6), // Bigger than basic attack
        color        = {255, 150, 0}, // Orange color
        start_pos    = util.vec2(start_x, start_y),
        max_distance = distance,
        damage       = 3, // Q ability does 3 damage
        active       = true,
    }
}

// Place a trap at target location
place_trap :: proc(player: ^Player, target_x, target_y: f32, bounds: util.Rectangle) {
    if player.abilities.trap.active do return // Only one trap at a time
    
    // Set trap position
    trap_x := target_x - player.abilities.trap.size.x / 2
    trap_y := target_y - player.abilities.trap.size.y / 2
    
    // Clamp to bounds
    trap_rect := util.rect(trap_x, trap_y, player.abilities.trap.size.x, player.abilities.trap.size.y)
    util.clamp_rect_to_bounds(&trap_rect, bounds)
    
    player.abilities.trap.position = util.vec2(trap_rect.x, trap_rect.y)
    player.abilities.trap.active = true
    player.abilities.trap.triggered = false
    player.abilities.trap.armed_time = 1.0 // Takes 1 second to arm
    player.abilities.trap.duration = 8.0   // Lasts 8 seconds
    player.abilities.trap.root_target = nil
    player.abilities.trap.root_duration = 0
}

// Update trap logic
update_trap :: proc(trap: ^Trap, enemy: ^Enemy, dt: f32) {
    if !trap.active do return
    
    // Update trap timing
    if trap.armed_time > 0 {
        trap.armed_time -= dt
    }
    
    trap.duration -= dt
    if trap.duration <= 0 {
        trap.active = false
        return
    }
    
    // Update root duration if enemy is rooted
    if trap.root_duration > 0 {
        trap.root_duration -= dt
        if trap.root_duration <= 0 {
            trap.root_target = nil
        }
    }
    
    // Check if enemy steps on armed trap
    if trap.armed_time <= 0 && !trap.triggered && enemy.alive {
        enemy_rect := get_enemy_rect(enemy)
        trap_rect := util.rect(trap.position.x, trap.position.y, trap.size.x, trap.size.y)
        
        if util.rects_overlap(enemy_rect, trap_rect) {
            // Trigger trap!
            trap.triggered = true
            trap.root_target = enemy
            trap.root_duration = 2.0 // Root for 2 seconds
            trap.active = false // Trap disappears after triggering
        }
    }
}

// Render the trap
render_trap :: proc(trap: ^Trap) {
    if !trap.active do return
    
    trap_rect := util.rect(trap.position.x, trap.position.y, trap.size.x, trap.size.y)
    
    if trap.armed_time > 0 {
        // Trap is arming - show in yellow
        engine.draw_rect(trap_rect, 255, 255, 0)
    } else {
        // Trap is armed - show in red
        engine.draw_rect(trap_rect, 255, 0, 0)
    }
}

// Check if enemy is rooted
is_enemy_rooted :: proc(player: ^Player, enemy: ^Enemy) -> bool {
    return player.abilities.trap.root_target == enemy && player.abilities.trap.root_duration > 0
}

// Render ADC spell UI at bottom of screen
render_spell_ui :: proc(player: ^Player, window_width, window_height: i32) {
    slot_size: f32 = 50
    slot_spacing: f32 = 8
    ui_y := f32(window_height) - slot_size - 15
    
    // Center the spell slots horizontally (4 abilities: RMB, Q, W, E, F)
    total_width := 5 * slot_size + 4 * slot_spacing
    start_x := f32(window_width)/2 - total_width/2
    
    // Get mouse position for hover detection
    mouse_x, mouse_y := engine.get_mouse_pos()
    
    // Basic Attack (RMB) slot
    rmb_x := start_x
    rmb_hovered := engine.is_mouse_over_rect(mouse_x, mouse_y, rmb_x, ui_y, slot_size, slot_size)
    engine.draw_spell_slot(rmb_x, ui_y, slot_size, "AA", 
                          player.abilities.basic_attack_remaining, BASIC_ATTACK_CD, rmb_hovered)
    
    if rmb_hovered {
        engine.draw_tooltip(rmb_x, ui_y, "BASIC ATTACK - DAMAGE 1")
    }
    
    // Q ability slot
    q_x := start_x + slot_size + slot_spacing
    q_hovered := engine.is_mouse_over_rect(mouse_x, mouse_y, q_x, ui_y, slot_size, slot_size)
    engine.draw_spell_slot(q_x, ui_y, slot_size, "Q", 
                          player.abilities.q_cooldown_remaining, Q_ABILITY_CD, q_hovered)
    
    if q_hovered {
        engine.draw_tooltip(q_x, ui_y, "LONG SHOT - DAMAGE 3")
    }
    
    // W ability slot
    w_x := start_x + 2 * (slot_size + slot_spacing)
    w_hovered := engine.is_mouse_over_rect(mouse_x, mouse_y, w_x, ui_y, slot_size, slot_size)
    w_active := player.abilities.w_remaining > 0
    engine.draw_spell_slot(w_x, ui_y, slot_size, "W", 
                          player.abilities.w_cooldown_remaining, W_ABILITY_CD, w_hovered)
    
    if w_hovered {
        engine.draw_tooltip(w_x, ui_y, "SPEED BOOST - 3 SEC")
    }
    
    // E ability slot
    e_x := start_x + 3 * (slot_size + slot_spacing)
    e_hovered := engine.is_mouse_over_rect(mouse_x, mouse_y, e_x, ui_y, slot_size, slot_size)
    engine.draw_spell_slot(e_x, ui_y, slot_size, "E", 
                          player.abilities.e_cooldown_remaining, E_ABILITY_CD, e_hovered)
    
    if e_hovered {
        engine.draw_tooltip(e_x, ui_y, "TRAP - ROOT 2 SEC")
    }
    
    // F ability slot
    f_x := start_x + 4 * (slot_size + slot_spacing)
    f_hovered := engine.is_mouse_over_rect(mouse_x, mouse_y, f_x, ui_y, slot_size, slot_size)
    engine.draw_spell_slot(f_x, ui_y, slot_size, "F", 
                          player.abilities.f_cooldown_remaining, F_FLASH_CD, f_hovered)
    
    if f_hovered {
        engine.draw_tooltip(f_x, ui_y, "FLASH - TELEPORT")
    }
}
