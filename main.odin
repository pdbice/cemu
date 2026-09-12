package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:time"
import sdl "vendor:sdl3"

WINDOW_WIDTH           :: 1024
WINDOW_HEIGHT          :: 512
LOW_RESOLUTION_WIDTH   :: 64
LOW_RESOLUTION_HEIGHT  :: 32
HIGH_RESOLUTION_WIDTH  :: 128
HIGH_RESOLUTION_HEIGHT :: 64

AUDIO_BUFFER_LENGTH : i32 : 2000
AUDIO_BUFFER_SIZE   : i32 : AUDIO_BUFFER_LENGTH * size_of(f32)
AUDIO_SAMPLE_RATE   : f32 : 44100
AUDIO_AMPLITUDE     : f32 : 0.75
AUDIO_FREQUENCY     : f32 : 441
DOUBLE_PI           : f32 : 2.0 * math.PI

DISPLAY_FOREGROUND :: 0xFF808080
DISPLAY_BACKGROUND :: 0xFF000000

FPS_60_DURATION : time.Duration : 16666667

Display :: struct {
	video_textures: [2]^sdl.Texture,
	renderer:       ^sdl.Renderer,
}

Audio :: struct {
	buffer: [AUDIO_BUFFER_LENGTH]f32,
	stream: ^sdl.AudioStream,
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

	window := sdl.CreateWindow("Chip-8", WINDOW_WIDTH, WINDOW_HEIGHT, { .RESIZABLE })
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

	display.video_textures[0] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, LOW_RESOLUTION_WIDTH, LOW_RESOLUTION_HEIGHT)
	if display.video_textures[0] == nil {
		fmt.eprintfln("SDL CreateTexture error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyTexture(display.video_textures[0])
	sdl.SetTextureScaleMode(display.video_textures[0], .NEAREST)

	display.video_textures[1] = sdl.CreateTexture(display.renderer, .ARGB8888, .STREAMING, HIGH_RESOLUTION_WIDTH, HIGH_RESOLUTION_HEIGHT)
	if display.video_textures[1] == nil {
		fmt.eprintfln("SDL CreateTexture error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyTexture(display.video_textures[1])
	sdl.SetTextureScaleMode(display.video_textures[1], .NEAREST)

	audio: Audio

	audio_spec := sdl.AudioSpec {
		.F32,
		1,
		i32(AUDIO_SAMPLE_RATE),
	}
	audio.stream = sdl.OpenAudioDeviceStream(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio_spec, nil, nil)
	if audio.stream == nil {
		fmt.eprintfln("SDL OpenAudioDeviceStream error: %v", sdl.GetError())
		return
	}
	defer sdl.DestroyAudioStream(audio.stream)

	phase: f32
	for &sample in audio.buffer {
		sample = math.sin_f32(phase) * AUDIO_AMPLITUDE
		phase += DOUBLE_PI * AUDIO_FREQUENCY / AUDIO_SAMPLE_RATE
		if phase > DOUBLE_PI {
			phase -= DOUBLE_PI
		}
	}

	main_loop(rom, variant, display, &audio)
}

main_loop :: proc(rom: []u8, variant: Variant, display: Display, audio: ^Audio) {
	vm: Virtual_Machine
	load_rom(&vm, rom)
	vm.variant = variant

	frame_duration: time.Duration
	for {
		frame_start := time.tick_now()

		vm.keypad.key_released = false

		sdl_event: sdl.Event
		for sdl.PollEvent(&sdl_event) {
			#partial switch sdl_event.type {
			case .QUIT:
				return
			case .KEY_UP:
				keypad_key_released :: proc(keypad: ^Keypad, keypad_key: u8) {
					keypad.state[keypad_key] = false
					keypad.wait_key = keypad_key
					keypad.key_released = true
				}
				#partial switch sdl_event.key.scancode {
				case .F4:
					mem.zero(&vm, size_of(Virtual_Machine))
					load_rom(&vm, rom)
					vm.variant = variant
				case  .X: keypad_key_released(&vm.keypad, 0)
				case ._1: keypad_key_released(&vm.keypad, 1)
				case ._2: keypad_key_released(&vm.keypad, 2)
				case ._3: keypad_key_released(&vm.keypad, 3)
				case  .Q: keypad_key_released(&vm.keypad, 4)
				case  .W: keypad_key_released(&vm.keypad, 5)
				case  .E: keypad_key_released(&vm.keypad, 6)
				case  .A: keypad_key_released(&vm.keypad, 7)
				case  .S: keypad_key_released(&vm.keypad, 8)
				case  .D: keypad_key_released(&vm.keypad, 9)
				case  .Z: keypad_key_released(&vm.keypad, 10)
				case  .C: keypad_key_released(&vm.keypad, 11)
				case ._4: keypad_key_released(&vm.keypad, 12)
				case  .R: keypad_key_released(&vm.keypad, 13)
				case  .F: keypad_key_released(&vm.keypad, 14)
				case  .V: keypad_key_released(&vm.keypad, 15)
				}
			case .KEY_DOWN:
				#partial switch sdl_event.key.scancode {
				case .ESCAPE:
					return
				case  .X: vm.keypad.state[ 0] = true
				case ._1: vm.keypad.state[ 1] = true
				case ._2: vm.keypad.state[ 2] = true
				case ._3: vm.keypad.state[ 3] = true
				case  .Q: vm.keypad.state[ 4] = true
				case  .W: vm.keypad.state[ 5] = true
				case  .E: vm.keypad.state[ 6] = true
				case  .A: vm.keypad.state[ 7] = true
				case  .S: vm.keypad.state[ 8] = true
				case  .D: vm.keypad.state[ 9] = true
				case  .Z: vm.keypad.state[10] = true
				case  .C: vm.keypad.state[11] = true
				case ._4: vm.keypad.state[12] = true
				case  .R: vm.keypad.state[13] = true
				case  .F: vm.keypad.state[14] = true
				case  .V: vm.keypad.state[15] = true
				}
			}
		}

		vm.vblank_interrupt = false

		for instructions_per_frame in 0..<12 {
			fetch_and_execute(&vm)
		}

		if vm.delay_timer > 0 {
			vm.delay_timer -= 1
		}
		if vm.sound_timer > 0 {
			vm.sound_timer -= 1
			if sdl.GetAudioStreamQueued(audio.stream) < AUDIO_BUFFER_SIZE {
				sdl.PutAudioStreamData(audio.stream, &audio.buffer, AUDIO_BUFFER_SIZE)
			}
			if sdl.AudioStreamDevicePaused(audio.stream) {
				sdl.ResumeAudioStreamDevice(audio.stream)
			}
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
