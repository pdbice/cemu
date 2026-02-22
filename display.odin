package main

import "core:fmt"
import sdl "vendor:sdl3"

Video_Display :: struct {
	window:   ^sdl.Window,
	renderer: ^sdl.Renderer,
	texture:  ^sdl.Texture,
}

VIDEO_DISPLAY_WIDTH  : i32 : 1024
VIDEO_DISPLAY_HEIGHT : i32 : 512

init_video_display :: proc(display: ^Video_Display) -> bool {
	display.window = sdl.CreateWindow("Chip-8", VIDEO_DISPLAY_WIDTH, VIDEO_DISPLAY_HEIGHT, { .RESIZABLE })
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

	display.texture = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 64, 32)
	if display.texture == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.texture, .NEAREST)

	return true
}

destroy_video_display :: proc(display: ^Video_Display) {
	sdl.DestroyTexture(display.texture)
	sdl.DestroyRenderer(display.renderer)
	sdl.DestroyWindow(display.window)
}

draw_video_display :: proc(display: Video_Display, framebuffer: [2048]u8) {
	pitch: i32
	pixels: [^]u32

	sdl.LockTexture(display.texture, nil, cast(^rawptr)&pixels, &pitch)

	sdl.UnlockTexture(display.texture)
	sdl.RenderTexture(display.renderer, display.texture, nil, nil)
	sdl.RenderPresent(display.renderer)
}
