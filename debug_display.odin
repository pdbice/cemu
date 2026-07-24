package main

import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Debug_Display :: struct {
	video_textures: [2]^sdl.Texture,
	glyph_texture:  ^sdl.Texture,
	window:         ^sdl.Window,
	renderer:       ^sdl.Renderer,
}

FONT_FILE        :: "./assets/LiberationMono-Regular.ttf"
FONT_PT_SIZE     : f32 : 11.0
FONT_HEIGHT      : f32 : 17.0
FONT_WIDTH       : f32 : 9.0
HALF_FONT_HEIGHT : f32 : FONT_HEIGHT / 2.0
HALF_FONT_WIDTH  : f32 : FONT_WIDTH / 2.0
FONT_DPI         : i32 : 96

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

RGBA_BLACK      : sdl.Color : { 0x00, 0x00, 0x00, 0xFF }
RGBA_DARK_GRAY  : sdl.Color : { 0x40, 0x40, 0x40, 0xFF }
RGBA_GRAY       : sdl.Color : { 0x80, 0x80, 0x80, 0xFF }
RGBA_LIGHT_GRAY : sdl.Color : { 0xC0, 0xC0, 0xC0, 0xFF }
RGBA_WHITE      : sdl.Color : { 0xFF, 0xFF, 0xFF, 0xFF }

button :: proc(display: Debug_Display, rect: ^sdl.FRect, text: []string, mouse: ^Mouse, mouse_lock_id: Mouse_Lock_Id) -> bool {
	clicked := false

	bg_color := RGBA_GRAY
	fg_color := RGBA_BLACK

	if mouse_in_rect(display.window, mouse^, rect^) && (!mouse.locked || mouse.lock_id == mouse_lock_id) {
		if mouse.left {
			bg_color = RGBA_DARK_GRAY
			fg_color = RGBA_WHITE
			mouse.locked = true
			mouse.lock_id = mouse_lock_id
			clicked = mouse.left_clicked
		} else {
			bg_color = RGBA_LIGHT_GRAY
		}
	} else if mouse.lock_id == mouse_lock_id {
		mouse.lock_id = .None
	}

	sdl.SetRenderDrawColor(display.renderer, bg_color.r, bg_color.g, bg_color.b, bg_color.a)
	sdl.RenderFillRect(display.renderer, rect)

	text_position: sdl.FPoint = {
		0,
		rect.y + (rect.h / 2) - (f32(len(text)) * HALF_FONT_HEIGHT),
	}
	middle_x := rect.x + (rect.w / 2)
	for line in text {
		text_position.x = middle_x - f32(len(line)) * HALF_FONT_WIDTH
		draw_text(display, line, text_position, fg_color)
		text_position.y += FONT_HEIGHT
	}

	return clicked
}

draw_text :: proc(display: Debug_Display, text: string, position: sdl.FPoint, color: sdl.Color = RGBA_WHITE) {
	sdl.SetTextureColorMod(display.glyph_texture, color.r, color.g, color.b)

	source: sdl.FRect = { 0.0, 0.0, FONT_WIDTH, FONT_HEIGHT }
	destination: sdl.FRect = { position.x, position.y, FONT_WIDTH, FONT_HEIGHT }

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

render_horizontal_line :: proc(renderer: ^sdl.Renderer, position: sdl.FPoint, length: f32, line_width: f32 = 2, color: sdl.Color = RGBA_GRAY) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	rect: sdl.FRect = { position.x, position.y, length, line_width }
	sdl.RenderFillRect(renderer, &rect)
}

render_rect_lines :: proc(renderer: ^sdl.Renderer, rect: sdl.FRect, line_width: f32 = 2, color: sdl.Color = RGBA_GRAY) {
	rects: [4]sdl.FRect = {
		sdl.FRect { rect.x, rect.y, rect.w, line_width },
		sdl.FRect { rect.x + rect.w - line_width, rect.y + line_width, line_width, rect.h - 2 * line_width },
		sdl.FRect { rect.x, rect.y + rect.h - line_width, rect.w, line_width },
		sdl.FRect { rect.x, rect.y + line_width, line_width, rect.h - 2 * line_width },
	}
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderFillRects(renderer, &rects[0], 4)
}

render_clear :: proc(renderer: ^sdl.Renderer, color: sdl.Color = RGBA_BLACK) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderClear(renderer)
}
