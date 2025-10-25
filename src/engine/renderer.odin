package engine

import "core:fmt"
import win32 "core:sys/windows"
import "../util"

// Window and rendering context
RenderContext :: struct {
    hwnd:        win32.HWND,
    hdc:         win32.HDC,
    width:       i32,
    height:      i32,
    class_name:  win32.LPCWSTR,
}

// Global rendering context
render_ctx: RenderContext

// Window procedure
window_proc :: proc "stdcall" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
    switch msg {
    case win32.WM_DESTROY:
        win32.PostQuitMessage(0)
        return 0
    case win32.WM_PAINT:
        paint_struct: win32.PAINTSTRUCT
        hdc := win32.BeginPaint(hwnd, &paint_struct)
        win32.EndPaint(hwnd, &paint_struct)
        return 0
    }
    return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
}

// Initialize the renderer and create window
init_renderer :: proc(width, height: i32, title: string) -> bool {
    render_ctx.width = width
    render_ctx.height = height
    
    // Get instance handle
    hinstance := win32.GetModuleHandleW(nil)
    
    // Convert title to wide string
    w_title := win32.utf8_to_wstring(title)
    class_name := win32.utf8_to_wstring("OdinGameWindow")
    render_ctx.class_name = class_name
    
    // Register window class
    wc := win32.WNDCLASSEXW{
        cbSize        = size_of(win32.WNDCLASSEXW),
        style         = win32.CS_HREDRAW | win32.CS_VREDRAW,
        lpfnWndProc   = window_proc,
        cbClsExtra    = 0,
        cbWndExtra    = 0,
        hInstance     = win32.HANDLE(hinstance),
        hIcon         = nil,
        hCursor       = nil,
        hbrBackground = win32.HBRUSH(uintptr(win32.COLOR_WINDOW + 1)),
        lpszMenuName  = nil,
        lpszClassName = class_name,
        hIconSm       = nil,
    }
    
    if win32.RegisterClassExW(&wc) == 0 {
        fmt.println("Failed to register window class")
        return false
    }
    
    // Calculate window size including borders
    window_rect := win32.RECT{0, 0, width, height}
    win32.AdjustWindowRect(&window_rect, win32.WS_OVERLAPPEDWINDOW, false)
    
    // Create window
    render_ctx.hwnd = win32.CreateWindowExW(
        0,
        class_name,
        w_title,
        win32.WS_OVERLAPPEDWINDOW,
        win32.CW_USEDEFAULT, win32.CW_USEDEFAULT,
        window_rect.right - window_rect.left,
        window_rect.bottom - window_rect.top,
        nil, nil, win32.HANDLE(hinstance), nil
    )
    
    if render_ctx.hwnd == nil {
        fmt.println("Failed to create window")
        return false
    }
    
    // Get device context
    render_ctx.hdc = win32.GetDC(render_ctx.hwnd)
    
    // Show window
    win32.ShowWindow(render_ctx.hwnd, win32.SW_SHOW)
    win32.UpdateWindow(render_ctx.hwnd)
    
    // Set window handle for input system
    set_window_handle(render_ctx.hwnd)
    
    return true
}

// Check for window messages
should_close :: proc() -> bool {
    msg: win32.MSG
    for win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
        if msg.message == win32.WM_QUIT {
            return true
        }
        win32.TranslateMessage(&msg)
        win32.DispatchMessageW(&msg)
    }
    return false
}

// Clear the screen
clear_screen :: proc(r, g, b: u8) {
    // Create brush for background
    brush := win32.CreateSolidBrush(win32.RGB(r, g, b))
    rect := win32.RECT{0, 0, render_ctx.width, render_ctx.height}
    win32.FillRect(render_ctx.hdc, &rect, brush)
    win32.DeleteObject(win32.HGDIOBJ(brush))
}

// Draw a rectangle
draw_rect :: proc(rectangle: util.Rectangle, r, g, b: u8) {
    // Create brush
    brush := win32.CreateSolidBrush(win32.RGB(r, g, b))
    
    // Convert to Windows RECT
    rect := win32.RECT{
        left   = i32(rectangle.x),
        top    = i32(rectangle.y),
        right  = i32(rectangle.x + rectangle.width),
        bottom = i32(rectangle.y + rectangle.height),
    }
    
    // Fill rectangle
    win32.FillRect(render_ctx.hdc, &rect, brush)
    win32.DeleteObject(win32.HGDIOBJ(brush))
}

// Draw a line between two points
draw_line :: proc(x1, y1, x2, y2: f32, r, g, b: u8, thickness: i32 = 2) {
    // For simplicity, draw line as a thin rectangle for now
    // Calculate line direction and create a thin rectangle
    dx := x2 - x1
    dy := y2 - y1
    length := util.sqrt(dx*dx + dy*dy)
    
    if length < 1 do return
    
    // Create multiple small rectangles to simulate a line
    steps := i32(length)
    if steps > 200 do steps = 200 // Limit for performance
    
    brush := win32.CreateSolidBrush(win32.RGB(r, g, b))
    
    for i in 0..<steps {
        t := f32(i) / f32(steps)
        px := i32(x1 + dx * t)
        py := i32(y1 + dy * t)
        
        rect := win32.RECT{px, py, px + thickness, py + thickness}
        win32.FillRect(render_ctx.hdc, &rect, brush)
    }
    
    win32.DeleteObject(win32.HGDIOBJ(brush))
}

// Draw an arrow from start to end point
draw_arrow :: proc(start_x, start_y, end_x, end_y: f32, r, g, b: u8, thickness: i32 = 3) {
    // Draw main line
    draw_line(start_x, start_y, end_x, end_y, r, g, b, thickness)
    
    // Calculate arrow head
    dx := end_x - start_x
    dy := end_y - start_y
    length := util.sqrt(dx*dx + dy*dy)
    
    if length < 10 do return // Too short for arrow head
    
    // Normalize direction
    norm_x := dx / length
    norm_y := dy / length
    
    // Arrow head size
    head_length: f32 = 15
    head_width: f32 = 8
    
    // Calculate arrow head points
    head_back_x := end_x - norm_x * head_length
    head_back_y := end_y - norm_y * head_length
    
    // Perpendicular vector for arrow head width
    perp_x := -norm_y * head_width
    perp_y := norm_x * head_width
    
    // Arrow head points
    head_left_x := head_back_x + perp_x
    head_left_y := head_back_y + perp_y
    head_right_x := head_back_x - perp_x
    head_right_y := head_back_y - perp_y
    
    // Draw arrow head lines
    draw_line(end_x, end_y, head_left_x, head_left_y, r, g, b, thickness)
    draw_line(end_x, end_y, head_right_x, head_right_y, r, g, b, thickness)
}

// Simple text rendering using rectangles to form letters
draw_text :: proc(text: string, x, y: f32, size: f32, r, g, b: u8) {
    letter_width := size * 0.6
    letter_height := size
    spacing := size * 0.1
    
    current_x := x
    
    for char in text {
        switch char {
        case 'V':
            // Draw V as two diagonal lines
            draw_rect(util.rect(current_x, y, size*0.2, letter_height*0.8), r, g, b)
            draw_rect(util.rect(current_x + size*0.5, y, size*0.2, letter_height*0.8), r, g, b)
            draw_rect(util.rect(current_x + size*0.2, y + letter_height*0.8, size*0.1, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + size*0.3, y + letter_height*0.8, size*0.1, size*0.2), r, g, b)
        case 'I':
            // Draw I as vertical line with horizontal lines at top and bottom
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.4, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
        case 'C':
            // Draw C as rectangle with right side missing
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
        case 'T':
            // Draw T as horizontal line at top with vertical line in middle
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.4, y, size*0.2, letter_height), r, g, b)
        case 'O':
            // Draw O as hollow rectangle
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
        case 'R':
            // Draw R as P with diagonal line
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y, letter_width*0.8, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, letter_width*0.6, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.6, y, size*0.2, letter_height*0.4), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.4, y + letter_height*0.6, size*0.4, size*0.2), r, g, b)
        case 'Y':
            // Draw Y as two diagonal lines meeting in middle with vertical line
            draw_rect(util.rect(current_x, y, size*0.2, letter_height*0.5), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y, size*0.2, letter_height*0.5), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.4, y + letter_height*0.5, size*0.2, letter_height*0.5), r, g, b)
        case 'Q':
            // Draw Q as O with diagonal line
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.6, y + letter_height*0.6, size*0.3, size*0.2), r, g, b)
        case 'F':
            // Draw F as vertical line with two horizontal lines
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y, letter_width*0.8, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, letter_width*0.6, size*0.2), r, g, b)
        case 'L':
            // Draw L as vertical line with horizontal line at bottom
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
        case 'A':
            // Draw A as triangle shape
            draw_rect(util.rect(current_x + letter_width*0.4, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, size*0.2, letter_height*0.6), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y + letter_height*0.4, size*0.2, letter_height*0.6), r, g, b)
        case 'S':
            // Draw S as curved lines (simplified)
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y, size*0.2, letter_height*0.5), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y + letter_height*0.4, size*0.2, letter_height*0.6), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
        case 'H':
            // Draw H as two vertical lines with horizontal connector
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, letter_width, size*0.2), r, g, b)
        case 'D':
            // Draw D as rectangle with curved right side (simplified)
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y, letter_width*0.8, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.6, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width*0.8, size*0.2), r, g, b)
        case 'M':
            // Draw M as two vertical lines with diagonal connectors
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.8, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.2, y, size*0.2, letter_height*0.6), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.6, y, size*0.2, letter_height*0.6), r, g, b)
        case 'G':
            // Draw G as C with horizontal line
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.6, y + letter_height*0.4, letter_width*0.4, size*0.2), r, g, b)
            draw_rect(util.rect(current_x + letter_width*0.6, y + letter_height*0.4, size*0.2, letter_height*0.5), r, g, b)
        case 'E':
            // Draw E as vertical line with three horizontal lines
            draw_rect(util.rect(current_x, y, size*0.2, letter_height), r, g, b)
            draw_rect(util.rect(current_x, y, letter_width, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.4, letter_width*0.8, size*0.2), r, g, b)
            draw_rect(util.rect(current_x, y + letter_height*0.8, letter_width, size*0.2), r, g, b)
        case ' ':
            // Space - just advance position
        }
        
        current_x += letter_width + spacing
    }
}

// Draw a button (rectangle with border)
draw_button :: proc(x, y, width, height: f32, text: string, bg_r, bg_g, bg_b, text_r, text_g, text_b: u8) {
    // Background
    draw_rect(util.rect(x, y, width, height), bg_r, bg_g, bg_b)
    
    // Border
    border_thickness: f32 = 2
    draw_rect(util.rect(x, y, width, border_thickness), 255, 255, 255) // Top
    draw_rect(util.rect(x, y, border_thickness, height), 255, 255, 255) // Left
    draw_rect(util.rect(x + width - border_thickness, y, border_thickness, height), 255, 255, 255) // Right
    draw_rect(util.rect(x, y + height - border_thickness, width, border_thickness), 255, 255, 255) // Bottom
    
    // Text (centered)
    text_size: f32 = height * 0.4
    text_width := f32(len(text)) * text_size * 0.7 // Approximate text width
    text_x := x + (width - text_width) / 2
    text_y := y + (height - text_size) / 2
    draw_text(text, text_x, text_y, text_size, text_r, text_g, text_b)
}

// Draw a spell slot with cooldown overlay
draw_spell_slot :: proc(x, y, size: f32, key_text: string, cooldown_remaining, max_cooldown: f32, is_hovered: bool) {
    // Background (dark gray)
    bg_color := is_hovered ? u8(80) : u8(60)
    draw_rect(util.rect(x, y, size, size), bg_color, bg_color, bg_color)
    
    // Border (white)
    border_thickness: f32 = 2
    draw_rect(util.rect(x, y, size, border_thickness), 255, 255, 255) // Top
    draw_rect(util.rect(x, y, border_thickness, size), 255, 255, 255) // Left
    draw_rect(util.rect(x + size - border_thickness, y, border_thickness, size), 255, 255, 255) // Right
    draw_rect(util.rect(x, y + size - border_thickness, size, border_thickness), 255, 255, 255) // Bottom
    
    // Key label (bottom right corner)
    key_size: f32 = size * 0.25
    key_x := x + size - key_size * 1.5
    key_y := y + size - key_size * 1.2
    draw_text(key_text, key_x, key_y, key_size, 255, 255, 255)
    
    // Cooldown overlay (if on cooldown)
    if cooldown_remaining > 0 {
        // Dark overlay
        cooldown_alpha := cooldown_remaining / max_cooldown
        overlay_darkness := u8(150 * cooldown_alpha)
        draw_rect(util.rect(x + border_thickness, y + border_thickness, 
                          size - 2*border_thickness, size - 2*border_thickness), 
                 0, 0, overlay_darkness)
        
        // Cooldown text (center)
        cooldown_str := format_cooldown(cooldown_remaining)
        text_size: f32 = size * 0.3
        text_x := x + size/2 - f32(len(cooldown_str)) * text_size * 0.3
        text_y := y + size/2 - text_size/2
        draw_text(cooldown_str, text_x, text_y, text_size, 255, 255, 0) // Yellow
    }
}

// Helper function to format cooldown time
format_cooldown :: proc(time: f32) -> string {
    if time <= 0 do return ""
    
    // Simple integer conversion
    seconds := i32(time + 0.5) // Round up
    if seconds <= 0 do return ""
    
    // Convert to string manually since we don't have dynamic allocation
    switch seconds {
    case 1: return "1"
    case 2: return "2"
    case 3: return "3"
    case 4: return "4"
    case 5: return "5"
    case 6: return "6"
    case 7: return "7"
    case 8: return "8"
    case 9: return "9"
    case: return "9+"
    }
}

// Check if mouse is over a rectangle
is_mouse_over_rect :: proc(mouse_x, mouse_y: i32, rect_x, rect_y, rect_width, rect_height: f32) -> bool {
    return f32(mouse_x) >= rect_x && f32(mouse_x) <= rect_x + rect_width &&
           f32(mouse_y) >= rect_y && f32(mouse_y) <= rect_y + rect_height
}

// Draw tooltip
draw_tooltip :: proc(x, y: f32, text: string) {
    tooltip_width: f32 = f32(len(text)) * 12 + 10
    tooltip_height: f32 = 30
    
    // Background
    draw_rect(util.rect(x, y - tooltip_height, tooltip_width, tooltip_height), 40, 40, 40)
    
    // Border
    draw_rect(util.rect(x, y - tooltip_height, tooltip_width, 2), 200, 200, 200) // Top
    draw_rect(util.rect(x, y - tooltip_height, 2, tooltip_height), 200, 200, 200) // Left
    draw_rect(util.rect(x + tooltip_width - 2, y - tooltip_height, 2, tooltip_height), 200, 200, 200) // Right
    draw_rect(util.rect(x, y - 2, tooltip_width, 2), 200, 200, 200) // Bottom
    
    // Text
    draw_text(text, x + 5, y - tooltip_height + 5, 16, 255, 255, 255)
}

// Present the frame (swap buffers)
present :: proc() {
    // In GDI, drawing is immediate, so we just need to validate
    win32.ValidateRect(render_ctx.hwnd, nil)
}

// Cleanup renderer
cleanup_renderer :: proc() {
    if render_ctx.hdc != nil {
        win32.ReleaseDC(render_ctx.hwnd, render_ctx.hdc)
    }
    if render_ctx.hwnd != nil {
        win32.DestroyWindow(render_ctx.hwnd)
    }
}
