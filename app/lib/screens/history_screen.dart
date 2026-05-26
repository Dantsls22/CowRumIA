import 'package:flutter/material.dart';
import '../models/recording_result.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<RecordingResult> _historial = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await HistoryService.cargarTodos();
    setState(() { _historial = lista; _cargando = false; });
  }

  Future<void> _renombrar(RecordingResult result) async {
    final ctrl = TextEditingController(text: result.nombre);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nombre del animal / registro'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Panchita 1, Vaca 23...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nuevo == null) return;
    await HistoryService.actualizarNombre(result.id, nuevo);
    _cargar();
  }

  Future<void> _eliminarDirecto(RecordingResult result) async {
    await HistoryService.eliminar(result.id);
    _cargar();
  }

  Color _colorEstres(StressLevel nivel) => switch (nivel) {
        StressLevel.alto     => AppColors.stressHigh,
        StressLevel.moderado => AppColors.stressMedium,
        StressLevel.leve     => AppColors.stressLow,
        StressLevel.nulo     => AppColors.stressLow,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          if (_historial.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Borrar todo',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('¿Borrar todo el historial?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.stressHigh),
                        child: const Text('Borrar todo'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await HistoryService.limpiarTodo();
                  _cargar();
                }
              },
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _historial.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Sin registros aún',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historial.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _historial[i];
                    final color = _colorEstres(r.stressLevel);
                    final titulo = r.nombre.isNotEmpty
                        ? r.nombre
                        : '${r.cowTypeLabel} — ${r.stressLabel}';

                    return Dismissible(
                      key: Key(r.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.stressHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_rounded,
                            color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _eliminarDirecto(r);
                        return false;
                      },
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.surfaceVariant),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(
                              r.stressLevel == StressLevel.alto
                                  ? Icons.warning_rounded
                                  : r.stressLevel == StressLevel.moderado
                                      ? Icons.warning_amber_rounded
                                      : r.stressLevel == StressLevel.leve
                                          ? Icons.info_rounded
                                          : Icons.check_circle_rounded,
                              color: color,
                            ),
                          ),
                          title: Text(titulo,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, color: color)),
                          subtitle: Text(
                            '${r.cowTypeLabel} · ${r.stressPercentage.toStringAsFixed(1)}% estrés · ${_formatFecha(r.timestamp)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                tooltip: 'Renombrar',
                                onPressed: () => _renombrar(r),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                          onTap: () async {
                            // Espera resultado — si fue true (eliminado) recarga
                            final eliminado = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultScreen(
                                  result: r,
                                  desdeHistorial: true,
                                ),
                              ),
                            );
                            if (eliminado == true) _cargar();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatFecha(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}