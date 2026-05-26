import 'package:flutter/material.dart';
import '../models/recording_result.dart';
import '../theme/app_theme.dart';
import '../widgets/cow_type_card.dart';
import '../widgets/record_button.dart';
import '../services/audio_recorder_service.dart';
import '../services/classifier_service.dart';
import '../services/history_service.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  CowType? _selectedType;
  bool _isRecording  = false;
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  final AudioRecorderService _recorder   = AudioRecorderService();
  final ClassifierService    _classifier = ClassifierService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _classifier.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorder.dispose();
    _classifier.dispose();
    super.dispose();
  }

  void _onTypeSelected(CowType type) => setState(() => _selectedType = type);

  Future<void> _startRecording() async {
    if (_selectedType == null) {
      _snackbar('Selecciona el tipo de ganado primero');
      return;
    }
    final tienePermiso = await _recorder.tienePermiso();
    if (!tienePermiso) {
      _snackbar('Se necesita permiso de micrófono', esError: true);
      return;
    }
    setState(() => _isRecording = true);
    _pulseController.repeat(reverse: true);

    List<double>? muestras;
    try {
      muestras = await _recorder.grabarYProcesar();
    } catch (e) {
      _pulseController.stop();
      setState(() => _isRecording = false);
      _snackbar('Error al grabar: $e', esError: true);
      return;
    }

    _pulseController.stop();
    setState(() { _isRecording = false; _isProcessing = true; });

    if (muestras == null || muestras.isEmpty) {
      setState(() => _isProcessing = false);
      return;
    }
    await _procesarYNavegar(muestras);
  }

  Future<void> _procesarYNavegar(List<double> muestras) async {
    try {
      final resultado = await _classifier.classify(muestras);
      setState(() => _isProcessing = false);

      if (!resultado.isValid) {
        _dialogo(resultado.warningMessage ?? 'Audio no válido');
        return;
      }

      final result = RecordingResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        cowType: _selectedType!,
        stressPercentage: resultado.stressPercentage,
        audioPath: _recorder.ultimaRuta ?? '',
        duration: const Duration(seconds: 6),
      );

      await HistoryService.guardar(result);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            labelModelo: resultado.label,
            cowTypeUsuario: _selectedType!,
            confianzaModelo: resultado.confidence,
            desdeHistorial: false,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      _snackbar('Error en clasificación: $e', esError: true);
    }
  }

  void _snackbar(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: esError ? AppColors.accentDark : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _dialogo(String mensaje) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 10),
          Text('Audio no válido'),
        ]),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COW RUMIA'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historial',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configuración',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(children: [
                  Text('Detección de Estrés Bovino',
                      style: TextStyle(
                          color: AppColors.textOnDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                  SizedBox(height: 4),
                  Text('Selecciona el tipo de ganado y graba el mugido',
                      style: TextStyle(color: Color(0xFFB9F6CA), fontSize: 13),
                      textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 20),
              const _StepLabel(number: '1', label: 'Tipo de ganado'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: CowTypeCard(
                  type: CowType.engorda,
                  isSelected: _selectedType == CowType.engorda,
                  onTap: (_isRecording || _isProcessing)
                      ? null
                      : () => _onTypeSelected(CowType.engorda),
                )),
                const SizedBox(width: 12),
                Expanded(child: CowTypeCard(
                  type: CowType.leche,
                  isSelected: _selectedType == CowType.leche,
                  onTap: (_isRecording || _isProcessing)
                      ? null
                      : () => _onTypeSelected(CowType.leche),
                )),
              ]),
              const SizedBox(height: 24),
              const _StepLabel(number: '2', label: 'Grabar mugido'),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: _isProcessing
                        ? const _ProcessingIndicator()
                        : AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Transform.scale(
                              scale: _isRecording ? _pulseAnimation.value : 1.0,
                              child: child,
                            ),
                            child: RecordButton(
                              isRecording: _isRecording,
                              isEnabled: !_isProcessing && !_isRecording,
                              onPressed: _startRecording,
                            ),
                          ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _isRecording ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.recordingBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.recording, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: AppColors.recording, size: 14),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Grabando 6 segundos... espera el resultado',
                          style: TextStyle(
                              color: AppColors.recording,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator();
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('Analizando vocalización...',
              style: TextStyle(color: AppColors.primary,
                  fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      );
}

class _StepLabel extends StatelessWidget {
  final String number;
  final String label;
  const _StepLabel({required this.number, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text(number,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 14)))),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 16,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]);
}