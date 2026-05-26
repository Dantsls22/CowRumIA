import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  static const int _sampleRate = 16000;
  static const int _duracion   = 6;

  Future<bool> tienePermiso() async => await _recorder.hasPermission();

  Future<void> iniciarGrabacion() async {
    final dir  = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/cowrumia_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder:     AudioEncoder.wav,
        sampleRate:  _sampleRate,
        numChannels: 1,
      ),
      path: _currentPath!,
    );
  }

  Future<String?> detenerGrabacion() async => await _recorder.stop();

  Future<List<double>?> grabarYProcesar() async {
    if (!await tienePermiso()) throw Exception('Permiso de micrófono denegado');
    await iniciarGrabacion();
    await Future.delayed(const Duration(seconds: _duracion));
    final path = await detenerGrabacion();
    if (path == null) return null;
    return await _wavAMuestras(path);
  }

  Future<List<double>?> muestrasDesdeRuta(String path) async {
    try {
      return await _wavAMuestras(path);
    } catch (e) {
      print('[Recorder] Error leyendo ruta: $e');
      return null;
    }
  }

  Future<List<double>> _wavAMuestras(String path) async {
    final bytes = await File(path).readAsBytes();
    const headerSize = 44;
    if (bytes.length <= headerSize) throw Exception('WAV vacío o corrupto');
    final dataBytes = bytes.sublist(headerSize);
    final samples   = <double>[];
    for (int i = 0; i < dataBytes.length - 1; i += 2) {
      int s = (dataBytes[i + 1] << 8) | dataBytes[i];
      if (s >= 32768) s -= 65536;
      samples.add(s / 32768.0);
    }
    return samples;
  }

  String? get ultimaRuta => _currentPath;
  void dispose() => _recorder.dispose();
}