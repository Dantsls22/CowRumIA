"""
buscar_duplicado.py — Cow RumIA
Dado un archivo WAV de referencia, busca duplicados exactos (MD5)
y near-duplicates (recortes del mismo audio) en una carpeta.

Uso:
    python buscar_duplicado.py --archivo "Watusi_7.wav" --carpeta "D:/Audios"
"""

import argparse
import hashlib
import os
import wave

import numpy as np
from scipy import signal
from scipy.spatial.distance import cosine


# ── lectura ──────────────────────────────────────────────────────────────────

def read_wav(path):
    with wave.open(path, 'rb') as w:
        n_ch   = w.getnchannels()
        sampw  = w.getsampwidth()
        rate   = w.getframerate()
        raw    = w.readframes(w.getnframes())
    dtype = np.int16 if sampw == 2 else np.int32
    data  = np.frombuffer(raw, dtype=dtype).astype(np.float32)
    if n_ch == 2:
        data = data.reshape(-1, 2).mean(axis=1)
    data /= 32768.0 if sampw == 2 else 2147483648.0
    return data, rate


def md5(path):
    return hashlib.md5(open(path, 'rb').read()).hexdigest()


# ── huella espectral ──────────────────────────────────────────────────────────

def huella_espectral(data, rate, n_bins=64):
    """
    Vector de n_bins bandas de energía (50–8000 Hz), normalizado a suma=1.
    Sirve para comparar archivos aunque tengan distinto volumen o duración.
    """
    nperseg = min(2048, len(data))
    freqs, psd = signal.welch(data, rate, nperseg=nperseg)
    limites = np.linspace(50, 8000, n_bins + 1)
    huella  = np.zeros(n_bins)
    for i in range(n_bins):
        m = (freqs >= limites[i]) & (freqs < limites[i + 1])
        huella[i] = float(np.trapezoid(psd[m], freqs[m])) if m.any() else 0.0
    total = huella.sum()
    if total > 0:
        huella /= total
    return huella


def similitud(h1, h2):
    """Similitud coseno: 1.0 = idéntico, 0.0 = completamente distinto."""
    if np.all(h1 == 0) or np.all(h2 == 0):
        return 0.0
    return float(1.0 - cosine(h1, h2))


# ── análisis ──────────────────────────────────────────────────────────────────

def analizar(path):
    data, rate = read_wav(path)
    dur  = len(data) / rate
    rms  = float(np.sqrt(np.mean(data ** 2)))
    h    = huella_espectral(data, rate)
    return dur, rms, h


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Busca duplicados de un archivo WAV.')
    parser.add_argument('--archivo',  required=True,
                        help='Nombre del archivo a verificar (solo nombre, no ruta completa)')
    parser.add_argument('--carpeta',  required=True,
                        help='Carpeta donde buscar (busca recursivamente)')
    parser.add_argument('--umbral',   type=float, default=0.985,
                        help='Similitud mínima para considerar near-duplicate (default: 0.985)')
    args = parser.parse_args()

    # Localizar el archivo de referencia dentro de la carpeta
    ref_path = None
    for root, _, files in os.walk(args.carpeta):
        for f in files:
            if f.lower() == args.archivo.lower():
                ref_path = os.path.join(root, f)
                break
        if ref_path:
            break

    if ref_path is None:
        # Intentar ruta directa si el usuario pasó la ruta completa
        if os.path.isfile(args.archivo):
            ref_path = args.archivo
        else:
            print(f"[ERROR] No se encontró '{args.archivo}' dentro de '{args.carpeta}'")
            return

    ref_md5          = md5(ref_path)
    ref_dur, ref_rms, ref_huella = analizar(ref_path)

    print(f"\nArchivo de referencia : {os.path.basename(ref_path)}")
    print(f"  MD5   : {ref_md5}")
    print(f"  Dur   : {ref_dur:.3f} s   RMS: {ref_rms:.4f}")
    print(f"  Ruta  : {ref_path}")
    print(f"\nBuscando en: {args.carpeta}")
    print(f"Umbral near-dup: {args.umbral}\n")
    print("-" * 80)

    exactos    = []
    near_dups  = []
    revisados  = 0

    for root, _, files in os.walk(args.carpeta):
        for f in sorted(files):
            if not f.lower().endswith('.wav'):
                continue
            candidate = os.path.join(root, f)
            if os.path.abspath(candidate) == os.path.abspath(ref_path):
                continue  # saltar el propio archivo de referencia

            revisados += 1

            # 1. MD5 exacto
            c_md5 = md5(candidate)
            if c_md5 == ref_md5:
                exactos.append(candidate)
                print(f"[DUPLICADO EXACTO]  {candidate}")
                continue

            # 2. Near-duplicate por huella espectral
            try:
                c_dur, c_rms, c_huella = analizar(candidate)
            except Exception:
                continue

            sim = similitud(ref_huella, c_huella)
            dur_ratio = min(ref_dur, c_dur) / max(ref_dur, c_dur) if max(ref_dur, c_dur) > 0 else 0

            if sim >= args.umbral:
                near_dups.append((candidate, sim, c_dur, dur_ratio))
                tipo = "RECORTE" if dur_ratio < 0.95 else "NEAR-DUP"
                print(f"[{tipo}]  sim={sim:.4f}  dur={c_dur:.2f}s (ratio={dur_ratio:.2f})  {candidate}")

    print("-" * 80)
    print(f"\nArchivos revisados : {revisados}")
    print(f"Duplicados exactos : {len(exactos)}")
    print(f"Near-duplicates    : {len(near_dups)}")

    if not exactos and not near_dups:
        print("\nSin coincidencias — el archivo parece único en la carpeta.")
    else:
        print("\nRECOMENDACION:")
        if exactos:
            print(f"  Eliminar los {len(exactos)} duplicados exactos — son copias byte a byte.")
        if near_dups:
            print(f"  Revisar los {len(near_dups)} near-duplicates manualmente.")
            print("  Si son recortes del mismo audio, conservar solo el de mejor duración.")


if __name__ == '__main__':
    main()