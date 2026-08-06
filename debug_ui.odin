package main

import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

FONT_FILE        :: "./assets/LiberationMono-Regular.ttf"
FONT_DPI         : i32 : 96
FONT_PT_SIZE     : f32 : 11.0
FONT_HEIGHT      : f32 : 17.0
FONT_WIDTH       : f32 : 9.0
HALF_FONT_HEIGHT : f32 : FONT_HEIGHT / 2.0
HALF_FONT_WIDTH  : f32 : FONT_WIDTH / 2.0

BLACK      : sdl.Color : { 0x00, 0x00, 0x00, 0xFF }
DARK_GRAY  : sdl.Color : { 0x40, 0x40, 0x40, 0xFF }
GRAY       : sdl.Color : { 0x80, 0x80, 0x80, 0xFF }
LIGHT_GRAY : sdl.Color : { 0xC0, 0xC0, 0xC0, 0xFF }
WHITE      : sdl.Color : { 0xFF, 0xFF, 0xFF, 0xFF }

Debug_Display :: struct {
	video_textures: [2]^sdl.Texture,
	glyph_texture:  ^sdl.Texture,
	window:         ^sdl.Window,
	renderer:       ^sdl.Renderer,
	width:          i32,
	height:         i32,
}

Mouse_Lock_Id :: enum {
	None,
	Reset_Button,
	Continue_Button,
	Pause_Button,
	Step_Button,
}

Mouse :: struct {
	position:      sdl.FPoint,
	lock_offset:   sdl.FPoint,
	window:        ^sdl.Window,
	lock_id:       Mouse_Lock_Id,
	left:          bool,
	left_clicked:  bool,
	left_previous: bool,
	locked:        bool,
}

init_debug_display :: proc(display: ^Debug_Display) -> bool {
	display.window = sdl.CreateWindow("Chip-8 Debugger", 1024, 768, { .RESIZABLE, .MAXIMIZED })
	if display.window == nil {
		fmt.eprintfln("SDL CreateWindow error: %v", sdl.GetError())
		return false
	}

	display.renderer = sdl.CreateRenderer(display.window, nil)
	if display.renderer == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		sdl.DestroyWindow(display.window)
		return false
	}

	display.video_textures[0] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 64, 32)
	if display.video_textures[0] == nil {
		fmt.eprintfln("SDL CreateTexture error: %v", sdl.GetError())
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.video_textures[0], .NEAREST)

	display.video_textures[1] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 128, 64)
	if display.video_textures[1] == nil {
		fmt.eprintfln("SDL CreateTexture error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.video_textures[1], .NEAREST)

	if !ttf.Init() {
		fmt.eprintfln("TTF Init error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	defer ttf.Quit()

	font := ttf.OpenFont(FONT_FILE, FONT_PT_SIZE)
	if font == nil {
		fmt.eprintfln("TTF OpenFont error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	defer ttf.CloseFont(font)
	ttf.SetFontSizeDPI(font, FONT_PT_SIZE, FONT_DPI, FONT_DPI)

	glyph_string: [95]u8
	for &glyph_character, glyph_index in glyph_string {
		glyph_character = u8(glyph_index) + 32
	}

	glyph_surface := ttf.RenderText_Blended(font, cstring(&glyph_string[0]), 0, { 0xFF, 0xFF, 0xFF, 0xFF })
	if glyph_surface == nil {
		fmt.eprintfln("TTF RenderText_Blended error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	defer sdl.DestroySurface(glyph_surface)

	display.glyph_texture = sdl.CreateTextureFromSurface(display.renderer, glyph_surface)
	if display.glyph_texture == nil {
		fmt.eprintfln("SDL CreateTextureFromSurface error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}

	return true
}

destroy_debug_display :: proc(display: ^Debug_Display) {
	sdl.DestroyTexture(display.glyph_texture)
	sdl.DestroyTexture(display.video_textures[1])
	sdl.DestroyTexture(display.video_textures[0])
	sdl.DestroyRenderer(display.renderer)
	sdl.DestroyWindow(display.window)
}

draw_debug_state_control :: proc(display: Debug_Display, mouse: ^Mouse) -> [4]bool {
	buttons: [4]bool

	buttons[0] = button(display, &{  10, 10, 100, 34 }, "Reset", mouse, .Reset_Button)
	buttons[1] = button(display, &{ 120, 10, 100, 34 }, "Continue", mouse, .Continue_Button)
	buttons[2] = button(display, &{ 230, 10, 100, 34 }, "Pause", mouse, .Pause_Button)
	buttons[3] = button(display, &{ 340, 10, 100, 34 }, "Step", mouse, .Step_Button)

	render_horizontal_line(display.renderer, { 10.0, 54.0 }, f32(display.width) - 20.0)

	return buttons
}

button :: proc(display: Debug_Display, rect: ^sdl.FRect, text: string, mouse: ^Mouse, mouse_lock_id: Mouse_Lock_Id) -> bool {
	clicked := false

	bg_color := GRAY
	fg_color := BLACK

	if mouse_in_rect(display.window, mouse^, rect^) && (!mouse.locked || mouse.lock_id == mouse_lock_id) {
		if mouse.left {
			bg_color = DARK_GRAY
			fg_color = WHITE
			mouse.locked = true
			mouse.lock_id = mouse_lock_id
			clicked = mouse.left_clicked
		} else {
			bg_color = LIGHT_GRAY
		}
	} else if mouse.lock_id == mouse_lock_id {
		mouse.lock_id = .None
	}

	sdl.SetRenderDrawColor(display.renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
	sdl.RenderFillRect(display.renderer, rect)

	text_position := sdl.FPoint {
		rect.x + (rect.w / 2) - (f32(len(text)) * HALF_FONT_WIDTH),
		rect.y + (rect.h / 2) - HALF_FONT_HEIGHT,
	}
	draw_text(display, text, text_position, fg_color)

	return clicked
}

draw_text :: proc(display: Debug_Display, text: string, position: sdl.FPoint, color: sdl.Color = WHITE) {
	sdl.SetTextureColorMod(display.glyph_texture, color.r, color.g, color.b)

	source := sdl.FRect { 0.0, 0.0, FONT_WIDTH, FONT_HEIGHT }
	destination := sdl.FRect { position.x, position.y, FONT_WIDTH, FONT_HEIGHT }

	for character in text {
		if character == '\n' {
			destination.y += FONT_HEIGHT
			destination.x = position.x
			continue
		}
		if character < 32 || character > 126 {
			continue
		}
		source.x = f32(character - 32) * FONT_WIDTH
		sdl.RenderTexture(display.renderer, display.glyph_texture, &source, &destination)
		destination.x += FONT_WIDTH
	}
}

render_horizontal_line :: proc(renderer: ^sdl.Renderer, position: sdl.FPoint, length: f32, line_width: f32 = 2, color: sdl.Color = GRAY) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	rect := sdl.FRect { position.x, position.y, length, line_width }
	sdl.RenderFillRect(renderer, &rect)
}

render_rect_lines :: proc(renderer: ^sdl.Renderer, rect: sdl.FRect, line_width: f32 = 2, color: sdl.Color = GRAY) {
	rects := [4]sdl.FRect {
		{ rect.x, rect.y, rect.w, line_width },
		{ rect.x + rect.w - line_width, rect.y + line_width, line_width, rect.h - 2 * line_width },
		{ rect.x, rect.y + rect.h - line_width, rect.w, line_width },
		{ rect.x, rect.y + line_width, line_width, rect.h - 2 * line_width },
	}
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderFillRects(renderer, &rects[0], 4)
}

render_clear :: proc(renderer: ^sdl.Renderer, color: sdl.Color = BLACK) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderClear(renderer)
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
		mouse.lock_id = .None
	}
}

mouse_in_rect :: #force_inline proc(window: ^sdl.Window, mouse: Mouse, rect: sdl.FRect) -> bool {
	return mouse.window == window && sdl.PointInRectFloat(mouse.position, rect)
}

lock_mouse :: proc(mouse: ^Mouse, lock_id: Mouse_Lock_Id, rect: sdl.FRect) {
	mouse.locked = true
	mouse.lock_id = lock_id
	mouse.lock_offset.x = mouse.position.x - rect.x
	mouse.lock_offset.y = mouse.position.y - rect.y
}
