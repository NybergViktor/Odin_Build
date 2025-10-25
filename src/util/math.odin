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

// Obstacle represents a barrier that blocks projectiles but not flash
Obstacle :: struct {
    rect: Rectangle,
    color: struct { r, g, b: u8 },
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

// Calculate distance between two points
distance :: proc(a, b: Vector2) -> f32 {
    dx := b.x - a.x
    dy := b.y - a.y
    return sqrt(dx*dx + dy*dy)
}

// Square root function
sqrt :: proc(x: f32) -> f32 {
    if x <= 0 do return 0
    
    // Newton's method for square root
    guess: f32 = x
    for i in 0..<10 { // 10 iterations should be enough
        guess = (guess + x/guess) * 0.5
    }
    return guess
}

// Cosine function (Taylor series approximation)
cos :: proc(x: f32) -> f32 {
    // Normalize angle to [-PI, PI]
    PI :: 3.14159265358979323846
    angle := x
    for angle > PI do angle -= 2 * PI
    for angle < -PI do angle += 2 * PI
    
    // Taylor series: cos(x) = 1 - x²/2! + x⁴/4! - x⁶/6! + ...
    result: f32 = 1.0
    term: f32 = 1.0
    
    for i in 1..=8 { // 8 terms should be enough for reasonable accuracy
        term *= -angle * angle / f32(2*i-1) / f32(2*i)
        result += term
    }
    
    return result
}

// Sine function (Taylor series approximation)
sin :: proc(x: f32) -> f32 {
    // Normalize angle to [-PI, PI]
    PI :: 3.14159265358979323846
    angle := x
    for angle > PI do angle -= 2 * PI
    for angle < -PI do angle += 2 * PI
    
    // Taylor series: sin(x) = x - x³/3! + x⁵/5! - x⁷/7! + ...
    result: f32 = angle
    term: f32 = angle
    
    for i in 1..=8 { // 8 terms should be enough for reasonable accuracy
        term *= -angle * angle / f32(2*i) / f32(2*i+1)
        result += term
    }
    
    return result
}
