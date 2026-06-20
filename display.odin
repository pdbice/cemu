package main

import "core:fmt"
import sdl "vendor:sdl3"

Video_Display :: struct {
	window:   ^sdl.Window,
	renderer: ^sdl.Renderer,
	texture:  [2]^sdl.Texture,
}

init_video_display :: proc(display: ^Video_Display) -> bool {
	display.window = sdl.CreateWindow("Chip-8", 1024, 512, { .RESIZABLE })
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

	display.texture[0] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 64, 32)
	if display.texture[0] == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.texture[0], .NEAREST)

	display.texture[1] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 128, 64)
	if display.texture[1] == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		sdl.DestroyTexture(display.texture[0])
		sdl.DestroyRenderer(display.renderer)
		sdl.DestroyWindow(display.window)
		return false
	}
	sdl.SetTextureScaleMode(display.texture[1], .NEAREST)

	return true
}

destroy_video_display :: proc(display: ^Video_Display) {
	sdl.DestroyTexture(display.texture[1])
	sdl.DestroyTexture(display.texture[0])
	sdl.DestroyRenderer(display.renderer)
	sdl.DestroyWindow(display.window)
}

draw_video_display :: proc(display: Video_Display, video: Video) {
	pitch: i32
	pixels: [^]u32

	texture: ^sdl.Texture
	if video.length == 2048 {
		texture = display.texture[0]
	} else {
		texture = display.texture[1]
	}

	sdl.LockTexture(texture, nil, cast(^rawptr)&pixels, &pitch)

	for pixel_index in 0..<video.length {
		if video.framebuffer[pixel_index] == 1 {
			pixels[pixel_index] = 0xFF808080
		} else {
			pixels[pixel_index] = 0xFF000000
		}
	}

	sdl.UnlockTexture(texture)
	sdl.RenderTexture(display.renderer, texture, nil, nil)
	sdl.RenderPresent(display.renderer)
}
