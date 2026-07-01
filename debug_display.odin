package main

import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Debug_Display :: struct {
	glyph_atlas:    [95]sdl.FRect,
	video_textures: [2]^sdl.Texture,
	glyph_texture:  ^sdl.Texture,
	window:         ^sdl.Window,
	renderer:       ^sdl.Renderer,
}

FONT_FILE    :: ""
FONT_PT_SIZE : f32 : 13.0
FONT_HEIGHT  : f32 : 16.0
FONT_WIDTH   : f32 : 8.0

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

	glyph_string: [95]u8
	glyph_x: f32 = 0.0
	for glyph_index in 0..<95 {
		glyph_string[glyph_index] = u8(glyph_index) + 32
		display.glyph_atlas[glyph_index].x = glyph_x
		display.glyph_atlas[glyph_index].w = FONT_WIDTH
		display.glyph_atlas[glyph_index].h = FONT_HEIGHT
		glyph_x += FONT_WIDTH
	}

	font := ttf.OpenFont(FONT_FILE, FONT_PT_SIZE)
	if font == nil {
		fmt.eprintfln("TTF OpenFont error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
	}
	defer ttf.CloseFont(font)

	glyph_surface := ttf.RenderText_Blended(font, cstring(&glyph_string[0]), 0, { 0xFF, 0xFF, 0xFF, 0xFF })
	if glyph_surface == nil {
		fmt.eprintfln("TTF RenderText_Blended error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
	}
	defer sdl.DestroySurface(glyph_surface)

	display.glyph_texture = sdl.CreateTextureFromSurface(display.renderer, glyph_surface)
	if display.glyph_texture == nil {
		fmt.eprintfln("SDL CreateTextureFromSurface error: %v", sdl.GetError())
		sdl.DestroyTexture(display.video_textures[1])
		sdl.DestroyTexture(display.video_textures[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
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

RGBA_BLACK     : sdl.Color : { 0x00, 0x00, 0x00, 0xFF }
RGBA_DARK_GRAY : sdl.Color : { 0x40, 0x40, 0x40, 0xFF }
RGBA_GRAY      : sdl.Color : { 0x80, 0x80, 0x80, 0xFF }
RGBA_LIGH_GRAY : sdl.Color : { 0xC0, 0xC0, 0xC0, 0xFF }
RGBA_WHITE     : sdl.Color : { 0xFF, 0xFF, 0xFF, 0xFF }

draw_text :: proc(display: Debug_Display, text: string, position: sdl.FPoint, color: sdl.Color = RGBA_WHITE) {
	sdl.SetTextureColorMod(display.glyph_texture, color.r, color.g, color.b)

	destination: sdl.FRect = { position.x, position.y, FONT_WIDTH, FONT_HEIGHT }

	for character in text {
		if character == '\n' {
			destination.y += FONT_HEIGHT
			destination.x = position.x
			continue
		}
		if u8(character) < 32 || u8(character) > 126 {
			continue
		}
		source := display.glyph_atlas[u8(character) - 32]
		sdl.RenderTexture(display.renderer, display.glyph_texture, &source, &destination)
	}
}

draw_rect_lines :: proc(display: Debug_Display, rect: sdl.FRect, line_width: f32 = 2, color: sdl.Color = RGBA_GRAY) {
	rects: [4]sdl.FRect = {
		sdl.FRect { rect.x, rect.y, rect.w, line_width },
		sdl.FRect { rect.x + rect.w - line_width, rect.y + line_width, line_width, rect.h - 2 * line_width },
		sdl.FRect { rect.x, rect.y + rect.h - line_width, rect.w, line_width },
		sdl.FRect { rect.x, rect.y + line_width, line_width, rect.h - 2 * line_width },
	}
	sdl.SetRenderDrawColor(display.renderer, color.r, color.g, color.b, color.a)
	sdl.RenderFillRects(display.renderer, &rects[0], 4)
}

render_clear :: proc(display: Debug_Display, color: sdl.Color = RGBA_BLACK) {
	sdl.SetRenderDrawColor(display.renderer, color.r, color.g, color.b, color.a)
	sdl.RenderClear(display.renderer)
}
