package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"
import sdl "vendor:sdl3"

main :: proc() {
	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer check_tracking_allocator(&tracking_allocator)
	}

	if len(os.args) < 2 {
		usage()
		return
	}

	debug := false
	if len(os.args) > 2 {
		for argument in os.args[2:] {
			switch argument {
			case "-debug":
				debug = true
			case:
				usage()
				return
			}
		}
	}

	rom, read_file_ok := os.read_entire_file_from_filename(os.args[1])
	if !read_file_ok {
		fmt.eprintfln("Could not read file %v", os.args[1])
		return
	}
	defer delete(rom)

	if !sdl.Init({ .VIDEO, .AUDIO }) {
		fmt.eprintfln("SDL Init error: %v", sdl.GetError())
		return
	}
	defer sdl.Quit()

	video_display: Video_Display
	if !init_video_display(&video_display) {
		return
	}
	defer destroy_video_display(&video_display)

	audio: Audio
	if !init_audio(&audio) {
		return
	}
	defer sdl.DestroyAudioStream(audio.stream)

	if debug {
	} else {
		main_loop(rom, video_display, audio)
	}
}

main_loop :: proc(rom: []u8, display: Video_Display, audio: Audio) {
	vm: Virtual_Machine
	load_rom(&vm, rom)

	for {
		frame_start := time.tick_now()

		sdl_event: sdl.Event
		window_resized := false

		for sdl.PollEvent(&sdl_event) {
			#partial switch sdl_event.type {
			case .QUIT:
				return
			case .WINDOW_RESIZED:
				window_resized = true
			case .KEY_DOWN:
				#partial switch sdl_event.key.scancode {
				case .ESCAPE:
					return
				case .F4:
					mem.zero(&vm, size_of(Virtual_Machine))
					load_rom(&vm, rom)
				}
			}
		}

		update_keypad(&vm.keypad)
		vm.vblank_interrupt = false

		for instructions_per_frame in 0..<12 {
			fetch_and_execute(&vm)
		}

		if vm.vblank_interrupt || window_resized {
			draw_video_display(display, vm.framebuffer)
		}
	}
}

usage :: proc() {
	fmt.println("Usage:")
	fmt.println("\tcemu [ROM file] [flags]")
	fmt.println()
	fmt.println("\tFlags")
	fmt.println()
	fmt.println("\t-debug")
	fmt.println("\t\tRun the emulator in debug mode")
	fmt.println()
}

check_tracking_allocator :: proc(tracking_allocator: ^mem.Tracking_Allocator) {
	if len(tracking_allocator.allocation_map) > 0 {
		fmt.eprintfln("%v allocations not freed:", len(tracking_allocator.allocation_map))
		for _, entry in tracking_allocator.allocation_map {
			fmt.eprintfln("- %v bytes @ %v", entry.size, entry.location)
		}
	}
	mem.tracking_allocator_destroy(tracking_allocator)
}
