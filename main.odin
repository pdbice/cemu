package main

import "core:fmt"
import "core:mem"

main :: proc() {
	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer check_tracking_allocator(&tracking_allocator)
	}
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
