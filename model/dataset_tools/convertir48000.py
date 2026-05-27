import wave, os, struct

import numpy as np
from scipy.signal import resample_poly
from math import gcd

carpeta = r"D:\Recursos Tesina\AUDIO2"
SR_OBJETIVO = 48000

def resamplear_wav(path_in, sr_orig):
    # Leer
    with wave.open(path_in, 'rb') as wf:
        n_ch = wf.getnchannels()
        sw = wf.getsampwidth()
        n_frames = wf.getnframes()
        raw = wf.readframes(n_frames)

    # Decodificar
    samples = np.frombuffer(raw, dtype='<i2').astype(np.float32) / 32768.0
    if n_ch > 1:
        samples = samples.reshape(-1, n_ch).mean(axis=1)

    # Resamplear
    g = gcd(SR_OBJETIVO, sr_orig)
    up, down = SR_OBJETIVO // g, sr_orig // g
    resampled = resample_poly(samples, up, down)

    # Recodificar a 16-bit
    out = np.clip(resampled, -1.0, 1.0)
    out_int = (out * 32767).astype(np.int16)

    # Sobreescribir el archivo original
    with wave.open(path_in, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR_OBJETIVO)
        wf.writeframes(out_int.tobytes())

    print(f"✓ {sr_orig} Hz → {SR_OBJETIVO} Hz: {os.path.basename(path_in)}")

# Buscar y convertir
convertidos = 0
for root, _, files in os.walk(carpeta):
    for f in sorted(files):
        if f.lower().endswith('.wav'):
            path = os.path.join(root, f)
            with wave.open(path, 'rb') as wf:
                sr = wf.getframerate()
            if sr != SR_OBJETIVO:
                resamplear_wav(path, sr)
                convertidos += 1

print(f"\n{'✓ Todo en 48000 Hz.' if convertidos == 0 else f'{convertidos} archivos convertidos a 48000 Hz.'}")