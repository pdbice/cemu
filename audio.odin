package main

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

AUDIO_BUFFER_SIZE :: 1024
AUDIO_SAMPLE_RATE :: 4400
AUDIO_AMPLITUDE   :: 0.75
AUDIO_FREQUENCY   :: 440
DOUBLE_PI         :: 2.0 * math.PI

Audio :: struct {
	buffer: [AUDIO_BUFFER_SIZE]f32,
	stream: ^sdl.AudioStream,
}

init_audio :: proc(audio: ^Audio) -> bool {
	audio_spec: sdl.AudioSpec = {
		.F32,
		1,
		AUDIO_FREQUENCY,
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
	sdl.PutAudioStreamData(audio.stream, rawptr(&audio.buffer), AUDIO_BUFFER_SIZE)
	sdl.ResumeAudioStreamDevice(audio.stream)
}
