import 'dart:convert';

enum CowType { engorda, leche }

enum StressLevel { nulo, leve, moderado, alto }

class RecordingResult {
  final String    id;
  final DateTime  timestamp;
  final CowType   cowType;
  final double    stressPercentage;
  final String    audioPath;
  final Duration  duration;
  final String    nombre;

  const RecordingResult({
    required this.id,
    required this.timestamp,
    required this.cowType,
    required this.stressPercentage,
    required this.audioPath,
    required this.duration,
    this.nombre = '',
  });

  // ── Nivel de estrés ───────────────────────────────────────────
  // Basado en probabilidad marginal P(estrés) = P(estres_engorda) + P(estres_leche)
  // leve: 11–34%  |  moderado: 35–69%  |  alto: 70–100%
  StressLevel get stressLevel {
    if (stressPercentage <= 10) return StressLevel.nulo;
    if (stressPercentage <= 30) return StressLevel.leve;
    if (stressPercentage <= 70) return StressLevel.moderado;
    return StressLevel.alto;
  }

  String get stressLabel {
    final base = switch (stressLevel) {
      StressLevel.nulo     => 'Sin estrés',
      StressLevel.leve     => 'Estrés leve',
      StressLevel.moderado => 'Estrés moderado',
      StressLevel.alto     => 'Estrés alto',
    };
    return nombre.isNotEmpty ? '$base — $nombre' : base;
  }

  String get cowTypeLabel => switch (cowType) {
        CowType.engorda => 'Engorda',
        CowType.leche   => 'Leche',
      };

  RecordingResult copyWith({String? nombre}) => RecordingResult(
        id:               id,
        timestamp:        timestamp,
        cowType:          cowType,
        stressPercentage: stressPercentage,
        audioPath:        audioPath,
        duration:         duration,
        nombre:           nombre ?? this.nombre,
      );

  Map<String, dynamic> toJson() => {
        'id':               id,
        'timestamp':        timestamp.toIso8601String(),
        'cowType':          cowType.index,
        'stressPercentage': stressPercentage,
        'audioPath':        audioPath,
        'durationSeconds':  duration.inSeconds,
        'nombre':           nombre,
      };

  factory RecordingResult.fromJson(Map<String, dynamic> j) => RecordingResult(
        id:               j['id'] as String,
        timestamp:        DateTime.parse(j['timestamp'] as String),
        cowType:          CowType.values[j['cowType'] as int],
        stressPercentage: (j['stressPercentage'] as num).toDouble(),
        audioPath:        j['audioPath'] as String? ?? '',
        duration:         Duration(seconds: j['durationSeconds'] as int? ?? 6),
        nombre:           j['nombre'] as String? ?? '',
      );

  static RecordingResult? tryFromJson(String raw) {
    try {
      return RecordingResult.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}