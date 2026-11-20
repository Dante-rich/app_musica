import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'utilidades.dart';

/// Guarda los errores de la app en un archivo para poder revisarlos después
/// (Ajustes → Acerca de → Registro de errores). También anota cada vez que
/// la app arranca desde cero, lo que ayuda a saber si Android la cerró solo.
class RegistroErrores {
  static File? _archivo;

  static Future<File> _f() async {
    final actual = _archivo;
    if (actual != null) return actual;
    final d = await getApplicationSupportDirectory();
    return _archivo = File('${d.path}/registro_errores.txt');
  }

  static void instalar() {
    final previo = FlutterError.onError;
    FlutterError.onError = (detalles) {
      anotar('Error de Flutter', detalles.exceptionAsString(), detalles.stack);
      previo?.call(detalles);
    };
    PlatformDispatcher.instance.onError = (error, pila) {
      anotar('Error no controlado', '$error', pila);
      return true;
    };
  }

  static Future<void> anotar(String tipo, String mensaje, [StackTrace? pila]) async {
    try {
      final f = await _f();
      final ahora = DateTime.now().toString().split('.').first;
      final trozo = StringBuffer('[$ahora] $tipo: $mensaje\n');
      if (pila != null) {
        final lineas = pila.toString().split('\n').take(8).join('\n');
        trozo.writeln(lineas);
      }
      trozo.writeln();
      await f.writeAsString(trozo.toString(), mode: FileMode.append, flush: true);
      if (await f.length() > 200000) {
        final texto = await f.readAsString();
        await f.writeAsString(texto.substring(texto.length - 100000));
      }
    } catch (_) {}
  }

  static Future<String> leer() async {
    try {
      final f = await _f();
      if (!await f.exists()) return '';
      return await f.readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<void> borrar() async {
    try {
      final f = await _f();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class PantallaRegistroErrores extends StatefulWidget {
  const PantallaRegistroErrores({super.key});

  @override
  State<PantallaRegistroErrores> createState() => _PantallaRegistroErroresState();
}

class _PantallaRegistroErroresState extends State<PantallaRegistroErrores> {
  late Future<String> _texto = RegistroErrores.leer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de errores'),
        actions: [
          IconButton(
            tooltip: 'Copiar todo',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final t = await RegistroErrores.leer();
              await Clipboard.setData(ClipboardData(text: t));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copiado. Pégalo en el chat.')));
            },
          ),
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await RegistroErrores.borrar();
              final nuevo = RegistroErrores.leer();
              if (!mounted) return;
              setState(() {
                _texto = nuevo;
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _texto,
        builder: (context, snap) {
          final t = snap.data ?? '';
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: context.acento));
          }
          if (t.trim().isEmpty) {
            return Center(
              child: Text('Aún no hay errores guardados.', style: TextStyle(color: tSuave)),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              t,
              style: TextStyle(
                fontFamily: defaultTargetPlatform == TargetPlatform.android ? 'monospace' : null,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          );
        },
      ),
    );
  }
}
