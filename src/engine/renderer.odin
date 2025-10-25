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
