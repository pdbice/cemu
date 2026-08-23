package main

import sdl "vendor:sdl3"

KEYPAD_0 :: sdl.Scancode.X
KEYPAD_1 :: sdl.Scancode._1
KEYPAD_2 :: sdl.Scancode._2
KEYPAD_3 :: sdl.Scancode._3
KEYPAD_4 :: sdl.Scancode.Q
KEYPAD_5 :: sdl.Scancode.W
KEYPAD_6 :: sdl.Scancode.E
KEYPAD_7 :: sdl.Scancode.A
KEYPAD_8 :: sdl.Scancode.S
KEYPAD_9 :: sdl.Scancode.D
KEYPAD_A :: sdl.Scancode.Z
KEYPAD_B :: sdl.Scancode.C
KEYPAD_C :: sdl.Scancode._4
KEYPAD_D :: sdl.Scancode.R
KEYPAD_E :: sdl.Scancode.F
KEYPAD_F :: sdl.Scancode.V

update_keypad :: proc(keypad: ^Keypad) {
	key_state := sdl.GetKeyboardState(nil)
	
	keypad.key_released = false

	if keypad.state[0] && !key_state[KEYPAD_0] {
		keypad.wait_key = 0
		keypad.key_released = true
	}

	if keypad.state[1] && !key_state[KEYPAD_1] {
		keypad.wait_key = 1
		keypad.key_released = true
	}
	if keypad.state[2] && !key_state[KEYPAD_2] {
		keypad.wait_key = 2
		keypad.key_released = true
	}

	if keypad.state[3] && !key_state[KEYPAD_3] {
		keypad.wait_key = 3
		keypad.key_released = true
	}

	if keypad.state[4] && !key_state[KEYPAD_4] {
		keypad.wait_key = 4
		keypad.key_released = true
	}

	if keypad.state[5] && !key_state[KEYPAD_5] {
		keypad.wait_key = 5
		keypad.key_released = true
	}

	if keypad.state[6] && !key_state[KEYPAD_6] {
		keypad.wait_key = 6
		keypad.key_released = true
	}

	if keypad.state[7] && !key_state[KEYPAD_7] {
		keypad.wait_key = 7
		keypad.key_released = true
	}

	if keypad.state[8] && !key_state[KEYPAD_8] {
		keypad.wait_key = 8
		keypad.key_released = true
	}

	if keypad.state[9] && !key_state[KEYPAD_9] {
		keypad.wait_key = 9
		keypad.key_released = true
	}
	if keypad.state[10] && !key_state[KEYPAD_A] {
		keypad.wait_key = 10
		keypad.key_released = true
	}

	if keypad.state[11] && !key_state[KEYPAD_B] {
		keypad.wait_key = 11
		keypad.key_released = true
	}

	if keypad.state[12] && !key_state[KEYPAD_C] {
		keypad.wait_key = 12
		keypad.key_released = true
	}

	if keypad.state[13] && !key_state[KEYPAD_D] {
		keypad.wait_key = 13
		keypad.key_released = true
	}

	if keypad.state[14] && !key_state[KEYPAD_E] {
		keypad.wait_key = 14
		keypad.key_released = true
	}

	if keypad.state[15] && !key_state[KEYPAD_F] {
		keypad.wait_key = 15
		keypad.key_released = true
	}

	keypad.state[ 0] = key_state[KEYPAD_0]
	keypad.state[ 1] = key_state[KEYPAD_1]
	keypad.state[ 2] = key_state[KEYPAD_2]
	keypad.state[ 3] = key_state[KEYPAD_3]
	keypad.state[ 4] = key_state[KEYPAD_4]
	keypad.state[ 5] = key_state[KEYPAD_5]
	keypad.state[ 6] = key_state[KEYPAD_6]
	keypad.state[ 7] = key_state[KEYPAD_7]
	keypad.state[ 8] = key_state[KEYPAD_8]
	keypad.state[ 9] = key_state[KEYPAD_9]
	keypad.state[10] = key_state[KEYPAD_A]
	keypad.state[11] = key_state[KEYPAD_B]
	keypad.state[12] = key_state[KEYPAD_C]
	keypad.state[13] = key_state[KEYPAD_D]
	keypad.state[14] = key_state[KEYPAD_E]
	keypad.state[15] = key_state[KEYPAD_F]
}
