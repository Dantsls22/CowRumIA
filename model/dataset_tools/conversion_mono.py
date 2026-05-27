import wave, os, subprocess
import numpy as np

carpeta = r"D:\Recursos Tesina\rancho"
carpeta_originales = r"D:\Recursos Tesina\rancho\_estereo_originales"

# Ruta al ffmpeg de Shutter Encoder — ajusta si es diferente
FFMPEG = r"D:\Shutter encoder\Shutter Encoder\Library\ffmpeg.exe"

FORMATOS_CONVERTIR = ('.mp3', '.m4a', '.aac', '.ogg', '.flac', '.mp4', '.aiff')

convertidos_fmt = 0
convertidos_mono = 0
ya_ok = 0

for root, _, files in os.walk(carpeta):
    if carpeta_originales in root:
        continue

    for f in sorted(files):
        path = os.path.join(root, f)
        ext = os.path.splitext(f)[1].lower()

        # --- PASO 1: convertir a WAV si no lo es ---
        if ext in FORMATOS_CONVERTIR:
            wav_path = os.path.splitext(path)[0] + '.wav'

            # Mover original a respaldo
            os.makedirs(carpeta_originales, exist_ok=True)
            respaldo = os.path.join(carpeta_originales, f)
            os.rename(path, respaldo)

            # Convertir con ffmpeg: mono, 48000 Hz, 16-bit PCM
            subprocess.run([
                FFMPEG, '-y', '-i', respaldo,
                '-ac', '1',
                '-ar', '48000',
                '-sample_fmt', 's16',
                wav_path
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            print(f"✓ {ext} → WAV: {f}")
            convertidos_fmt += 1
            continue  # ya es mono y 48k, pasar al siguiente

        # --- PASO 2: solo procesar WAV ---
        if ext != '.wav':
            continue

        with wave.open(path, 'rb') as wf:
            n_ch = wf.getnchannels()
            sr = wf.getframerate()
            sw = wf.getsampwidth()
            n_frames = wf.getnframes()
            raw = wf.readframes(n_frames)

        if n_ch == 1:
            ya_ok += 1
            continue

        # --- PASO 3: convertir estéreo a mono ---
        os.makedirs(carpeta_originales, exist_ok=True)
        respaldo = os.path.join(carpeta_originales, f)
        os.rename(path, respaldo)

        dtype = {1: '<i1', 2: '<i2', 4: '<i4'}[sw]
        samples = np.frombuffer(raw, dtype=dtype).astype(np.float32)
        samples /= (2 ** (8 * sw - 1))
        samples = samples.reshape(-1, n_ch).mean(axis=1)

        out_int = np.clip(samples, -1.0, 1.0)
        out_int = (out_int * (2 ** (8 * sw - 1) - 1)).astype(
            {1: np.int8, 2: np.int16, 4: np.int32}[sw]
        )

        with wave.open(path, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(sw)
            wf.setframerate(sr)
            wf.writeframes(out_int.tobytes())

        print(f"✓ Estéreo → mono: {f}")
        convertidos_mono += 1

print(f"\nFormatos convertidos a WAV: {convertidos_fmt}")
print(f"Estéreo convertidos a mono: {convertidos_mono}")
print(f"Ya correctos: {ya_ok}")
if convertidos_fmt or convertidos_mono:
    print(f"Originales guardados en: {carpeta_originales}")