package main

Keypad :: struct {
	state:        [16]bool,
	wait_key:     u8,
	key_released: bool,
}

Virtual_Machine :: struct {
	ram:              [4096]u8,
	framebuffer:      [2048]u8,
	stack:            [12]u16,
	keypad:           Keypad,
	v_registers:      [16]u8,
	program_counter:  u16,
	index_register:   u16,
	stack_pointer:    u8,
	delay_timer:      u8,
	sound_timer:      u8,
	vblank_interrupt: bool,
}
