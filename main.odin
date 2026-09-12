package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"
import sdl "vendor:sdl3"

DISPLAY_FOREGROUND :: 0xFF808080
DISPLAY_BACKGROUND :: 0xFF000000

FPS_60_DURATION : time.Duration : 16666667

Display :: struct {
	video_textures: [2]^sdl.Texture,
	renderer:       ^sdl.Renderer,
}

main :: proc() {
	if len(os.args) < 2 {
		usage()
		return
	}

	variant: Variant

	if len(os.args) > 2 {
		for argument in os.args[2:] {
			switch argument {
			case "-variant:modern":
				variant = .Superchip_Modern
			case "-variant:cosmac":
				variant = .Cosmac
			case:
				usage()
				return
			}
		}
	}

	rom, read_file_err := os.read_entire_file_from_path(os.args[1], context.allocator)
	if read_file_err != os.ERROR_NONE {
		fmt.eprintfln("Could not read file %v", os.args[1])
		return
	}
	defer delete(rom)

	display: Display

	if !sdl.Init({ .VIDEO, .AUDIO }) {
		fmt.eprintfln("SDL Init error: %v", sdl.GetError())
		return
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("Chip-8", 1024, 512, { .RESIZABLE })
	if window == nil {
		fmt.eprintfln("SDL CreateWindow error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyWindow(window)

	display.renderer = sdl.CreateRenderer(window, nil)
	if display.renderer == nil {
		fmt.eprintfln("SDL CreateRenderer error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyRenderer(display.renderer)

	display.video_textures[0] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 64, 32)
	if display.video_textures[0] == nil {
		fmt.eprintfln("SDL CreateTexture error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyTexture(display.video_textures[0])
	sdl.SetTextureScaleMode(display.video_textures[0], .NEAREST)

	display.video_textures[1] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, 128, 64)
	if display.video_textures[1] == nil {
		fmt.eprintfln("SDL CreateTexture error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyTexture(display.video_textures[1])
	sdl.SetTextureScaleMode(display.video_textures[1], .NEAREST)

	main_loop(rom, variant, display)
}

main_loop :: proc(rom: []u8, variant: Variant, display: Display) {
	audio: Audio
	if !init_audio(&audio) {
		return
	}
	defer sdl.DestroyAudioStream(audio.stream)

	vm: Virtual_Machine
	load_rom(&vm, rom)
	vm.variant = variant

	frame_duration: time.Duration
	for {
		frame_start := time.tick_now()

		sdl_event: sdl.Event
		for sdl.PollEvent(&sdl_event) {
			#partial switch sdl_event.type {
			case .QUIT:
				return
			case .KEY_DOWN:
				#partial switch sdl_event.key.scancode {
				case .ESCAPE:
					return
				case .F4:
					mem.zero(&vm, size_of(Virtual_Machine))
					load_rom(&vm, rom)
					vm.variant = variant
				}
			}
		}

		update_keypad(&vm.keypad)
		vm.vblank_interrupt = false

		for instructions_per_frame in 0..<12 {
			fetch_and_execute(&vm)
		}

		if vm.delay_timer > 0 {
			vm.delay_timer -= 1
		}
		if vm.sound_timer > 0 {
			vm.sound_timer -= 1
			play_audio(&audio)
		} else if !sdl.AudioStreamDevicePaused(audio.stream) {
			sdl.PauseAudioStreamDevice(audio.stream)
		}

		pitch: i32
		pixels: [^]u32

		texture: ^sdl.Texture
		if vm.video.length == 2048 {
			texture = display.video_textures[0]
		} else {
			texture = display.video_textures[1]
		}

		sdl.LockTexture(texture, nil, cast(^rawptr)&pixels, &pitch)

		for pixel_index in 0..<vm.video.length {
			if vm.video.framebuffer[pixel_index] == 1{
				pixels[pixel_index] = DISPLAY_FOREGROUND
			} else {
				pixels[pixel_index] = DISPLAY_BACKGROUND
			}
		}

		sdl.UnlockTexture(texture)
		sdl.RenderTexture(display.renderer, texture, nil, nil)
		sdl.RenderPresent(display.renderer)

		frame_duration = 0
		for frame_duration < FPS_60_DURATION {
			frame_duration = time.tick_since(frame_start)
		}
	}
}

usage :: proc() {
	fmt.println("Usage:")
	fmt.println("\tcemu [ROM file] [flags]")
	fmt.println()
	fmt.println("\tFlags")
	fmt.println()
	fmt.println("\t-variant:<variant>")
	fmt.println("\t\tSelects the Chip-8 variant to use")
	fmt.println("\t\t\t-variant:modern\tThe modern interpretation of the super chip variant")
	fmt.println("\t\t\t-variant:cosmac\tThe Chip-8 variant used by the Cosmac VIP")
	fmt.println()
}
