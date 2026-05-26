import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassificationResult {
  final String label;
  final double confidence;
  final double stressPercentage;
  final bool isValid;
  final String? warningMessage;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.stressPercentage,
    required this.isValid,
    this.warningMessage,
  });
}

class ClassifierService {
  static const String _yamnetPath = 'assets/models/yamnet_embeddings.tflite';
  static const String _densePath  = 'assets/models/cowrumia_dense.tflite';
  static const String _labelsPath = 'assets/models/labels.txt';

  static const double _rmsMinimo       = 0.003;
  static const double _peakMaximo      = 0.92;
  static const double _umbralConfianza = 0.58;
  static const double _umbralResidual  = 10.0;

  static Interpreter? _yamnet;
  static Interpreter? _dense;
  static List<String> _labels = [];
  static bool         _ready  = false;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      _yamnet = await Interpreter.fromAsset(_yamnetPath);
      _dense  = await Interpreter.fromAsset(_densePath);
      final data = await rootBundle.loadString(_labelsPath);
      _labels = data.split('\n').where((s) => s.isNotEmpty).toList();
      _ready  = true;
      print('[Classifier] Listo. Clases: $_labels');
    } catch (e) {
      _ready = false;
      throw Exception('Error cargando modelos: $e');
    }
  }

  Future<ClassificationResult> classify(List<double> samples) async {
    final stopwatch = Stopwatch()..start();
    if (!_ready) await initialize();

    final rms       = _rms(samples);
    final peak      = samples.map((s) => s.abs()).reduce(max);
    final centroide = _centroideRapido(samples, 16000);
    final eBaja     = _energiaBanda(samples, 16000, 50, 800);

    print('[Classifier] RMS=${rms.toStringAsFixed(4)} '
          'peak=${peak.toStringAsFixed(3)} '
          'centroide=${centroide.toStringAsFixed(0)}Hz '
          'eBaja=${(eBaja*100).toStringAsFixed(1)}%');

    if (rms < _rmsMinimo) {
      return const ClassificationResult(
        label: 'sin_audio', confidence: 0, stressPercentage: 0, isValid: false,
        warningMessage: 'No se detectó ninguna vocalización.\n'
            'Acerca el teléfono al animal e intenta de nuevo.',
      );
    }

    if (peak > _peakMaximo) {
      return const ClassificationResult(
        label: 'saturado', confidence: 0, stressPercentage: 0, isValid: false,
        warningMessage: 'El audio está saturado.\n'
            'Aleja el micrófono del animal e intenta de nuevo.',
      );
    }

    final embedding = await _extraerEmbedding(samples);
    if (embedding == null) {
      return const ClassificationResult(
        label: 'error', confidence: 0, stressPercentage: 0, isValid: false,
        warningMessage: 'Error procesando el audio.',
      );
    }

    final probs = await _clasificarEmbedding(embedding);
    if (probs == null) {
      return const ClassificationResult(
        label: 'error', confidence: 0, stressPercentage: 0, isValid: false,
        warningMessage: 'Error en la clasificación.',
      );
    }

    final maxIdx = _argmax(probs);
    final conf   = probs[maxIdx];
    final label  = maxIdx < _labels.length ? _labels[maxIdx] : 'desconocido';

    final double pEstresCrudo = probs[0] + probs[1];
    double pctEstres;

    if (label.contains('estres') && !label.contains('no_estres')) {
      // Ponderador RMS original — ya funcionaba bien
      final double factorIntensidad = (rms / 0.15).clamp(0.0, 1.0);
      pctEstres = (pEstresCrudo * 100) * factorIntensidad;

      // Estrés ALTO solo si hay evidencia física: bramido fuerte Y modelo muy seguro
      // RMS > 0.08 (vocalización intensa) + pEstresCrudo > 0.85 (modelo seguro)
      // Si no se cumplen ambas → cap en 70% (moderado máximo)
      if (!(rms > 0.08 && pEstresCrudo > 0.85)) {
        pctEstres = pctEstres.clamp(0.0, 70.0);
      }

      if (pctEstres < 15.0 && pEstresCrudo > 0.70) pctEstres = 15.0;
    } else {
      pctEstres = (pEstresCrudo * 100) * 0.15;
      if (pctEstres < _umbralResidual) pctEstres = 0.0;
    }

    pctEstres = pctEstres.clamp(0.0, 100.0);

    // Veto espectral fenomenológico
    if (pctEstres > 50.0 && centroide < 1100.0 && eBaja > 0.60) {
      print('[Classifier] Veto espectral → 20%');
      pctEstres = 20.0;
    }

    stopwatch.stop();
    print('[Classifier] Scores: $probs → $label '
          '(conf=${(conf*100).toStringAsFixed(1)}%) '
          'P(final)=${pctEstres.toStringAsFixed(1)}%');
    print('[Timing] Total inferencia: ${stopwatch.elapsedMilliseconds}ms');

    if (conf < _umbralConfianza) {
      return ClassificationResult(
        label: label,
        confidence: conf * 100,
        stressPercentage: pctEstres,
        isValid: false,
        warningMessage: 'Resultado no concluyente (${(conf*100).toStringAsFixed(1)}%).\n'
            'Intenta grabar con menos ruido ambiental.',
      );
    }

    return ClassificationResult(
      label: label,
      confidence: conf * 100,
      stressPercentage: pctEstres,
      isValid: true,
    );
  }

  Future<List<double>?> _extraerEmbedding(List<double> samples) async {
    final sw = Stopwatch()..start();
    try {
      const int maxMuestras = 96000;
      final List<double> muestrasSeguras = samples.length > maxMuestras
          ? samples.sublist(0, maxMuestras)
          : samples;

      final preEnfatizado = Float32List(muestrasSeguras.length);
      preEnfatizado[0] = muestrasSeguras[0].toDouble();
      for (int i = 1; i < muestrasSeguras.length; i++) {
        preEnfatizado[i] =
            (muestrasSeguras[i] - 0.97 * muestrasSeguras[i - 1]).toDouble();
      }

      double maxAmp = 0.0;
      for (int i = 0; i < preEnfatizado.length; i++) {
        if (preEnfatizado[i].abs() > maxAmp) maxAmp = preEnfatizado[i].abs();
      }
      final inputData = Float32List(muestrasSeguras.length);
      final factor = maxAmp > 0.001 ? 0.9 / maxAmp : 1.0;
      for (int i = 0; i < preEnfatizado.length; i++) {
        inputData[i] = (preEnfatizado[i] * factor).clamp(-1.0, 1.0);
      }

      _yamnet!.resizeInputTensor(0, [muestrasSeguras.length]);
      _yamnet!.allocateTensors();
      final output = [List<double>.filled(1024, 0.0)];
      _yamnet!.run(inputData, output);
      sw.stop();
      print('[Timing] YAMNet embedding: ${sw.elapsedMilliseconds}ms');
      return output[0];
    } catch (e) {
      print('[Classifier] Error YAMNet: $e');
      return null;
    }
  }

  Future<List<double>?> _clasificarEmbedding(List<double> embedding) async {
    try {
      final input  = [Float32List.fromList(embedding)];
      final output = [List<double>.filled(_labels.length, 0.0)];
      _dense!.run(input, output);
      return output[0];
    } catch (e) {
      print('[Classifier] Error Dense: $e');
      return null;
    }
  }

  double _centroideRapido(List<double> samples, int sr) {
    const blockSize = 1024;
    const maxBlocks = 5;
    final numBlocks = (samples.length ~/ blockSize).clamp(0, maxBlocks);
    if (numBlocks == 0) return 0.0;
    double total = 0.0;
    int procesados = 0;
    for (int b = 0; b < numBlocks; b++) {
      final start = b * blockSize;
      double sumPeso = 0.0, sumMag = 0.0;
      for (int k = 1; k <= blockSize ~/ 2; k++) {
        double re = 0.0, im = 0.0;
        for (int i = 0; i < blockSize; i++) {
          final angle = 2 * pi * k * i / blockSize;
          re += samples[start + i] * cos(angle);
          im += samples[start + i] * sin(angle);
        }
        final mag  = sqrt(re * re + im * im);
        final freq = k.toDouble() * sr / blockSize;
        sumPeso += freq * mag;
        sumMag  += mag;
      }
      if (sumMag > 0) { total += sumPeso / sumMag; procesados++; }
    }
    return procesados > 0 ? total / procesados : 0.0;
  }

  double _energiaBanda(List<double> samples, int sr, int freqMin, int freqMax) {
    const blockSize = 1024;
    const maxBlocks = 5;
    final numBlocks = (samples.length ~/ blockSize).clamp(0, maxBlocks);
    if (numBlocks == 0) return 0.0;
    double eBanda = 0.0, eTotal = 0.0;
    for (int b = 0; b < numBlocks; b++) {
      final start = b * blockSize;
      for (int k = 1; k <= blockSize ~/ 2; k++) {
        double re = 0.0, im = 0.0;
        for (int i = 0; i < blockSize; i++) {
          final angle = 2 * pi * k * i / blockSize;
          re += samples[start + i] * cos(angle);
          im += samples[start + i] * sin(angle);
        }
        final mag  = sqrt(re * re + im * im);
        final freq = k.toDouble() * sr / blockSize;
        eTotal += mag;
        if (freq >= freqMin && freq <= freqMax) eBanda += mag;
      }
    }
    return eTotal > 0 ? eBanda / eTotal : 0.0;
  }

  double _rms(List<double> s) {
    if (s.isEmpty) return 0.0;
    return sqrt(s.fold(0.0, (a, x) => a + x * x) / s.length);
  }

  int _argmax(List<double> v) {
    int idx = 0;
    for (int i = 1; i < v.length; i++) if (v[i] > v[idx]) idx = i;
    return idx;
  }

  void dispose() {
    _yamnet?.close();
    _dense?.close();
    _yamnet = null;
    _dense  = null;
    _ready  = false;
  }
}