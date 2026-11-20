import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'motor.dart';
import 'utilidades.dart';

const int kBandas = 32;

/// Barras / ondas que reaccionan a la música en tiempo real.
///
/// Los datos reales vienen de Android (clase Visualizer) a través de
/// MainActivity.kt. Si no está disponible (sin permiso o sin ese archivo),
/// muestra una animación que sigue el estado de reproducción.
///
/// Se muestra en lugar de la carátula (toca la carátula para alternar).
/// El botón de la esquina cambia el estilo; mantenerlo presionado vuelve a pedir el permiso.
class VisualizadorEspectro extends StatefulWidget {
  final MotorMusica motor;
  final double lado;
  final Widget? fondo;

  const VisualizadorEspectro({
    super.key,
    required this.motor,
    required this.lado,
    this.fondo,
  });

  @override
  State<VisualizadorEspectro> createState() => _EstadoVisualizador();
}

class _EstadoVisualizador extends State<VisualizadorEspectro>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _ctl = MethodChannel('mi_musica/espectro');
  static const EventChannel _canal = EventChannel('mi_musica/espectro_datos');

  late final AnimationController _anim;
  final List<double> _objetivo = List<double>.filled(kBandas, 0.0);
  final List<double> _actual = List<double>.filled(kBandas, 0.0);
  final Stopwatch _reloj = Stopwatch()..start();

  StreamSubscription<dynamic>? _subDatos;
  StreamSubscription<int?>? _subSesion;
  bool _real = false;
  DateTime _ultimoDato = DateTime.fromMillisecondsSinceEpoch(0);
  int _cerosSeguidos = 0;
  bool _activo = false;

  MotorMusica get motor => widget.motor;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_paso);
    _encender();
  }

  @override
  void dispose() {
    _apagar();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _encender() async {
    _activo = true;
    _anim.repeat();
    await _iniciarReal(pedirSiFalta: !motor.espectroPreguntado);
  }

  void _apagar() {
    if (!_activo) return;
    _activo = false;
    _anim.stop();
    _subDatos?.cancel();
    _subDatos = null;
    _subSesion?.cancel();
    _subSesion = null;
    _real = false;
    _ctl.invokeMethod<bool>('detener').catchError((Object _) => false);
  }

  Future<void> _iniciarReal({required bool pedirSiFalta}) async {
    if (!Platform.isAndroid) return;
    try {
      var estado = await Permission.microphone.status;
      if (!estado.isGranted && pedirSiFalta && mounted) {
        motor.marcarEspectroPreguntado();
        final acepta = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Visualizador en vivo'),
            content: const Text(
              'Para que las barras reaccionen a la música, Android exige el permiso de '
              'micrófono. La app NO graba nada: solo analiza el sonido que ella misma reproduce.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true), child: const Text('Permitir')),
            ],
          ),
        );
        if (acepta == true) estado = await Permission.microphone.request();
      }
      if (!estado.isGranted || !mounted || !_activo) return;

      _subSesion?.cancel();
      _subSesion = motor.reproductor.androidAudioSessionIdStream.listen((id) async {
        if (id == null || !_activo) return;
        try {
          final ok = await _ctl.invokeMethod<bool>('iniciar', <String, dynamic>{'sesion': id});
          if (ok == true && _activo) {
            _real = true;
            _subDatos ??= _canal.receiveBroadcastStream().listen(_alRecibir);
          }
        } on MissingPluginException {
          _real = false; // falta MainActivity.kt: se queda la animación simulada
        } catch (_) {
          _real = false;
        }
      });
    } catch (_) {
      _real = false;
    }
  }

  Future<void> _reintentarPermiso() async {
    final estado = await Permission.microphone.status;
    if (estado.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    await _iniciarReal(pedirSiFalta: true);
  }

  void _alRecibir(dynamic datos) {
    if (datos is! List) return;
    var suma = 0.0;
    for (var i = 0; i < kBandas && i < datos.length; i++) {
      final v = (datos[i] as num).toDouble().clamp(0.0, 1.0);
      _objetivo[i] = v;
      suma += v;
    }
    _ultimoDato = DateTime.now();
    _cerosSeguidos = suma < 0.001 ? _cerosSeguidos + 1 : 0;
  }

  double _simulado(int i, double t) {
    final b = 0.5 + 0.5 * sin(t * 5 + i * 0.9);
    final c = 0.5 + 0.5 * sin(t * 2.3 + i * 0.35);
    return (0.15 + 0.6 * b * c) * (1 - i / kBandas * 0.45);
  }

  void _paso() {
    final suena = motor.reproductor.playing;
    final t = _reloj.elapsedMilliseconds / 1000.0;
    final recibiendo = _real &&
        _cerosSeguidos < 100 &&
        DateTime.now().difference(_ultimoDato).inMilliseconds < 600;
    for (var i = 0; i < kBandas; i++) {
      final double obj = !suena ? 0.0 : (recibiendo ? _objetivo[i] : _simulado(i, t));
      final a = _actual[i];
      // Sube rápido, baja más despacio: se ve más musical.
      _actual[i] = obj > a ? a + (obj - a) * 0.6 : a + (obj - a) * 0.14;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: motor.visualizador,
      builder: (context, estilo, _) {
        final e = estilo.clamp(1, 3);
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: widget.lado,
            height: widget.lado,
            color: Colors.black.withValues(alpha: 0.35),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.fondo != null) widget.fondo!,
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 44, 14, 14),
                  child: CustomPaint(
                    painter: _Pintor(
                      valores: _actual,
                      estilo: e,
                      color: context.acento,
                      repintar: _anim,
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onLongPress: _reintentarPermiso,
                    child: IconButton(
                      tooltip: 'Cambiar estilo',
                      onPressed: () => motor.setVisualizador(e % 3 + 1),
                      icon: const Icon(Icons.auto_graph_rounded, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pintor extends CustomPainter {
  final List<double> valores;
  final int estilo;
  final Color color;

  _Pintor({
    required this.valores,
    required this.estilo,
    required this.color,
    required Listenable repintar,
  }) : super(repaint: repintar);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final n = valores.length;
    final degradado = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [color.withValues(alpha: 0.35), color],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    final pincel = Paint()..shader = degradado;

    if (estilo == 2) {
      // Ondas: curva suave que sigue las barras.
      final puntos = <Offset>[
        for (var i = 0; i < n; i++)
          Offset(w * i / (n - 1), h - max(2.0, valores[i] * h)),
      ];
      final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (var i = 0; i < puntos.length - 1; i++) {
        final medio = Offset(
          (puntos[i].dx + puntos[i + 1].dx) / 2,
          (puntos[i].dy + puntos[i + 1].dy) / 2,
        );
        linea.quadraticBezierTo(puntos[i].dx, puntos[i].dy, medio.dx, medio.dy);
      }
      linea.lineTo(puntos.last.dx, puntos.last.dy);
      final relleno = Path.from(linea)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        relleno,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [color.withValues(alpha: 0.05), color.withValues(alpha: 0.5)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      canvas.drawPath(
        linea,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final hueco = w / n;
    final ancho = hueco * 0.62;
    for (var i = 0; i < n; i++) {
      final x = i * hueco + (hueco - ancho) / 2;
      final alto = max(3.0, valores[i] * h);
      final rect = estilo == 3
          ? Rect.fromLTWH(x, (h - alto) / 2, ancho, alto) // espejo: crece desde el centro
          : Rect.fromLTWH(x, h - alto, ancho, alto);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(ancho / 2)), pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _Pintor viejo) => true;
}
