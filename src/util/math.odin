package util

// Vector2 represents a 2D vector with x and y components
Vector2 :: struct {
    x: f32,
    y: f32,
}

// Rectangle represents a rectangle with position and size
Rectangle :: struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
}

// Create a new Vector2
vec2 :: proc(x, y: f32) -> Vector2 {
    return Vector2{x, y}
}

// Create a new Rectangle
rect :: proc(x, y, width, height: f32) -> Rectangle {
    return Rectangle{x, y, width, height}
}

// Clamp a value between min and max
clamp :: proc(value, min_val, max_val: f32) -> f32 {
    if value < min_val do return min_val
    if value > max_val do return max_val
    return value
}

// Check if a point is inside a rectangle
point_in_rect :: proc(point: Vector2, rectangle: Rectangle) -> bool {
    return point.x >= rectangle.x && 
           point.x <= rectangle.x + rectangle.width &&
           point.y >= rectangle.y && 
           point.y <= rectangle.y + rectangle.height
}

// Check if two rectangles overlap
rects_overlap :: proc(a, b: Rectangle) -> bool {
    return a.x < b.x + b.width &&
           a.x + a.width > b.x &&
           a.y < b.y + b.height &&
           a.y + a.height > b.y
}

// Keep a rectangle within bounds
clamp_rect_to_bounds :: proc(rect: ^Rectangle, bounds: Rectangle) {
    rect.x = clamp(rect.x, bounds.x, bounds.x + bounds.width - rect.width)
    rect.y = clamp(rect.y, bounds.y, bounds.y + bounds.height - rect.height)
}
