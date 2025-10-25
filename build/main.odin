package main

import "core:fmt"
import win32 "core:sys/windows"

// Program entry point
main :: proc() {
    // Print a greeting
  //  fmt.println("Hello, Odin!")

    // Simple window using core:sys/windows for Windows
    when ODIN_OS == .Windows {
        
        
        // Create a simple message box
        result := win32.MessageBoxW(
            nil,
            win32.utf8_to_wstring("Hello, Odin!"),
            win32.utf8_to_wstring("Greeting"),
            win32.MB_OK
        )
    }
}
