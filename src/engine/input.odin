package engine

import win32 "core:sys/windows"

// Key states
KeyState :: enum {
    UP,
    DOWN,
    PRESSED,   // Just pressed this frame
    RELEASED,  // Just released this frame
}

// Virtual key codes
VK_LEFT     :: 0x25
VK_UP       :: 0x26
VK_RIGHT    :: 0x27
VK_DOWN     :: 0x28
VK_ESCAPE   :: 0x1B
VK_LBUTTON  :: 0x01  // Left mouse button
VK_RBUTTON  :: 0x02  // Right mouse button
VK_Q        :: 0x51  // Q key
VK_W        :: 0x57  // W key
VK_E        :: 0x45  // E key
VK_F        :: 0x46  // F key

// Mouse input data
MouseInput :: struct {
    x, y:           i32,
    left_clicked:   bool,
    right_clicked:  bool,
    left_pressed:   bool,
    right_pressed:  bool,
}

// Input manager to track key states and mouse
InputManager :: struct {
    current_keys:   [256]bool,
    previous_keys:  [256]bool,
    mouse:          MouseInput,
    prev_mouse:     MouseInput,
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
    input_manager.prev_mouse = input_manager.mouse
    
    // Check key states using GetAsyncKeyState
    for i in 0..<256 {
        state := win32.GetAsyncKeyState(i32(i))
        input_manager.current_keys[i] = (state & -32768) != 0
    }
    
    // Update mouse position
    point: win32.POINT
    win32.GetCursorPos(&point)
    
    // Convert to client coordinates (relative to window)
    extern_hwnd := get_window_handle() // We need to add this function
    if extern_hwnd != nil {
        win32.ScreenToClient(extern_hwnd, &point)
    }
    
    input_manager.mouse.x = point.x
    input_manager.mouse.y = point.y
    
    // Check mouse button states
    input_manager.mouse.left_pressed = input_manager.current_keys[VK_LBUTTON]
    input_manager.mouse.right_pressed = input_manager.current_keys[VK_RBUTTON]
    
    // Detect clicks (pressed this frame but not last frame)
    input_manager.mouse.left_clicked = input_manager.mouse.left_pressed && !input_manager.prev_mouse.left_pressed
    input_manager.mouse.right_clicked = input_manager.mouse.right_pressed && !input_manager.prev_mouse.right_pressed
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

// Q key functions
is_q_pressed :: proc() -> bool {
    return get_key_state(VK_Q) == .DOWN || get_key_state(VK_Q) == .PRESSED
}

is_q_just_pressed :: proc() -> bool {
    return get_key_state(VK_Q) == .PRESSED
}

// F key functions
is_f_pressed :: proc() -> bool {
    return get_key_state(VK_F) == .DOWN || get_key_state(VK_F) == .PRESSED
}

is_f_just_pressed :: proc() -> bool {
    return get_key_state(VK_F) == .PRESSED
}

// W key functions
is_w_pressed :: proc() -> bool {
    return get_key_state(VK_W) == .DOWN || get_key_state(VK_W) == .PRESSED
}

is_w_just_pressed :: proc() -> bool {
    return get_key_state(VK_W) == .PRESSED
}

// E key functions
is_e_pressed :: proc() -> bool {
    return get_key_state(VK_E) == .DOWN || get_key_state(VK_E) == .PRESSED
}

is_e_just_pressed :: proc() -> bool {
    return get_key_state(VK_E) == .PRESSED
}

// Mouse functions
get_mouse_pos :: proc() -> (i32, i32) {
    return input_manager.mouse.x, input_manager.mouse.y
}

is_left_mouse_clicked :: proc() -> bool {
    return input_manager.mouse.left_clicked
}

is_right_mouse_clicked :: proc() -> bool {
    return input_manager.mouse.right_clicked
}

is_left_mouse_pressed :: proc() -> bool {
    return input_manager.mouse.left_pressed
}

is_right_mouse_pressed :: proc() -> bool {
    return input_manager.mouse.right_pressed
}

// Window handle storage
current_window_handle: win32.HWND

// Function to be called by renderer to provide window handle
set_window_handle :: proc(hwnd: win32.HWND) {
    current_window_handle = hwnd
}

get_window_handle :: proc() -> win32.HWND {
    return current_window_handle
}
