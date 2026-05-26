# CowRumIA

**Automatic bovine stress detection via bioacoustics and deep learning**

CowRumIA is a system for classifying bovine vocalizations into four behavioral categories using transfer learning (YAMNet) and a custom Dense classifier, deployed as an Android mobile application built with Flutter.

> Undergraduate thesis — Ingeniería en Computación Inteligente  
> Universidad Autónoma de Aguascalientes (UAA) · May 2026  
> Author: Daniel Alejandro Tena Salas

---

## Results

| Metric | Value |
|--------|-------|
| Global accuracy (virgin test set) | **85.6%** |
| Test set size | 125 audios (never seen during training) |
| Full corpus accuracy | 94% |
| Corpus size | 624 WAV files · 4 classes |

### Classes

| Class | Description | Samples |
|-------|-------------|---------|
| `estres_engorda` | Stress vocalizations — beef cattle | 194 |
| `no_estres_engorda` | Calm vocalizations — beef cattle | 39 |
| `estres_leche` | Stress vocalizations — dairy cattle + calves | 350 |
| `no_estres_leche` | Calm vocalizations — dairy cattle | 41 |

---

## Repository Structure

```
cowrumia/
├── model/
│   ├── cow_rumia_train_v2.py
│   ├── cow_rumia_tflite_convert.py
│   └── requirements.txt
├── app/
│   ├── lib/
│   │   ├── services/
│   │   │   ├── classifier_service.dart
│   │   │   └── audio_recorder_service.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   └── result_screen.dart
│   │   └── main.dart
│   ├── assets/
│   │   └── models/
│   │       ├── yamnet_embeddings.tflite
│   │       ├── cowrumia_dense.tflite
│   │       └── labels.txt
│   └── pubspec.yaml
└── README.md
```

---

## Model Architecture

- **Feature extractor**: YAMNet (MobileNetV1, pretrained on AudioSet 521 classes) → 1024-dimensional embeddings
- **Classifier**: Dense MLP — 512 → 256 → 4 neurons, ReLU, Dropout (0.5 / 0.4), Softmax
- **Loss**: `sparse_categorical_crossentropy`
- **Augmentation**: Gaussian noise N(0, 0.005) on embeddings of minority classes

---

## Inference Pipeline (Mobile App)

```
WAV recording (6s · 16kHz · mono)
    → RMS / peak filters
    → Pre-emphasis (α = 0.97)
    → Peak normalization (90%)
    → YAMNet embeddings (1024D)
    → Dense classifier (4 classes)
    → Acoustic intensity weighting (RMS)
    → Stress level: None / Mild / Moderate / High
```

Confidence threshold: **58%**

---

## Dataset

The bovine vocalization corpus is available on Zenodo:

Tena Salas, D. A. (2026). *CowRumIA Bovine Vocalization Dataset* [Data set]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

Audio files: WAV · mono · 48,000 Hz · 16-bit PCM · ~3 seconds per clip

---

## Setup
# Tested on Python 3.12.10 · Windows x86_64
```bash
pip install -r model/requirements.txt
python model/train_model.py
python model/cow_rumia_tflite_convert.py
```

---

## Citation

If you use this work please cite:

```
Tena Salas, D. A. (2026). CowRumIA: Detección de estrés en ganado bovino
mediante bioacústica y redes neuronales convolucionales.
Tesina de Ingenieria, Universidad Autónoma de Aguascalientes.
```

---

## License

MIT License — free to use for research and extension to other species.
