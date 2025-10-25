package engine

import win32 "core:sys/windows"

// Key states
KeyState :: enum {
    UP,
    DOWN,
    PRESSED,   // Just pressed this frame
    RELEASED,  // Just released this frame
}

// Virtual key codes for arrow keys
VK_LEFT  :: 0x25
VK_UP    :: 0x26
VK_RIGHT :: 0x27
VK_DOWN  :: 0x28
VK_ESCAPE :: 0x1B

// Input manager to track key states
InputManager :: struct {
    current_keys:  [256]bool,
    previous_keys: [256]bool,
}

// Global input manager
input_manager: InputManager

// Initialize the input system
init_input :: proc() {
    input_manager = {}
}

// Update input states (call once per frame)
update_input :: proc() {
    // Copy current to previous
    input_manager.previous_keys = input_manager.current_keys
    
    // Check key states using GetAsyncKeyState
    for i in 0..<256 {
        state := win32.GetAsyncKeyState(i32(i))
        input_manager.current_keys[i] = (state & -32768) != 0
    }
}

// Get the state of a specific key
get_key_state :: proc(key_code: int) -> KeyState {
    current := input_manager.current_keys[key_code]
    previous := input_manager.previous_keys[key_code]
    
    if current && !previous {
        return .PRESSED
    } else if !current && previous {
        return .RELEASED
    } else if current {
        return .DOWN
    } else {
        return .UP
    }
}

// Convenience functions for arrow keys
is_left_pressed :: proc() -> bool {
    return get_key_state(VK_LEFT) == .DOWN || get_key_state(VK_LEFT) == .PRESSED
}

is_right_pressed :: proc() -> bool {
    return get_key_state(VK_RIGHT) == .DOWN || get_key_state(VK_RIGHT) == .PRESSED
}

is_up_pressed :: proc() -> bool {
    return get_key_state(VK_UP) == .DOWN || get_key_state(VK_UP) == .PRESSED
}

is_down_pressed :: proc() -> bool {
    return get_key_state(VK_DOWN) == .DOWN || get_key_state(VK_DOWN) == .PRESSED
}

is_escape_pressed :: proc() -> bool {
    return get_key_state(VK_ESCAPE) == .PRESSED
}
