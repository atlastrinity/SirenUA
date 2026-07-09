import os
import subprocess
import numpy as np
import soundfile as sf

def main():
    sr_target = 44100
    
    # 1. Load the beep prefix from warning.wav (first 1.9 seconds)
    print("⏳ Loading beep prefix from warning.wav...")
    warning_data, sr_warning = sf.read('./Sources/SirenUA/warning.wav')
    if sr_warning != sr_target:
        raise ValueError(f"Expected warning.wav samplerate to be {sr_target}, got {sr_warning}")
        
    prefix_len = int(1.9 * sr_target)
    beep_prefix = warning_data[:prefix_len]
    
    # 2. Use gTTS to synthesize the Ukrainian speech
    print("⏳ Synthesizing speech via gTTS...")
    from gtts import gTTS
    text = "Увага! Відбій загрози!"
    tts = gTTS(text=text, lang='uk')
    
    mp3_path = "temp_speech.mp3"
    wav_path = "temp_speech.wav"
    tts.save(mp3_path)
    
    # 3. Convert MP3 to WAV using ffmpeg at 44100 Hz, mono
    print("⏳ Converting MP3 to WAV via ffmpeg...")
    subprocess.run([
        "ffmpeg", "-y", "-i", mp3_path, 
        "-ar", str(sr_target), "-ac", "1", wav_path
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # 4. Load the converted speech WAV
    speech_data, sr_speech = sf.read(wav_path)
    
    # 5. Concatenate beep prefix, 0.1s silence buffer, and speech
    print("⏳ Concatenating beep prefix and gTTS speech...")
    silence_buffer = np.zeros(int(0.1 * sr_target))
    combined = np.concatenate([beep_prefix, silence_buffer, speech_data])
    
    # Normalize to max absolute amplitude of 0.95
    combined = combined / np.max(np.abs(combined)) * 0.95
    
    # 6. Save final clearance.wav
    output_path = './Sources/SirenUA/clearPermission.wav' # wait, we should overwrite clearance.wav!
    output_path = './Sources/SirenUA/clearance.wav'
    print(f"💾 Saving final audio to {output_path}...")
    sf.write(output_path, combined, sr_target)
    
    # 7. Cleanup temp files
    if os.path.exists(mp3_path):
        os.remove(mp3_path)
    if os.path.exists(wav_path):
        os.remove(wav_path)
        
    print("🎉 Done generating gTTS clearance.wav!")

if __name__ == '__main__':
    main()
