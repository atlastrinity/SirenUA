import numpy as np
import soundfile as sf
import scipy.signal as signal
import subprocess
sr = 44100
duration = 22.0
t = np.arange(int(duration * sr)) / sr
# Parameters for the wail
T_wail = 4.6112  # Period in seconds
f_mean = 570.0   # Average frequency in Hz
f_amp = 180.0    # Frequency sweep amplitude (so sweeps between 390Hz and 750Hz)
# Calculate phase mathematically: Phi(t) = 2*pi * integral of f(t)
# f(t) = f_mean + f_amp * sin(2*pi*t/T_wail - pi/2)  # starts at trough
# Integral of f(t) = f_mean*t - f_amp*(T_wail/(2*pi)) * cos(2*pi*t/T_wail - pi/2)
phi = 2 * np.pi * f_mean * t - f_amp * T_wail * np.cos(2 * np.pi * t / T_wail - np.pi/2)
# Generate waveform with harmonics for rich realistic mechanical sound
x = np.sin(phi) + 0.3 * np.sin(2 * phi) + 0.15 * np.sin(3 * phi) + 0.08 * np.sin(4 * phi)
# Add soft-clipping distortion for mechanical horn growl
x = np.tanh(1.4 * x)
# Amplitude modulation (louder when pitch is high, quieter at trough)
# Volume oscillates between 0.2 and 1.0
am = 0.6 + 0.4 * np.sin(2 * np.pi * t / T_wail - np.pi/2)
x *= am
# Add outdoor stadium echo (feedback delay line)
# Delay is 180ms, feedback factor is 0.35
delay_samples = int(0.180 * sr)
echo_signal = np.zeros_like(x)
for i in range(len(x)):
    if i >= delay_samples:
        echo_signal[i] = x[i] + 0.35 * echo_signal[i - delay_samples]
    else:
        echo_signal[i] = x[i]
# Mix clean signal and echo (75% clean + 25% echo)
siren_raw = 0.75 * x + 0.25 * echo_signal
# Normalize to max 1.0
siren_raw = siren_raw / np.max(np.abs(siren_raw))
print("Siren synthesized successfully. Saving raw synthesis to verify...")
sf.write("/tmp/siren_synth_raw.wav", siren_raw, sr)