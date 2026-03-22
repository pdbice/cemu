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

	quirks: Quirks

	if len(os.args) > 2 {
		for argument in os.args[2:] {
			switch argument {
			case "-quirk:all":
				quirks.vf_reset = true
				quirks.shift = true
				quirks.memory = true
			case "-quirk:vf_reset":
				quirks.vf_reset = true
			case "-quirk:shift":
				quirks.shift = true
			case "-quirk:memory":
				quirks.memory = true
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

	main_loop(rom, quirks)
}

FPS_60_TICKS : i64 : 16666667

main_loop :: proc(rom: []u8, quirks: Quirks) {
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

	vm: Virtual_Machine
	load_rom(&vm, rom)
	vm.quirks = quirks

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
					vm.quirks = quirks
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

		if vm.vblank_interrupt || window_resized {
			draw_video_display(video_display, vm.framebuffer)
		}

		wait(FPS_60_TICKS, frame_start)
	}
}

wait :: proc(target: i64, start: time.Tick) -> i64 {
	elapsed: i64
	for elapsed < target {
		elapsed = time.tick_now()._nsec - start._nsec
	}
	return elapsed
}

usage :: proc() {
	fmt.println("Usage:")
	fmt.println("\tcemu [ROM file] [flags]")
	fmt.println()
	fmt.println("\tFlags")
	fmt.println()
	fmt.println("\tquirk:<quirk>")
	fmt.println("\t\tEnables a quirk in the cpu")
	fmt.println("\t\t\t-quirk:all\tEnables all quirks")
	fmt.println("\t\t\t-quirk:vf_reset\tEnables the VF Reset quirk")
	fmt.println("\t\t\t-quirk:shift\tEnables the shift quirk")
	fmt.println("\t\t\t-quirk:memory\tEnables the memory quirk")
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
