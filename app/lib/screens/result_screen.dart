import 'package:flutter/material.dart';
import '../models/recording_result.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final RecordingResult result;
  final String? labelModelo;
  final CowType? cowTypeUsuario;
  final bool desdeHistorial;
  final double? confianzaModelo; // confianza de la clase ganadora (0-100)

  const ResultScreen({
    super.key,
    required this.result,
    this.labelModelo,
    this.cowTypeUsuario,
    this.desdeHistorial = false,
    this.confianzaModelo,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.result.stressPercentage / 100,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _stressColor => switch (widget.result.stressLevel) {
        StressLevel.nulo => AppColors.stressLow,
        StressLevel.leve => AppColors.stressLow,
        StressLevel.moderado => AppColors.stressMedium,
        StressLevel.alto => AppColors.stressHigh,
      };

  IconData get _stressIcon => switch (widget.result.stressLevel) {
        StressLevel.nulo => Icons.check_circle_rounded,
        StressLevel.leve => Icons.info_rounded,
        StressLevel.moderado => Icons.warning_amber_rounded,
        StressLevel.alto => Icons.warning_rounded,
      };

  String get _stressLabelDisplay => switch (widget.result.stressLevel) {
        StressLevel.nulo => 'SIN ESTRÉS',
        StressLevel.leve => 'ESTRÉS LEVE',
        StressLevel.moderado => 'ESTRÉS MODERADO',
        StressLevel.alto => 'ESTRÉS ALTO',
      };

  String get _stressDescription => switch (widget.result.stressLevel) {
        StressLevel.nulo =>
          'El animal no presenta signos de estrés. Condiciones adecuadas.',
        StressLevel.leve =>
          'El animal muestra indicios leves de estrés. Monitorear el ambiente.',
        StressLevel.moderado =>
          'El animal muestra estrés moderado. Considerar mejoras en el manejo.',
        StressLevel.alto =>
          'El animal presenta signos claros de estrés. Se recomienda atención inmediata.',
      };

  Widget? _notaDiscrepancia() {
    if (widget.labelModelo == null || widget.cowTypeUsuario == null)
      return null;
    if (widget.confianzaModelo == null || widget.confianzaModelo! < 70)
      return null;
    final modeloEsLeche = widget.labelModelo!.contains('leche');
    final usuarioEsLeche = widget.cowTypeUsuario == CowType.leche;
    if (modeloEsLeche == usuarioEsLeche) return null;
    final sugerencia = modeloEsLeche ? 'leche' : 'engorda';
    final confianzaStr = widget.confianzaModelo!.toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
          'Nota ($confianzaStr% de confianza): El modelo sugiere que esta '
          'vocalización corresponde a ganado de $sugerencia. '
          'Verifica el tipo seleccionado.',
          style:
              const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
        )),
      ]),
    );
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('¿Eliminar este registro del historial?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.stressHigh),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await HistoryService.eliminar(widget.result.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final nota = _notaDiscrepancia();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('RESULTADO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta principal
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _stressColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _stressColor.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    Icon(_stressIcon, color: _stressColor, size: 52),
                    const SizedBox(height: 10),
                    Text(
                      _stressLabelDisplay,
                      style: TextStyle(
                        color: _stressColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Ganado de ${widget.result.cowTypeLabel}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, _) {
                        final pct = _progressAnimation.value * 100;
                        return Column(children: [
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _stressColor,
                              fontSize: 60,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.confianzaModelo != null)
                            Text(
                              'Confianza de respuesta: ${widget.confianzaModelo!.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic),
                            ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progressAnimation.value,
                              minHeight: 18,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_stressColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sin estrés',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.stressLow,
                                      fontWeight: FontWeight.w600)),
                              Text('Estrés alto',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.stressHigh,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ]);
                      },
                    ),
                    if (nota != null) nota,
                  ]),
                ),

                const SizedBox(height: 16),

                // Descripción
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _stressColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _stressColor.withOpacity(0.3)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: _stressColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_stressDescription,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.5))),
                      ]),
                ),

                const SizedBox(height: 16),

                // Detalles
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Detalles',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 10),
                        _DetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Fecha',
                            value: _formatDate(widget.result.timestamp)),
                        _DetailRow(
                            icon: Icons.timer_rounded,
                            label: 'Duración',
                            value:
                                '${widget.result.duration.inSeconds} segundos'),
                        _DetailRow(
                            icon: Icons.category_rounded,
                            label: 'Tipo',
                            value: widget.result.cowTypeLabel),
                        if (widget.result.nombre.isNotEmpty)
                          _DetailRow(
                              icon: Icons.label_rounded,
                              label: 'Animal',
                              value: widget.result.nombre),
                      ]),
                ),

                const SizedBox(height: 24),

                // Botones según origen
                if (!widget.desdeHistorial) ...[
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Nueva grabación'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: _eliminar,
                    icon: const Icon(Icons.delete_rounded,
                        color: AppColors.stressHigh),
                    label: const Text('Eliminar registro',
                        style: TextStyle(
                            color: AppColors.stressHigh,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.stressHigh, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}  '
      '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
        ]),
      );
}
