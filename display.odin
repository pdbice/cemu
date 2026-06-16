package main

import "core:fmt"
import sdl "vendor:sdl3"

Video_Display :: struct {
	window:        ^sdl.Window,
	renderer:      ^sdl.Renderer,
	texture_lores: ^sdl.Texture,
	texture_hires: ^sdl.Texture,
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

	display.texture_lores = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 64, 32)
	if display.texture_lores == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.texture_lores, .NEAREST)

	display.texture_hires = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 128, 64)
	if display.texture_hires == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		sdl.DestroyTexture(display.texture_lores)
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.texture_hires, .NEAREST)

	return true
}

destroy_video_display :: proc(display: ^Video_Display) {
	sdl.DestroyTexture(display.texture_hires)
	sdl.DestroyTexture(display.texture_lores)
	sdl.DestroyRenderer(display.renderer)
	sdl.DestroyWindow(display.window)
}

VIDEO_FOREGROUND : u32 : 0xFF808080
VIDEO_BACKGROUND : u32 : 0xFF000000

draw_video_display :: proc(display: Video_Display, video: Video) {
	pitch: i32
	pixels: [^]u32

	texture: ^sdl.Texture
	if video.length == 2048 {
		texture = display.texture_lores
	} else {
		texture = display.texture_hires
	}

	sdl.LockTexture(texture, nil, cast(^rawptr)&pixels, &pitch)

	for pixel_index in 0..<video.length {
		if video.framebuffer[pixel_index] == 1 {
			pixels[pixel_index] = VIDEO_FOREGROUND
		} else {
			pixels[pixel_index] = VIDEO_BACKGROUND
		}
	}

	sdl.UnlockTexture(texture)
	sdl.RenderTexture(display.renderer, texture, nil, nil)
	sdl.RenderPresent(display.renderer)
}
