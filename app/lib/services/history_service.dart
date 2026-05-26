import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording_result.dart';

class HistoryService {
  static const String _key = 'historial_grabaciones';

  /// Guarda un resultado al inicio del historial
  static Future<void> guardar(RecordingResult result) async {
    final prefs   = await SharedPreferences.getInstance();
    final lista   = await cargarTodos();
    lista.insert(0, result);
    final recorte = lista.take(100).toList();
    final encoded = recorte.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  /// Carga todos los resultados guardados
  static Future<List<RecordingResult>> cargarTodos() async {
    final prefs   = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_key) ?? [];
    return encoded
        .map((s) => RecordingResult.tryFromJson(s))
        .whereType<RecordingResult>()
        .toList();
  }

  /// Actualiza el nombre de un resultado por ID
  static Future<void> actualizarNombre(String id, String nombre) async {
    final prefs  = await SharedPreferences.getInstance();
    final lista  = await cargarTodos();
    final idx    = lista.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    lista[idx]   = lista[idx].copyWith(nombre: nombre);
    final encoded = lista.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  /// Elimina un resultado por ID
  static Future<void> eliminar(String id) async {
    final prefs  = await SharedPreferences.getInstance();
    final lista  = await cargarTodos();
    lista.removeWhere((r) => r.id == id);
    final encoded = lista.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  /// Borra todo el historial
  static Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}