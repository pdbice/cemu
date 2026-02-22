package main

import "core:fmt"
import "core:mem"
import "core:os"
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
