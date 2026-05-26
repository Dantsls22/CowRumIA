import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Grabación ─────────────────────────────────────────
          const _SectionHeader(titulo: 'Grabación'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.surfaceVariant),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoRow(etiqueta: 'Duración de grabación', valor: '6 segundos'),
                SizedBox(height: 8),
                _InfoRow(etiqueta: 'Frecuencia de muestreo', valor: '16,000 Hz'),
                SizedBox(height: 8),
                _InfoRow(etiqueta: 'Canales', valor: 'Mono'),
                SizedBox(height: 8),
                _InfoRow(etiqueta: 'Formato', valor: 'WAV PCM 16-bit'),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // ── Modelo de IA ──────────────────────────────────────
          const _SectionHeader(titulo: 'Modelo de IA'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.surfaceVariant),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoRow(etiqueta: 'Arquitectura', valor: 'YAMNet + Dense'),
                SizedBox(height: 8),
                _InfoRow(etiqueta: 'Exactitud (prueba virgen)', valor: '84.0%'),
                SizedBox(height: 8),
                _InfoRow(etiqueta: 'Clases', valor: '4'),
                SizedBox(height: 8),
                _InfoRow(etiqueta: 'Umbral de confianza', valor: '60%'),
              ]),
            ),
          ),

          const SizedBox(height: 24),

          // ── Clases del modelo ─────────────────────────────────
          const _SectionHeader(titulo: 'Clases detectadas'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.surfaceVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _ClaseRow(nombre: 'Estrés — Engorda',   color: AppColors.stressHigh),
                const SizedBox(height: 8),
                _ClaseRow(nombre: 'Estrés — Leche',     color: AppColors.stressHigh),
                const SizedBox(height: 8),
                _ClaseRow(nombre: 'Sin estrés — Engorda', color: AppColors.stressLow),
                const SizedBox(height: 8),
                _ClaseRow(nombre: 'Sin estrés — Leche',   color: AppColors.stressLow),
              ]),
            ),
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text('COW RUMIA v1.0 — Tesina UAA 2025',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String titulo;
  const _SectionHeader({required this.titulo});
  @override
  Widget build(BuildContext context) => Text(titulo.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.primary, letterSpacing: 1.2));
}

class _InfoRow extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _InfoRow({required this.etiqueta, required this.valor});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(etiqueta, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary)),
    ],
  );
}

class _ClaseRow extends StatelessWidget {
  final String nombre;
  final Color color;
  const _ClaseRow({required this.nombre, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 10),
    Text(nombre, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
  ]);
}