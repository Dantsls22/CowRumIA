"""
COW RUMIA — Validador de Dataset
==================================
Script unificado con dos modos de ejecucion:

  MODO 1 — Generar perfiles de referencia:
    python cow_rumia_validator.py --modo perfil

    Lee los audios de referencia que validaste manualmente,
    calcula los estadisticos de cada clase y guarda el perfil
    en cow_rumia_perfiles.json

  MODO 2 — Escanear el dataset completo:
    python cow_rumia_validator.py --modo escanear

    Lee el perfil generado en el modo 1 y analiza cada audio
    del dataset buscando anomalias reales que puedan afectar
    el entrenamiento de la red neuronal.

Flags que detecta el escaner:
  DUPLICADO       — MD5 identico a otro archivo (mismo o distinta carpeta)
  SATURADO        — RMS > -3 dB, audio distorsionado irrecuperable
  SILENCIO        — Bovino total < 50%, no hay vocalización dominante
  RECORTAR        — Duracion > 4.5 segundos
  NORMALIZAR      — RMS < -38 dB, muy silencioso
  ANOMALIA_AVE    — Contaminacion de aves fuera del rango de referencia
  ANOMALIA_CTR    — Centroide completamente fuera del rango de su clase
  ANOMALIA_QUE    — Queja% muy por encima del maximo de referencia
  CLASE_DUDOSA    — Perfil espectral mas cercano a otra clase que a la suya
  OK              — Sin problemas detectados
"""

import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import os
import csv
import json
import hashlib
import argparse
import numpy as np
import librosa
from pathlib import Path
from collections import defaultdict
from scipy import signal as scipy_signal

# ══════════════════════════════════════════════════════════════
# CONFIGURACION
# ══════════════════════════════════════════════════════════════
BASE_DIR      = r"D:\Recursos Tesina\AUDIO2"
DIR_REFERENCIA = r"D:\Recursos Tesina\Referencia"
ARCHIVO_PERFIL = "cow_rumia_perfiles.json"

# Carpetas del dataset a escanear (relativas a BASE_DIR)
CARPETAS_DATASET = {
    "estres_engorda":    ["engorda_estres"],
    "no_estres_engorda": ["engorda_no_estres"],
    "estres_leche":      [os.path.join("leche_estres", "Becerra_estres"),
                          os.path.join("leche_estres", "leche_estres")],
    "no_estres_leche":   ["leche_no_estres"],
}

# Carpetas a ignorar completamente
CARPETAS_IGNORAR = [
    "Referencia", "Biblioteca Berlin", "berlin_originales",
    "Imgs", "rancho", "scripts python", "Clasificar", "Clasificados",
]

SR         = 22050
DURATION   = 3.0
N_FFT      = 1024
HOP_LENGTH = 512

# Margenes para deteccion de anomalias (en desviaciones estandar)
# Un valor de 3.0 significa: solo flagear si esta a mas de 3 desviaciones
# del promedio de referencia — muy conservador para evitar falsos positivos
MARGEN_ANOMALIA = 3.0


# ══════════════════════════════════════════════════════════════
# UTILIDADES COMUNES
# ══════════════════════════════════════════════════════════════
def debe_ignorar(ruta):
    partes = [p.lower() for p in Path(ruta).parts]
    return any(ign.lower() in partes for ign in CARPETAS_IGNORAR)


def calcular_md5(ruta):
    h = hashlib.md5()
    try:
        with open(ruta, 'rb') as f:
            for bloque in iter(lambda: f.read(8192), b''):
                h.update(bloque)
        return h.hexdigest()
    except:
        return None


def cargar_audio(ruta):
    try:
        y, _ = librosa.load(ruta, sr=SR, mono=True, duration=DURATION)
        dur_real, _ = librosa.load(ruta, sr=SR, mono=True)
        dur_s = len(dur_real) / SR
        n = int(SR * DURATION)
        y = np.pad(y, (0, max(0, n - len(y))))[:n]
        return y.astype(np.float32), round(dur_s, 3)
    except Exception as e:
        return None, 0.0


def analizar_audio(y, dur_real):
    """
    Calcula todas las metricas espectrales relevantes de un audio.
    """
    rms    = float(np.sqrt(np.mean(y**2)))
    rms_db = float(20 * np.log10(rms + 1e-8))

    freqs_w, psd = scipy_signal.welch(y, fs=SR, nperseg=N_FFT, noverlap=HOP_LENGTH)
    energia_total = np.sum(psd) + 1e-8

    def banda(fmin, fmax):
        m = (freqs_w >= fmin) & (freqs_w <= fmax)
        return float(np.sum(psd[m]) / energia_total * 100)

    moo_pct   = banda(50, 800)
    queja_pct = banda(800, 2500)
    aves_pct  = banda(2500, 8000)
    bov_total = moo_pct + queja_pct
    bov_ext   = moo_pct + queja_pct + aves_pct

    mag   = np.abs(librosa.stft(y, n_fft=N_FFT, hop_length=HOP_LENGTH))
    freqs_s = librosa.fft_frequencies(sr=SR, n_fft=N_FFT)
    cent  = librosa.feature.spectral_centroid(S=mag, sr=SR, freq=freqs_s)
    ctr_hz = float(np.mean(cent))

    idx_pico = np.argmax(psd)
    pico_hz  = float(freqs_w[idx_pico])

    return {
        'dur_s':     round(dur_real, 3),
        'rms':       round(rms, 4),
        'rms_db':    round(rms_db, 1),
        'moo_pct':   round(moo_pct, 1),
        'queja_pct': round(queja_pct, 1),
        'aves_pct':  round(aves_pct, 1),
        'bov_total': round(bov_total, 1),
        'bov_ext':   round(bov_ext, 1),
        'ctr_hz':    round(ctr_hz, 0),
        'pico_hz':   round(pico_hz, 0),
    }


# ══════════════════════════════════════════════════════════════
# MODO 1 — GENERAR PERFILES DE REFERENCIA
# ══════════════════════════════════════════════════════════════
def generar_perfiles():
    print("\n" + "="*60)
    print("  COW RUMIA — Generando perfiles de referencia")
    print("="*60)

    if not os.path.exists(DIR_REFERENCIA):
        print(f"\n  ! No se encontro la carpeta de referencia:")
        print(f"    {DIR_REFERENCIA}")
        return

    clases_ref = [d for d in os.listdir(DIR_REFERENCIA)
                  if os.path.isdir(os.path.join(DIR_REFERENCIA, d))]
    print(f"\n  Clases encontradas: {clases_ref}")

    perfiles = {}

    for clase in clases_ref:
        carpeta = os.path.join(DIR_REFERENCIA, clase)
        archivos = list(Path(carpeta).glob("*.wav"))

        if len(archivos) == 0:
            print(f"\n  ! {clase}: carpeta vacia, saltando")
            continue

        print(f"\n  Analizando {clase} ({len(archivos)} audios de referencia)...")
        metricas_clase = []

        for archivo in archivos:
            audio, dur_real = cargar_audio(str(archivo))
            if audio is None:
                continue
            m = analizar_audio(audio, dur_real)
            metricas_clase.append(m)
            print(f"    {archivo.name:<40} "
                  f"Moo:{m['moo_pct']:5.1f}%  "
                  f"Que:{m['queja_pct']:5.1f}%  "
                  f"Ave:{m['aves_pct']:5.1f}%  "
                  f"Ctr:{m['ctr_hz']:6.0f}Hz  "
                  f"RMS:{m['rms_db']:6.1f}dB")

        if not metricas_clase:
            continue

        # Calcular estadisticos por metrica
        perfil = {'n_audios': len(metricas_clase)}
        claves = ['dur_s', 'rms_db', 'moo_pct', 'queja_pct',
                  'aves_pct', 'bov_total', 'bov_ext', 'ctr_hz', 'pico_hz']

        for clave in claves:
            valores = [m[clave] for m in metricas_clase]
            media   = float(np.mean(valores))
            desv    = float(np.std(valores))
            perfil[clave] = {
                'media':  round(media, 2),
                'desv':   round(desv, 2),
                'minimo': round(float(np.min(valores)), 2),
                'maximo': round(float(np.max(valores)), 2),
                # Limites para deteccion de anomalias
                'lim_min': round(media - MARGEN_ANOMALIA * desv, 2),
                'lim_max': round(media + MARGEN_ANOMALIA * desv, 2),
            }

        perfiles[clase] = perfil
        print(f"  OK {clase}: perfil calculado con {len(metricas_clase)} audios")

    # Guardar perfiles
    with open(ARCHIVO_PERFIL, 'w', encoding='utf-8') as f:
        json.dump(perfiles, f, indent=2, ensure_ascii=False)

    print(f"\n  Guardado: {ARCHIVO_PERFIL}")

    # Mostrar resumen de perfiles
    print("\n" + "="*60)
    print("  RESUMEN DE PERFILES GENERADOS")
    print("="*60)

    for clase, perfil in perfiles.items():
        print(f"\n  {clase.upper()} ({perfil['n_audios']} audios de referencia):")
        print(f"    {'Metrica':<20} {'Media':>8} {'Desv':>6} {'Min':>8} {'Max':>8}")
        print(f"    {'-'*52}")
        metricas_mostrar = [
            ('moo_pct',   'Moo%'),
            ('queja_pct', 'Queja%'),
            ('aves_pct',  'Aves%'),
            ('bov_total', 'Bovino total'),
            ('ctr_hz',    'Centroide Hz'),
            ('rms_db',    'RMS dB'),
        ]
        for clave, etiqueta in metricas_mostrar:
            if clave in perfil:
                p = perfil[clave]
                print(f"    {etiqueta:<20} {p['media']:>8.1f} {p['desv']:>6.1f} "
                      f"{p['minimo']:>8.1f} {p['maximo']:>8.1f}")

    print(f"\n  Listo. Ahora ejecuta con --modo escanear para validar el dataset.")


# ══════════════════════════════════════════════════════════════
# MODO 2 — ESCANEAR DATASET
# ══════════════════════════════════════════════════════════════
def detectar_flags(metricas, clase, perfiles, es_becerra=False):
    """
    Detecta anomalias reales comparando las metricas del audio
    contra el perfil de referencia de su clase.

    Solo reporta flags que podrian arruinar el entrenamiento,
    no diferencias menores que la red puede manejar.
    """
    flags = []

    # Checks absolutos — no dependen del perfil de referencia
    if metricas['rms_db'] > -3.0:
        flags.append('SATURADO')

    if metricas['dur_s'] > 4.5:
        flags.append('RECORTAR')

    if metricas['rms_db'] < -38.0:
        flags.append('NORMALIZAR')

    # Para becerras usar bovino extendido, para adultas bovino total
    bov_check = metricas['bov_ext'] if es_becerra else metricas['bov_total']
    if bov_check < 50.0:
        flags.append('SILENCIO')

    # Checks basados en perfil de referencia
    if clase in perfiles:
        p = perfiles[clase]

        # Contaminacion de aves fuera del rango de referencia
        if 'aves_pct' in p:
            lim_max_aves = p['aves_pct']['lim_max']
            # Para adultas ser mas estricto, para becerras mas tolerante
            umbral_aves = min(lim_max_aves, 25.0) if not es_becerra else min(lim_max_aves, 35.0)
            if metricas['aves_pct'] > umbral_aves:
                flags.append(f'ANOMALIA_AVE ({metricas["aves_pct"]:.1f}% > {umbral_aves:.1f}%)')

        # Centroide completamente fuera del rango de referencia
        if 'ctr_hz' in p:
            lim_min_ctr = p['ctr_hz']['lim_min']
            lim_max_ctr = p['ctr_hz']['lim_max']
            if metricas['ctr_hz'] < lim_min_ctr or metricas['ctr_hz'] > lim_max_ctr:
                flags.append(f'ANOMALIA_CTR ({metricas["ctr_hz"]:.0f}Hz fuera de [{lim_min_ctr:.0f}-{lim_max_ctr:.0f}])')

        # Queja% muy por encima del maximo de referencia
        # Solo flagear si supera el maximo absoluto de referencia, no la media
        if 'queja_pct' in p:
            maximo_queja = p['queja_pct']['maximo']
            # Dar margen de 15 puntos sobre el maximo de referencia
            umbral_queja = maximo_queja + 15.0
            if metricas['queja_pct'] > umbral_queja:
                flags.append(f'ANOMALIA_QUE ({metricas["queja_pct"]:.1f}% > {umbral_queja:.1f}%)')

    # Verificar si el perfil del audio se parece mas a otra clase
    # Solo si tenemos perfiles de referencia para comparar
    if perfiles and clase in perfiles:
        similitudes = {}
        for clase_ref, perfil_ref in perfiles.items():
            puntos = []
            for clave in ['moo_pct', 'queja_pct', 'ctr_hz']:
                if clave not in perfil_ref or clave not in metricas:
                    continue
                p_ref = perfil_ref[clave]
                valor = metricas[clave]
                desv  = p_ref['desv'] + 1e-8
                dist  = abs(valor - p_ref['media']) / desv
                puntos.append(max(0.0, 1.0 - dist / 3.0))
            if puntos:
                similitudes[clase_ref] = np.mean(puntos)

        if similitudes:
            clase_mas_similar = max(similitudes, key=similitudes.get)
            if (clase_mas_similar != clase and
                    similitudes[clase_mas_similar] > similitudes.get(clase, 0) + 0.2):
                flags.append(f'CLASE_DUDOSA (parece {clase_mas_similar})')

    return flags if flags else ['OK']


def escanear_dataset():
    print("\n" + "="*60)
    print("  COW RUMIA — Escaneando dataset completo")
    print("="*60)

    # Cargar perfiles
    if not os.path.exists(ARCHIVO_PERFIL):
        print(f"\n  ! No se encontro {ARCHIVO_PERFIL}")
        print(f"  Primero ejecuta con --modo perfil para generarlo.")
        return

    with open(ARCHIVO_PERFIL, 'r', encoding='utf-8') as f:
        perfiles = json.load(f)
    print(f"\n  Perfiles cargados: {list(perfiles.keys())}")

    # Recolectar todos los archivos del dataset
    todos_archivos = []  # [(ruta, clase)]
    for clase, subcarpetas in CARPETAS_DATASET.items():
        for sub in subcarpetas:
            carpeta = os.path.join(BASE_DIR, sub)
            if not os.path.exists(carpeta):
                print(f"  ! Carpeta no encontrada: {carpeta}")
                continue
            for archivo in Path(carpeta).glob("*.wav"):
                if not debe_ignorar(str(archivo)):
                    todos_archivos.append((str(archivo), clase))

    print(f"\n  Total de archivos a analizar: {len(todos_archivos)}")

    # Calcular MD5 de todos para detectar duplicados
    print("\n  Calculando MD5 para deteccion de duplicados...")
    hashes_md5 = defaultdict(list)
    for i, (ruta, clase) in enumerate(todos_archivos):
        if i % 50 == 0:
            print(f"    {i}/{len(todos_archivos)}...")
        md5 = calcular_md5(ruta)
        if md5:
            hashes_md5[md5].append(ruta)

    md5_duplicados = {h: rutas for h, rutas in hashes_md5.items() if len(rutas) > 1}
    print(f"  Grupos de duplicados MD5: {len(md5_duplicados)}")

    # Analizar cada archivo
    print("\n  Analizando metricas espectrales...")
    resultados = []
    resumen_flags = defaultdict(int)

    for i, (ruta, clase) in enumerate(todos_archivos):
        if i % 50 == 0:
            print(f"    {i}/{len(todos_archivos)}...")

        nombre = Path(ruta).name
        es_becerra = nombre.lower().startswith('becerra')

        # Verificar duplicado
        md5 = calcular_md5(ruta)
        es_duplicado = md5 and len(hashes_md5[md5]) > 1

        # Cargar y analizar
        audio, dur_real = cargar_audio(ruta)
        if audio is None:
            resultados.append({
                'archivo': nombre, 'clase': clase, 'ruta': ruta,
                'dur_s': 0, 'rms_db': 0, 'moo_pct': 0,
                'queja_pct': 0, 'aves_pct': 0, 'bov_total': 0,
                'ctr_hz': 0, 'md5': md5 or '',
                'flags': 'ERROR_CARGA', 'es_becerra': es_becerra
            })
            continue

        metricas = analizar_audio(audio, dur_real)

        # Detectar flags
        flags = detectar_flags(metricas, clase, perfiles, es_becerra)

        # Agregar flag de duplicado si aplica
        if es_duplicado:
            flags = ['DUPLICADO'] + [f for f in flags if f != 'OK']

        flags_str = ' | '.join(flags)
        for flag in flags:
            resumen_flags[flag.split('(')[0].strip()] += 1

        resultados.append({
            'archivo':    nombre,
            'clase':      clase,
            'ruta':       ruta,
            'dur_s':      metricas['dur_s'],
            'rms_db':     metricas['rms_db'],
            'moo_pct':    metricas['moo_pct'],
            'queja_pct':  metricas['queja_pct'],
            'aves_pct':   metricas['aves_pct'],
            'bov_total':  metricas['bov_total'],
            'ctr_hz':     metricas['ctr_hz'],
            'md5':        md5 or '',
            'flags':      flags_str,
            'es_becerra': es_becerra,
        })

    # Exportar CSV
    archivo_csv = 'cow_rumia_scan_resultados.csv'
    columnas = ['archivo', 'clase', 'dur_s', 'rms_db', 'moo_pct',
                'queja_pct', 'aves_pct', 'bov_total', 'ctr_hz',
                'md5', 'flags', 'es_becerra', 'ruta']

    with open(archivo_csv, 'w', newline='', encoding='utf-8') as f:
        escritor = csv.DictWriter(f, fieldnames=columnas)
        escritor.writeheader()
        escritor.writerows(resultados)

    print(f"\n  Guardado: {archivo_csv}")

    # Exportar solo los casos con flags (sin OK)
    archivo_flags = 'cow_rumia_scan_anomalias.csv'
    con_flags = [r for r in resultados if r['flags'] != 'OK']

    if con_flags:
        with open(archivo_flags, 'w', newline='', encoding='utf-8') as f:
            escritor = csv.DictWriter(f, fieldnames=columnas)
            escritor.writeheader()
            escritor.writerows(con_flags)
        print(f"  Guardado: {archivo_flags} ({len(con_flags)} casos)")

    # Mostrar resumen
    total = len(resultados)
    total_ok    = sum(1 for r in resultados if r['flags'] == 'OK')
    total_flags = total - total_ok

    print("\n" + "="*60)
    print("  RESUMEN DEL ESCANEO")
    print("="*60)
    print(f"\n  Total de archivos analizados: {total}")
    print(f"  Sin anomalias (OK):           {total_ok}")
    print(f"  Con alguna anomalia:          {total_flags}")

    if resumen_flags:
        print(f"\n  Distribucion de flags:")
        for flag, cantidad in sorted(resumen_flags.items(),
                                      key=lambda x: x[1], reverse=True):
            if flag != 'OK':
                print(f"    {flag:<25} {cantidad:>4} archivos")

    if md5_duplicados:
        print(f"\n  Grupos de duplicados exactos (MD5):")
        for md5, rutas in md5_duplicados.items():
            print(f"    {md5[:12]}...  ({len(rutas)} copias)")
            for r in rutas:
                print(f"      {r}")

    print(f"\n  Revisa cow_rumia_scan_anomalias.csv para ver los casos")
    print(f"  que requieren atencion antes del reentrenamiento.")


# ══════════════════════════════════════════════════════════════
# EJECUCION PRINCIPAL
# ══════════════════════════════════════════════════════════════
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='COW RUMIA — Validador de Dataset')
    parser.add_argument(
        '--modo',
        choices=['perfil', 'escanear'],
        required=True,
        help='perfil: genera perfiles de referencia | escanear: valida el dataset completo'
    )
    args = parser.parse_args()

    if args.modo == 'perfil':
        generar_perfiles()
    elif args.modo == 'escanear':
        escanear_dataset()