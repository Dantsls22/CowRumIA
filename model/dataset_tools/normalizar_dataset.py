import os
from pydub import AudioSegment
from pathlib import Path

# 1. Configuración de rutas
RUTA_ORIGINAL = r"D:\Recursos Tesina\AUDIO"
RUTA_NUEVA = r"D:\Recursos Tesina\AUDIO2_NORMALIZADO"

def normalizar_dataset_recursivo(origen, destino, target_db=-1.0):
    origen_path = Path(origen)
    destino_path = Path(destino)

    # Buscamos todos los archivos .wav en cualquier profundidad de subcarpetas
    archivos = list(origen_path.rglob("*.wav")) + list(origen_path.rglob("*.WAV"))
    
    if not archivos:
        print(f"No se encontraron archivos .wav en {origen}")
        return

    print(f"Iniciando normalización de {len(archivos)} archivos...")

    for archivo in archivos:
        # Calcular la ruta relativa para replicar la estructura de carpetas
        ruta_relativa = archivo.relative_to(origen_path)
        ruta_destino_archivo = destino_path / ruta_relativa
        
        # Crear la subcarpeta de destino si no existe
        ruta_destino_archivo.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            # Cargar y normalizar
            audio = AudioSegment.from_file(archivo)
            
            # Peak Normalization: calculamos la diferencia hasta el objetivo
            cambio_db = target_db - audio.max_dBFS
            audio_norm = audio.apply_gain(cambio_db)
            
            # Guardar copia
            audio_norm.export(ruta_destino_archivo, format="wav")
            # print(f"Normalizado: {ruta_relativa}") # Opcional: para ver el progreso
            
        except Exception as e:
            print(f"Error procesando {archivo.name}: {e}")

    print(f"\n¡Proceso completado! Dataset normalizado en: {destino}")

# Ejecutar el proceso
normalizar_dataset_recursivo(RUTA_ORIGINAL, RUTA_NUEVA)