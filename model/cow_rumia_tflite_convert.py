"""
COW RUMIA — Conversión TFLite CORREGIDA
=========================================
Genera yamnet_embeddings.tflite que SÍ expone los embeddings de 1024 dims.
El yamnet.tflite oficial de Google solo expone clasificación (521 clases),
no los embeddings. Este script crea uno que sí los expone.
"""

import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import numpy as np
import tensorflow as tf
import tensorflow_hub as hub
from pathlib import Path

# ══════════════════════════════════════════════════════════════
# CONFIGURACION
# ══════════════════════════════════════════════════════════════
MODELO_KERAS  = r"D:\Recursos Tesina\cowrumia_yamnet_final.keras"
ASSETS_DIR    = r"D:\Proyectos\Moo AI\cow_rumia\assets\models"

SALIDA_YAMNET = str(Path(ASSETS_DIR) / "yamnet_embeddings.tflite")
SALIDA_DENSE  = str(Path(ASSETS_DIR) / "cowrumia_dense.tflite")
SALIDA_LABELS = str(Path(ASSETS_DIR) / "labels.txt")

CLASES = [
    "estres_engorda",
    "estres_leche",
    "no_estres_engorda",
    "no_estres_leche",
]

Path(ASSETS_DIR).mkdir(parents=True, exist_ok=True)

# ══════════════════════════════════════════════════════════════
# PASO 1 — Crear YAMNet TFLite que expone EMBEDDINGS
# ══════════════════════════════════════════════════════════════
print("Cargando YAMNet desde TensorFlow Hub...")
yamnet_model = hub.load('https://tfhub.dev/google/yamnet/1')
print("YAMNet cargado.")

class YAMNetEmbeddings(tf.Module):
    """Wrapper que solo expone los embeddings de YAMNet (1024 dims)."""
    def __init__(self, yamnet):
        super().__init__()
        self.yamnet = yamnet

    @tf.function(input_signature=[
        tf.TensorSpec(shape=[None], dtype=tf.float32, name='waveform')
    ])
    def __call__(self, waveform):
        _, embeddings, _ = self.yamnet(waveform)
        # Promediar todos los frames -> un solo vector de 1024
        embedding_promedio = tf.reduce_mean(embeddings, axis=0, keepdims=True)
        return {'embeddings': embedding_promedio}

print("Creando wrapper de embeddings...")
wrapper = YAMNetEmbeddings(yamnet_model)

# Verificar que funciona
audio_prueba = tf.zeros([16000 * 3], dtype=tf.float32)
resultado    = wrapper(audio_prueba)
print(f"  Shape de embeddings: {resultado['embeddings'].shape}")  # debe ser (1, 1024)

# Convertir a TFLite
print("\nConvirtiendo YAMNet embeddings a TFLite...")
converter = tf.lite.TFLiteConverter.from_concrete_functions(
    [wrapper.__call__.get_concrete_function()],
    wrapper
)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_yamnet = converter.convert()

with open(SALIDA_YAMNET, 'wb') as f:
    f.write(tflite_yamnet)

tam = len(tflite_yamnet) / 1024 / 1024
print(f"YAMNet embeddings TFLite guardado: {tam:.1f} MB -> {SALIDA_YAMNET}")

# Verificar
interprete = tf.lite.Interpreter(model_path=SALIDA_YAMNET)
interprete.allocate_tensors()
entrada = interprete.get_input_details()
salidas = interprete.get_output_details()
print(f"  Entrada: {entrada[0]['shape']} {entrada[0]['dtype']}")
print(f"  Salida:  {salidas[0]['shape']} {salidas[0]['dtype']}")  # debe ser (1, 1024)

# ══════════════════════════════════════════════════════════════
# PASO 2 — Convertir Dense a TFLite
# ══════════════════════════════════════════════════════════════
print("\nCargando modelo Dense entrenado...")
dense_model = tf.keras.models.load_model(MODELO_KERAS)

print("Convirtiendo Dense a TFLite...")
converter2 = tf.lite.TFLiteConverter.from_keras_model(dense_model)
converter2.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_dense = converter2.convert()

with open(SALIDA_DENSE, 'wb') as f:
    f.write(tflite_dense)

tam2 = len(tflite_dense) / 1024 / 1024
print(f"Dense TFLite guardado: {tam2:.2f} MB -> {SALIDA_DENSE}")

# Verificar
interp2 = tf.lite.Interpreter(model_path=SALIDA_DENSE)
interp2.allocate_tensors()
ent2 = interp2.get_input_details()
sal2 = interp2.get_output_details()
print(f"  Entrada: {ent2[0]['shape']} {ent2[0]['dtype']}")  # debe ser (1, 1024)
print(f"  Salida:  {sal2[0]['shape']} {sal2[0]['dtype']}")  # debe ser (1, 4)

# ══════════════════════════════════════════════════════════════
# PASO 3 — Guardar etiquetas
# ══════════════════════════════════════════════════════════════
with open(SALIDA_LABELS, 'w', encoding='utf-8') as f:
    for clase in CLASES:
        f.write(clase + '\n')
print(f"\nEtiquetas guardadas: {SALIDA_LABELS}")

# ══════════════════════════════════════════════════════════════
# RESUMEN
# ══════════════════════════════════════════════════════════════
print("\n" + "="*55)
print("  ARCHIVOS LISTOS EN ASSETS/MODELS/")
print("="*55)
for f in Path(ASSETS_DIR).iterdir():
    tam = f.stat().st_size / 1024 / 1024
    print(f"  {f.name:<35} {tam:.2f} MB")

print("\nActualiza pubspec.yaml:")
print("  - assets/models/yamnet_embeddings.tflite")
print("  - assets/models/cowrumia_dense.tflite")
print("  - assets/models/labels.txt")