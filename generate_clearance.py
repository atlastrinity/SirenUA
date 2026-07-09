import os
import io
import numpy as np
import soundfile as sf
import scipy.signal as signal
from ukrainian_tts.tts import TTS, Voices, Stress

def main():
    sr_target = 44100
    
    # 1. Load the beep prefix from warning.wav (first 1.9 seconds)
    print("⏳ Loading beep prefix from warning.wav...")
    warning_data, sr_warning = sf.read('./Sources/SirenUA/warning.wav')
    if sr_warning != sr_target:
        raise ValueError(f"Expected warning.wav samplerate to be {sr_target}, got {sr_warning}")
    
    # 1.9 seconds of prefix
    prefix_len = int(1.9 * sr_target)
    beep_prefix = warning_data[:prefix_len]
    
    # 2. Initialize TTS engine and synthesize the speech
    print("⏳ Initializing TTS engine...")
    tts = TTS(device='cpu')
    
    text = "Увага! Ві/дбій загрози!"  # Using slash for correct accent stress if needed, or normal dictionary stress
    print(f"🎙️ Synthesizing speech: '{text}' using Dmytro's voice...")
    
    wav_data = io.BytesIO()
    tts.tts(text, Voices.Dmytro.value, Stress.Dictionary.value, wav_data)
    wav_data.seek(0)
    
    speech_data, sr_speech = sf.read(wav_data)
    print(f"✅ Synthesized successfully. SR: {sr_speech}, Shape: {speech_data.shape}")
    
    # 3. Resample speech from 22050 Hz to 44100 Hz
    if sr_speech == 22050:
        print("⏳ Resampling speech from 22050 Hz to 44100 Hz using resample_poly...")
        speech_resampled = signal.resample_poly(speech_data, 2, 1)
    elif sr_speech == sr_target:
        speech_resampled = speech_data
    else:
        print(f"⏳ Resampling speech from {sr_speech} Hz to {sr_target} Hz...")
        num_samples = int(len(speech_data) * sr_target / sr_speech)
        speech_resampled = signal.resample(speech_data, num_samples)
        
    # 4. Concatenate prefix and resampled speech
    print("⏳ Concatenating beep prefix and speech...")
    # Add a tiny silence buffer (0.1s) between beep and speech
    silence_buffer = np.zeros(int(0.1 * sr_target))
    combined = np.concatenate([beep_prefix, silence_buffer, speech_resampled])
    
    # Normalize to max absolute amplitude of 0.95 to match warning.wav
    combined = combined / np.max(np.abs(combined)) * 0.95
    
    # 5. Save the output wav file
    output_path = './Sources/SirenUA/clearance.wav'
    print(f"💾 Saving final audio to {output_path}...")
    sf.write(output_path, combined, sr_target)
    print("🎉 Done!")

if __name__ == '__main__':
    main()
