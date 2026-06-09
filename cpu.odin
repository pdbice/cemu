package main

import "core:math/rand"
import "core:slice"

Variant :: enum {
	Superchip_Modern,
	Superchip_Legacy,
	Cosmic,
}

Display :: struct {
	framebuffer:  [8192]u8,
	length:       int,
	width:        int,
	height:       int,
	scroll_width: int,
}

Keypad :: struct {
	state:        [16]bool,
	wait_key:     u8,
	key_released: bool,
}

Quirks :: struct {
	vf_reset: bool,
	shift:    bool,
	memory:   bool,
}

Virtual_Machine :: struct {
	display:          Display,
	ram:              [4096]u8,
	framebuffer:      [2048]u8,
	stack:            [12]u16,
	keypad:           Keypad,
	v_registers:      [16]u8,
	variant:          Variant,
	quirks:           Quirks,
	program_counter:  u16,
	index_register:   u16,
	stack_pointer:    u8,
	delay_timer:      u8,
	sound_timer:      u8,
	vblank_interrupt: bool,
}

load_rom :: proc(vm: ^Virtual_Machine, rom: []u8) {
	font: [180]u8 = {
		0xF0, 0x90, 0x90, 0x90, 0xF0, 0x20, 0x60, 0x20, 0x20, 0x70,
		0xF0, 0x10, 0xF0, 0x80, 0xF0, 0xF0, 0x10, 0xF0, 0x10, 0xF0,
		0x90, 0x90, 0xF0, 0x10, 0x10, 0xF0, 0x80, 0xF0, 0x10, 0xF0,
		0xF0, 0x80, 0xF0, 0x90, 0xF0, 0xF0, 0x10, 0x20, 0x40, 0x40,
		0xF0, 0x90, 0xF0, 0x90, 0xF0, 0xF0, 0x90, 0xF0, 0x10, 0xF0,
		0xF0, 0x90, 0xF0, 0x90, 0x90, 0xE0, 0x90, 0xE0, 0x90, 0xE0,
		0xF0, 0x80, 0x80, 0x80, 0xF0, 0xE0, 0x90, 0x90, 0x90, 0xE0,
		0xF0, 0x80, 0xF0, 0x80, 0xF0, 0xF0, 0x80, 0xF0, 0x80, 0x80,
		0x3C, 0x7E, 0xE7, 0xC3, 0xC3, 0xC3, 0xC3, 0xE7, 0x7E, 0x3C,
		0x18, 0x38, 0x58, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C,
		0x3E, 0x7F, 0xC3, 0x06, 0x0C, 0x18, 0x30, 0x60, 0xFF, 0xFF,
		0x3C, 0x7E, 0xC3, 0x03, 0x0E, 0x0E, 0x03, 0xC3, 0x7E, 0x3C,
		0x06, 0x0E, 0x1E, 0x36, 0x66, 0xC6, 0xFF, 0xFF, 0x06, 0x06,
		0xFF, 0xFF, 0xC0, 0xC0, 0xFC, 0xFE, 0x03, 0xC3, 0x7E, 0x3C,
		0x3E, 0x7C, 0xE0, 0xC0, 0xFC, 0xFE, 0xC3, 0xC3, 0x7E, 0x3C,
		0xFF, 0xFF, 0x03, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x60, 0x60,
		0x3C, 0x7E, 0xC3, 0xC3, 0x7E, 0x7E, 0xC3, 0xC3, 0x7E, 0x3C,
		0x3C, 0x7E, 0xC3, 0xC3, 0x7F, 0x3F, 0x03, 0x03, 0x3E, 0x7C,
	}

	copy(vm.ram[:], font[:])
	copy(vm.ram[512:], rom[:])

	vm.display.length = 2048
	vm.display.width = 64
	vm.display.height = 32
	if vm.variant == .Superchip_Legacy {
		vm.display.scroll_width = 2
	} else {
		vm.display.scroll_width = 4
	}

	vm.program_counter = 512
}

fetch_and_execute :: proc(vm: ^Virtual_Machine) {
	opcode_high := vm.ram[vm.program_counter]
	opcode_low := vm.ram[vm.program_counter + 1]

	vm.program_counter += 2

	x_operand := opcode_high & 0xF
	y_operand := opcode_low & 0xF0 >> 4
	n_operand := opcode_low & 0xF
	address_operand := u16(opcode_high & 0xF) << 8 | u16(opcode_low)

	math_flag: u8

	switch opcode_high & 0xF0 {
	case 0x00:
		if opcode_high != 0x00 {
			return
		}
		switch opcode_low {
		case 0xE0:
			vm.framebuffer = 0
		case 0xEE:
			vm.stack_pointer -= 1
			vm.program_counter = vm.stack[vm.stack_pointer]
			vm.stack[vm.stack_pointer] = 0
		case 0xFB:
			scroll_right(&vm.display)
		case 0xFC:
			scroll_left(&vm.display)
		case 0xFD:
			vm.program_counter -= 2
		case 0xFE:
			vm.display.length = 2048
			vm.display.width = 64
			vm.display.height = 32
			#partial switch vm.variant {
			case .Superchip_Modern:
				vm.display.framebuffer = 0
			case .Superchip_Legacy:
				vm.display.scroll_width = 2
			}
		case 0xFF:
			vm.display.length = 8192
			vm.display.width = 128
			vm.display.height = 64
			vm.display.scroll_width = 4
			if vm.variant == .Superchip_Modern {
				vm.display.framebuffer = 0
			}
		case:
			if y_operand == 0xC {
				if vm.variant == .Superchip_Legacy && vm.display.length == 2048 {
					scroll_down(&vm.display, n_operand / 2)
				} else {
					scroll_down(&vm.display, n_operand)
				}
			}
		}
	case 0x10:
		vm.program_counter = address_operand
	case 0x20:
		vm.stack[vm.stack_pointer] = vm.program_counter
		vm.stack_pointer += 1
		vm.program_counter = address_operand
	case 0x30:
		if vm.v_registers[x_operand] == opcode_low {
			vm.program_counter += 2
		}
	case 0x40:
		if vm.v_registers[x_operand] != opcode_low {
			vm.program_counter += 2
		}
	case 0x50:
		if vm.v_registers[x_operand] == vm.v_registers[y_operand] {
			vm.program_counter += 2
		}
	case 0x60:
		vm.v_registers[x_operand] = opcode_low
	case 0x70:
		vm.v_registers[x_operand] += opcode_low
	case 0x80:
		switch n_operand {
		case 0x0:
			vm.v_registers[x_operand] = vm.v_registers[y_operand]
		case 0x1:
			vm.v_registers[x_operand] |= vm.v_registers[y_operand]
			if !vm.quirks.vf_reset {
				vm.v_registers[15] = 0
			}
		case 0x2:
			vm.v_registers[x_operand] &= vm.v_registers[y_operand]
			if !vm.quirks.vf_reset {
				vm.v_registers[15] = 0
			}
		case 0x3:
			vm.v_registers[x_operand] ~= vm.v_registers[y_operand]
			if !vm.quirks.vf_reset {
				vm.v_registers[15] = 0
			}
		case 0x4:
			vm.v_registers[x_operand] += vm.v_registers[y_operand]
			if vm.v_registers[x_operand] < vm.v_registers[y_operand] {
				vm.v_registers[15] = 1
			} else {
				vm.v_registers[15] = 0
			}
		case 0x5:
			math_flag = 1
			if vm.v_registers[y_operand] > vm.v_registers[x_operand] {
				math_flag = 0
			}
			vm.v_registers[x_operand] -= vm.v_registers[y_operand]
			vm.v_registers[15] = math_flag
		case 0x6:
			if vm.quirks.shift {
				math_flag = vm.v_registers[x_operand] & 1
				vm.v_registers[x_operand] >>= 1
			} else {
				math_flag = vm.v_registers[y_operand] & 1
				vm.v_registers[x_operand] = vm.v_registers[y_operand] >> 1
			}
			vm.v_registers[15] = math_flag
		case 0x7:
			math_flag = 1
			if vm.v_registers[x_operand] > vm.v_registers[y_operand] {
				math_flag = 0
			}
			vm.v_registers[x_operand] = vm.v_registers[y_operand] - vm.v_registers[x_operand]
			vm.v_registers[15] = math_flag
		case 0xE:
			if vm.quirks.shift {
				math_flag = vm.v_registers[x_operand] >> 7
				vm.v_registers[x_operand] <<= 1
			} else {
				math_flag = vm.v_registers[y_operand] >> 7
				vm.v_registers[x_operand] = vm.v_registers[y_operand] << 1
			}
			vm.v_registers[15] = math_flag
		}
	case 0x90:
		if vm.v_registers[x_operand] != vm.v_registers[y_operand] {
			vm.program_counter += 2
		}
	case 0xA0:
		vm.index_register = address_operand
	case 0xB0:
		vm.program_counter = u16(vm.v_registers[0]) + address_operand
	case 0xC0:
		vm.v_registers[x_operand] = u8(rand.uint32() % 256) & opcode_low
	case 0xD0:
		if vm.vblank_interrupt {
			vm.program_counter -= 2
			return
		}
		vm.v_registers[15] = 0
		x_start := int(vm.v_registers[x_operand]) & 63
		pixel_y := int(vm.v_registers[y_operand]) & 31
		for sprite_index in vm.index_register..<vm.index_register + u16(n_operand) {
			sprite_row := vm.ram[sprite_index]
			shift_length: u8 = 7
			framebuffer_index := pixel_y * 64 + x_start
			for pixel_x in x_start..<x_start + 8 {
				if pixel_x > 63 {
					break
				}
				sprite_bit := (sprite_row >> shift_length) & 1
				vm.v_registers[15] |= vm.framebuffer[framebuffer_index] & sprite_bit
				vm.framebuffer[framebuffer_index] ~= sprite_bit
				framebuffer_index += 1
				shift_length -= 1
			}
			pixel_y += 1
			if pixel_y > 31 {
				break
			}
		}
		vm.vblank_interrupt = true
	case 0xE0:
		switch opcode_low {
		case 0x9E:
			if vm.keypad.state[vm.v_registers[x_operand] & 0xF] {
				vm.program_counter += 2
			}
		case 0xA1:
			if !vm.keypad.state[vm.v_registers[x_operand] & 0xF] {
				vm.program_counter += 2
			}
		}
	case 0xF0:
		switch opcode_low {
		case 0x07:
			vm.v_registers[x_operand] = vm.delay_timer
		case 0x0A:
			if vm.keypad.key_released {
				vm.v_registers[x_operand] = vm.keypad.wait_key
				vm.keypad.key_released = false
				return
			}
			vm.program_counter -= 2
		case 0x15:
			vm.delay_timer = vm.v_registers[x_operand]
		case 0x18:
			vm.sound_timer = vm.v_registers[x_operand]
		case 0x1E:
			vm.index_register += u16(vm.v_registers[x_operand])
		case 0x29:
			vm.index_register = u16(vm.v_registers[x_operand] & 0xF) * 5
		case 0x33:
			bcd_value := vm.v_registers[x_operand]
			vm.ram[vm.index_register + 2] = bcd_value % 10
			bcd_value /= 10
			vm.ram[vm.index_register + 1] = bcd_value % 10
			bcd_value /= 10
			vm.ram[vm.index_register] = bcd_value
		case 0x55:
			copy(vm.ram[vm.index_register:], vm.v_registers[:x_operand + 1])
			if !vm.quirks.memory {
				vm.index_register += u16(x_operand) + 1
			}
		case 0x65:
			copy(vm.v_registers[:], vm.ram[vm.index_register:][:x_operand + 1])
			if !vm.quirks.memory {
				vm.index_register += u16(x_operand) + 1
			}
		}
	}
}

scroll_right :: proc(display: ^Display) {
	scroll_length := display.width - display.scroll_width
	for row_start := 0; row_start < display.length; row_start += display.width {
		copy(
			display.framebuffer[row_start + display.scroll_width:],
			display.framebuffer[row_start:][:scroll_length]
		)
		slice.zero(display.framebuffer[row_start:][:display.scroll_width])
	}
}

scroll_left :: proc(display: ^Display) {
	scroll_length := display.width - display.scroll_width
	for row_start := 0; row_start < display.length; row_start += display.width {
		copy(
			display.framebuffer[row_start:],
			display.framebuffer[row_start + display.scroll_width:][:scroll_length]
		)
		slice.zero(display.framebuffer[row_start + scroll_length:][:display.scroll_width])
	}
}

scroll_down :: proc(display: ^Display, rows: u8) {
	scroll_height := int(rows) * display.width
	scroll_length := display.length - scroll_height
	copy(display.framebuffer[scroll_height:], display.framebuffer[:scroll_length])
	slice.zero(display.framebuffer[:scroll_height])
}
