import librosa
import numpy as np
import pandas as pd
import os
from pathlib import Path
from tqdm import tqdm # Si no lo tienes, usa: pip install tqdm

# --- CONFIGURACIÓN ---
BASE_DIR = r"D:\Recursos Tesina\AUDIO2"
OUTPUT_REPORT = "reporte_salud_dataset_vaca.csv"

def analizar_todo_el_dataset(directorio):
    datos_reporte = []
    extensiones = ['*.wav', '*.WAV']
    
    # Recolectar todos los archivos
    archivos = []
    for ext in extensiones:
        archivos.extend(list(Path(directorio).rglob(ext)))
    
    print(f"🔍 Analizando {len(archivos)} archivos. Por favor espera...")

    for ruta in tqdm(archivos):
        try:
            # Cargamos solo los primeros 3 segundos para ir rápido
            y, sr = librosa.load(str(ruta), sr=22050, duration=3.0)
            
            if len(y) == 0:
                continue

            # MÉTRICAS TÉCNICAS
            # 1. Centroide Espectral: ¿Es agudo (aves/ruido) o grave (vaca)?
            centroid = np.mean(librosa.feature.spectral_centroid(y=y, sr=sr))
            
            # 2. RMS: Volumen promedio
            rms = np.mean(librosa.feature.rms(y=y))
            
            # 3. Peak: Volumen máximo (para detectar saturación/clipping)
            peak = np.max(np.abs(y))
            
            # 4. Zero Crossing Rate: ¿Hay mucho ruido blanco/viento?
            zcr = np.mean(librosa.feature.zero_crossing_rate(y=y))
            
            # 5. Rolloff: Frecuencia donde cae la energía (ayuda a ver "brillo" de aves)
            rolloff = np.mean(librosa.feature.spectral_rolloff(y=y, sr=sr))

            # Clasificación automática de calidad
            estado = "ORO"
            razon = "Limpio"

            if centroid > 2800 or rolloff > 4500:
                estado = "FILTRAR"
                razon = "Ruido Agudo / Aves"
            elif peak > 0.98:
                estado = "REVISAR"
                razon = "Saturado (Clipping)"
            elif rms < 0.005:
                estado = "FILTRAR"
                razon = "Muy Silencioso"
            elif zcr > 0.18:
                estado = "REVISAR"
                razon = "Viento / Estática"

            datos_reporte.append({
                'Carpeta': ruta.parent.name,
                'Archivo': ruta.name,
                'Estado': estado,
                'Razón': razon,
                'Centroide_Hz': round(centroid, 2),
                'Energía_RMS': round(rms, 4),
                'Pico_Máximo': round(peak, 2),
                'ZCR': round(zcr, 4),
                'Ruta_Completa': str(ruta)
            })
            
        except Exception as e:
            print(f"Error procesando {ruta.name}: {e}")

    # Guardar a CSV
    df = pd.DataFrame(datos_reporte)
    df.to_csv(OUTPUT_REPORT, index=False, encoding='utf-8-sig')
    print(f"\n✅ ¡Análisis completado! Reporte guardado como: {OUTPUT_REPORT}")
    
    # Resumen rápido en consola
    print("\n--- RESUMEN DE CALIDAD ---")
    print(df['Estado'].value_counts())

if __name__ == "__main__":
    analizar_todo_el_dataset(BASE_DIR)