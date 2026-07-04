package main

import sdl "vendor:sdl3"

Mouse_Lock_Id :: enum {
	None,
}

Mouse :: struct {
	position:      sdl.FPoint,
	window:        ^sdl.Window,
	lock_id:       Mouse_Lock_Id,
	left:          bool,
	left_clicked:  bool,
	left_previous: bool,
	locked:        bool,
}

update_mouse :: proc(mouse: ^Mouse) {
	mouse.window = sdl.GetMouseFocus()
	mouse_buttons := sdl.GetMouseState(&mouse.position.x, &mouse.position.y)

	mouse.left = .LEFT in mouse_buttons
	mouse.left_clicked = mouse.left && !mouse.left_previous
	mouse.left_previous = mouse.left

	if mouse.left && !mouse.left_clicked && !mouse.locked {
		mouse.locked = true
		mouse.lock_id = .None
	}

	if !mouse.left {
		mouse.locked = false
	}
}
