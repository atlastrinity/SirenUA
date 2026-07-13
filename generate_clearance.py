import os
import sys
import numpy as np
import soundfile as sf
from pathlib import Path

# Add root directory to import path
project_root = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(project_root))

from edge_tts_wrapper.edge_tts_helper import EdgeTTSHelper

def main():
    sr_target = 44100
    
    # Initialize EdgeTTSHelper
    helper = EdgeTTSHelper(default_voice="uk-UA-OstapNeural", sample_rate=sr_target)
    
    raw_p1_path = "/tmp/c_phrase1.wav"
    raw_p2_path = "/tmp/c_phrase2.wav"
    trimmed_p1_path = "/tmp/c_phrase1_trimmed.wav"
    trimmed_p2_path = "/tmp/c_phrase2_trimmed.wav"
    combined_raw_path = "/tmp/c_combined_raw.wav"
    combined_deep_path = "/tmp/c_combined_deep.wav"
    
    # Step 1: Generate phrases separately via edge-tts
    print("⏳ Generating phrases...")
    helper.synthesize_to_wav("Увага!", raw_p1_path)
    helper.synthesize_to_wav("Відбій загрози!", raw_p2_path)
    
    # Step 2: Trim silence from phrases
    print("⏳ Trimming silence from phrases...")
    helper.trim_silence_file(raw_p1_path, trimmed_p1_path)
    helper.trim_silence_file(raw_p2_path, trimmed_p2_path)
    
    # Step 3: Concatenate phrases with tight 0.1s gaps (no normalization yet)
    print("⏳ Concatenating phrases...")
    helper.concatenate_files(
        [trimmed_p1_path, trimmed_p2_path],
        combined_raw_path,
        gap_seconds=0.1,
        normalize_peak=None
    )
    
    # Step 4: Pitch shifting down to 0.92x (deep resonant voice)
    print("⏳ Pitch shifting voice down to 0.92x...")
    helper.pitch_shift_file(combined_raw_path, combined_deep_path, pitch_factor=0.92)
    
    # Step 5: Load beep prefix (first 1.9s) and wail spin-down (last 1.4s) from warning.wav
    print("⏳ Loading elements from warning.wav...")
    warning_path = Path(__file__).parent / 'Sources/SirenUA/warning.wav'
    warning_data, sr_warning = sf.read(str(warning_path))
    if sr_warning != sr_target:
        raise ValueError(f"Expected warning.wav samplerate to be {sr_target}, got {sr_warning}")
        
    prefix_samples = int(1.9 * sr_target)
    beep_prefix = warning_data[:prefix_samples]
    
    spin_down_start = int(4.5 * sr_target)
    wail_spin_down = warning_data[spin_down_start:]
    
    # Step 6: Load the deep speech audio
    speech_deep, _ = sf.read(combined_deep_path)
    
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
    output_path = Path(__file__).parent / 'Sources/SirenUA/clearance.wav'
    print(f"💾 Saving final clearance.wav to {output_path}...")
    sf.write(str(output_path), final_audio, sr_target)
    
    # Cleanup temp files
    temp_files = [
        raw_p1_path, trimmed_p1_path,
        raw_p2_path, trimmed_p2_path,
        combined_raw_path, combined_deep_path
    ]
    for temp_file in temp_files:
        if os.path.exists(temp_file):
            os.remove(temp_file)
            
    print("🎉 Done! clearance.wav generated successfully!")

if __name__ == '__main__':
    main()

