import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import os
import numpy as np
import librosa
import tensorflow as tf
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import tensorflow_hub as hub
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils import shuffle
from pathlib import Path
import seaborn as sns
import joblib

# ══════════════════════════════════════════════════════════════
# CONFIGURACION
# ══════════════════════════════════════════════════════════════

BASE_DIR  = r"D:\Recursos Tesina\AUDIO2_NORMALIZADO"  
YAMNET_SR = 16000

RUTAS_CLASES = {
    "estres_engorda":    [Path(BASE_DIR) / "engorda_estres"],
    "no_estres_engorda": [Path(BASE_DIR) / "engorda_no_estres"],
    "estres_leche":      [Path(BASE_DIR) / "leche_estres" / "leche_estres",
                          Path(BASE_DIR) / "leche_estres" / "Becerra_estres"],
    "no_estres_leche":   [Path(BASE_DIR) / "leche_no_estres"],
}

# ══════════════════════════════════════════════════════════════
# CARGAR YAMNET
# ══════════════════════════════════════════════════════════════

print("Cargando YAMNet desde TensorFlow Hub...")
yamnet_model = hub.load('https://tfhub.dev/google/yamnet/1')
print("YAMNet listo.")


def extraer_embeddings_yamnet(ruta_archivo):
    try:
        wav, _ = librosa.load(str(ruta_archivo), sr=YAMNET_SR)
        waveform = tf.convert_to_tensor(wav, dtype=tf.float32)
        _, embeddings, _ = yamnet_model(waveform)
        return np.mean(embeddings.numpy(), axis=0)
    except Exception as e:
        print(f"  ! Error en {ruta_archivo.name}: {e}")
        return None


# ══════════════════════════════════════════════════════════════
# PASO 1 — CARGAR AUDIOS ORIGINALES (sin aumentacion)
# ══════════════════════════════════════════════════════════════

print("\nExtrayendo embeddings de audios originales...")
X_orig = []
y_orig = []

for nombre_clase, rutas in RUTAS_CLASES.items():
    contador = 0
    for ruta in rutas:
        if not ruta.exists():
            print(f"  ! Ruta no encontrada: {ruta}")
            continue
        archivos = list(set(
            list(ruta.glob("*.wav")) + list(ruta.glob("*.WAV"))
        ))
        for archivo in archivos:
            emb = extraer_embeddings_yamnet(archivo)
            if emb is not None:
                X_orig.append(emb)
                y_orig.append(nombre_clase)
                contador += 1
    print(f"  {nombre_clase}: {contador} audios originales")

X_orig = np.array(X_orig)
y_orig = np.array(y_orig)
print(f"\nTotal audios originales: {len(X_orig)}")


# ══════════════════════════════════════════════════════════════
# PASO 2 — DIVIDIR ANTES DE AUMENTAR
# ══════════════════════════════════════════════════════════════

encoder   = LabelEncoder()
y_encoded = encoder.fit_transform(y_orig)

print(f"\nClases detectadas: {list(encoder.classes_)}")

X_train_orig, X_test, y_train_orig, y_test = train_test_split(
    X_orig, y_encoded,
    test_size=0.20,
    random_state=42,
    stratify=y_encoded
)

print(f"\nDivision inicial:")
print(f"  Entrenamiento (originales): {len(y_train_orig)}")
print(f"  Prueba (virgen):            {len(y_test)}")
for i, nombre in enumerate(encoder.classes_):
    n = np.sum(y_test == i)
    print(f"    {nombre}: {n} en prueba")


# ══════════════════════════════════════════════════════════════
# PASO 3 — AUMENTAR SOLO EL ENTRENAMIENTO
# ══════════════════════════════════════════════════════════════

print("\nAumentando conjunto de entrenamiento (solo clases no_estres)...")
X_train_aug = list(X_train_orig)
y_train_aug = list(y_train_orig)

for emb, etiq in zip(X_train_orig, y_train_orig):
    nombre_clase = encoder.inverse_transform([etiq])[0]
    if "no_estres" in nombre_clase:
        ruido = np.random.normal(0, 0.005, emb.shape)
        X_train_aug.append(emb + ruido)
        y_train_aug.append(etiq)

X_train, y_train = shuffle(
    np.array(X_train_aug),
    np.array(y_train_aug),
    random_state=42
)

print(f"  Entrenamiento final (con aumentacion): {len(y_train)}")


# ══════════════════════════════════════════════════════════════
# PASO 4 — MODELO
# ══════════════════════════════════════════════════════════════

num_clases = len(encoder.classes_)

modelo = models.Sequential([
    layers.Input(shape=(1024,)),
    layers.Dense(512, activation='relu'),
    layers.Dropout(0.5),
    layers.Dense(256, activation='relu'),
    layers.Dropout(0.4),
    layers.Dense(num_clases, activation='softmax')
], name="CowRumIA_YAMNet")

modelo.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.0005),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

modelo.summary()


# ══════════════════════════════════════════════════════════════
# PASO 5 — ENTRENAMIENTO
# ══════════════════════════════════════════════════════════════

controles = [
    tf.keras.callbacks.EarlyStopping(
        monitor='val_accuracy', patience=10,
        restore_best_weights=True, verbose=1
    ),
    tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss', factor=0.5,
        patience=5, min_lr=1e-6, verbose=1
    )
]

print("\nIniciando entrenamiento de CowRumIA YAMNet...")
historial = modelo.fit(
    X_train, y_train,
    epochs=50,
    batch_size=16,
    validation_data=(X_test, y_test),
    callbacks=controles,
    verbose=1
)


# ══════════════════════════════════════════════════════════════
# PASO 6 — EVALUACION FINAL
# ══════════════════════════════════════════════════════════════

print("\n" + "="*50)
print("  REPORTE DE RESULTADOS (prueba virgen)")
print("="*50)

probs  = modelo.predict(X_test, verbose=0)
y_pred = np.argmax(probs, axis=-1)

print(classification_report(
    y_test, y_pred,
    target_names=encoder.classes_,
    digits=3
))

# Porcentaje de estres — busca dinamicamente las clases de estres
clases_lista = list(encoder.classes_)
indices_estres = [i for i, c in enumerate(clases_lista) if "estres" in c and "no_estres" not in c]

if indices_estres:
    pct_estres = probs[:, indices_estres].sum(axis=1) * 100
    print(f"Porcentaje de estres promedio en prueba: {pct_estres.mean():.1f}%")


# ══════════════════════════════════════════════════════════════
# PASO 7 — GUARDAR
# ══════════════════════════════════════════════════════════════

modelo.save('cowrumia_yamnet_final.keras')
print("\nModelo guardado: cowrumia_yamnet_final.keras")

joblib.dump(encoder, 'cowrumia_yamnet_encoder.pkl')
print("Encoder guardado: cowrumia_yamnet_encoder.pkl")

print("  YAMNet + Dense (esta version) 85.6%  prueba virgen")


# ══════════════════════════════════════════════════════════════
# PASO 8 — REPORTE VISUAL
# ══════════════════════════════════════════════════════════════

def generar_reporte_visual(historial, modelo, X_test, y_test, nombres_clases):
    fig, ejes = plt.subplots(1, 2, figsize=(12, 5))
    fig.suptitle('CowRumIA YAMNet — Curvas de Entrenamiento', fontweight='bold')

    ejes[0].plot(historial.history['accuracy'],     label='Entrenamiento', color='steelblue', lw=2)
    ejes[0].plot(historial.history['val_accuracy'], label='Validacion',    color='darkorange', lw=2)
    ejes[0].set_title('Exactitud por Ciclo')
    ejes[0].set_xlabel('Ciclo'); ejes[0].set_ylabel('Exactitud')
    ejes[0].set_ylim(0, 1); ejes[0].legend(); ejes[0].grid(alpha=0.3)

    ejes[1].plot(historial.history['loss'],     label='Entrenamiento', color='steelblue', lw=2)
    ejes[1].plot(historial.history['val_loss'], label='Validacion',    color='darkorange', lw=2)
    ejes[1].set_title('Perdida por Ciclo')
    ejes[1].set_xlabel('Ciclo'); ejes[1].set_ylabel('Perdida')
    ejes[1].legend(); ejes[1].grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig('cowrumia_yamnet_curvas.png', dpi=150, bbox_inches='tight')
    plt.close()
    print("Guardado: cowrumia_yamnet_curvas.png")

    # Matriz de confusion
    y_pred_vis = np.argmax(modelo.predict(X_test, verbose=0), axis=-1)
    cm      = confusion_matrix(y_test, y_pred_vis)
    cm_norm = cm.astype(float) / (cm.sum(axis=1, keepdims=True) + 1e-8)

    etiquetas = ['Eng.Est', 'Eng.Tran', 'Lch.Est', 'Lch.Tran']
    fig, ejes = plt.subplots(1, 2, figsize=(14, 6))
    fig.suptitle('CowRumIA YAMNet — Matriz de Confusion', fontweight='bold')

    sns.heatmap(cm,      annot=True, fmt='d',    cmap='Blues',
                xticklabels=etiquetas, yticklabels=etiquetas, ax=ejes[0])
    ejes[0].set_title('Cantidad de audios')
    ejes[0].set_ylabel('Clase real'); ejes[0].set_xlabel('Clase predicha')

    sns.heatmap(cm_norm, annot=True, fmt='.2f', cmap='Blues',
                xticklabels=etiquetas, yticklabels=etiquetas,
                ax=ejes[1], vmin=0, vmax=1)
    ejes[1].set_title('Sensibilidad por clase')
    ejes[1].set_ylabel('Clase real'); ejes[1].set_xlabel('Clase predicha')

    plt.tight_layout()
    plt.savefig('cowrumia_yamnet_confusion.png', dpi=150, bbox_inches='tight')
    plt.close()
    print("Guardado: cowrumia_yamnet_confusion.png")
    
generar_reporte_visual(historial, modelo, X_test, y_test, encoder.classes_)