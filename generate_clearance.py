import os
import subprocess
import soundfile as sf
import numpy as np

def generate_phrase(text, filename):
    print(f"⏳ Generating phrase: '{text}'...")
    subprocess.run([
        "edge-tts",
        "--voice", "uk-UA-OstapNeural",
        "--text", text,
        "--write-media", f"/tmp/{filename}.mp3"
    ], check=True)
    
    subprocess.run([
        "ffmpeg", "-y",
        "-i", f"/tmp/{filename}.mp3",
        "-ac", "1",
        "-ar", "44100",
        f"/tmp/{filename}.wav"
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def trim_silence(filepath, threshold=0.005):
    data, sr = sf.read(filepath)
    # Find indices where amplitude is above threshold
    above_threshold = np.where(np.abs(data) > threshold)[0]
    if len(above_threshold) > 0:
        start_idx = max(0, above_threshold[0] - int(sr * 0.05)) # keep 50ms padding
        end_idx = min(len(data), above_threshold[-1] + int(sr * 0.05)) # keep 50ms padding
        return data[start_idx:end_idx], sr
    return data, sr

def main():
    sr_target = 44100
    
    # Step 1: Generate phrases separately via edge-tts
    generate_phrase("Увага!", "c_phrase1")
    generate_phrase("Відбій загрози!", "c_phrase2")
    
    # Step 2: Trim silence from phrases
    print("⏳ Trimming silence from phrases...")
    p1, sr = trim_silence("/tmp/c_phrase1.wav")
    p2, _ = trim_silence("/tmp/c_phrase2.wav")
    
    # Create 0.1s silence gap
    gap_0_1 = np.zeros(int(sr_target * 0.1))
    
    # Step 3: Concatenate phrases with tight 0.1s gaps
    print("⏳ Concatenating phrases...")
    combined_speech = np.concatenate([p1, gap_0_1, p2])
    sf.write("/tmp/c_combined_raw.wav", combined_speech, sr_target)
    
    # Step 4: Pitch shifting down to 0.92x using ffmpeg rubberband
    print("⏳ Pitch shifting voice down to 0.92x (deep resonant voice)...")
    subprocess.run([
        "ffmpeg", "-y",
        "-i", "/tmp/c_combined_raw.wav",
        "-af", "rubberband=pitch=0.92",
        "-ac", "1",
        "-ar", str(sr_target),
        "/tmp/c_combined_deep.wav"
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Step 5: Load beep prefix (first 1.9s) and wail spin-down (last 1.4s) from warning.wav
    print("⏳ Loading elements from warning.wav...")
    warning_data, sr_warning = sf.read('./Sources/SirenUA/warning.wav')
    if sr_warning != sr_target:
        raise ValueError(f"Expected warning.wav samplerate to be {sr_target}, got {sr_warning}")
        
    prefix_samples = int(1.9 * sr_target)
    beep_prefix = warning_data[:prefix_samples]
    
    spin_down_start = int(4.5 * sr_target)
    wail_spin_down = warning_data[spin_down_start:]
    
    # Step 6: Load the deep speech audio
    speech_deep, _ = sf.read("/tmp/c_combined_deep.wav")
    
    # Step 7: Concatenate all parts: prefix, 0.4s pause, speech, 0.4s pause, spin-down
    print("⏳ Assembling final clearance.wav track...")
    pause_0_4 = np.zeros(int(sr_target * 0.4))
    
    final_audio = np.concatenate([
        beep_prefix,
        pause_0_4,
        speech_deep,
        pause_0_4,
        wail_spin_down
    ])
    
    # Normalize final audio to 0.95 peak
    final_audio = final_audio / np.max(np.abs(final_audio)) * 0.95
    
    # Step 8: Save final clearance.wav
    output_path = './Sources/SirenUA/clearance.wav'
    print(f"💾 Saving final clearance.wav to {output_path}...")
    sf.write(output_path, final_audio, sr_target)
    
    # Cleanup temp files
    temp_files = [
        "/tmp/c_phrase1.mp3", "/tmp/c_phrase1.wav",
        "/tmp/c_phrase2.mp3", "/tmp/c_phrase2.wav",
        "/tmp/c_combined_raw.wav", "/tmp/c_combined_deep.wav"
    ]
    for temp_file in temp_files:
        if os.path.exists(temp_file):
            os.remove(temp_file)
            
    print("🎉 Done! clearance.wav generated successfully!")

if __name__ == '__main__':
    main()
