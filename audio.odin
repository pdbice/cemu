package main

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

AUDIO_BUFFER_LENGTH : i32 : 1000
AUDIO_BUFFER_SIZE   : i32 : AUDIO_BUFFER_LENGTH * size_of(f32)
AUDIO_SAMPLE_RATE   : f32 : 44100
AUDIO_AMPLITUDE     : f32 : 0.75
AUDIO_FREQUENCY     : f32 : 441
DOUBLE_PI           : f32 : 2.0 * math.PI

Audio :: struct {
	buffer: [AUDIO_BUFFER_LENGTH]f32,
	stream: ^sdl.AudioStream,
}

init_audio :: proc(audio: ^Audio) -> bool {
	audio_spec: sdl.AudioSpec = {
		.F32,
		1,
		i32(AUDIO_SAMPLE_RATE),
	}
	audio.stream = sdl.OpenAudioDeviceStream(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio_spec, nil, nil)
	if audio.stream == nil {
		fmt.eprintfln("SDL OpenAudioDeviceStream error: %v", sdl.GetError())
		return false
	}

	phase: f32
	for &sample in audio.buffer {
		sample = math.sin_f32(phase) * AUDIO_AMPLITUDE
		phase += DOUBLE_PI * AUDIO_FREQUENCY / AUDIO_SAMPLE_RATE
		if phase > DOUBLE_PI {
			phase -= DOUBLE_PI
		}
	}

	return true
}

play_audio :: proc(audio: ^Audio) {
	if sdl.GetAudioStreamQueued(audio.stream) < AUDIO_BUFFER_SIZE {
		sdl.PutAudioStreamData(audio.stream, &audio.buffer, AUDIO_BUFFER_SIZE)
	}

	if sdl.AudioStreamDevicePaused(audio.stream) {
		sdl.ResumeAudioStreamDevice(audio.stream)
	}
}
