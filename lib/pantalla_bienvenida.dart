import 'package:flutter/material.dart';

import 'motor.dart';
import 'utilidades.dart';

/// Guía de bienvenida. Sale solo la primera vez que se abre la app;
/// después se puede volver a ver desde Ajustes ("Ver guía de bienvenida").
class PantallaBienvenida extends StatefulWidget {
  final MotorMusica motor;

  /// true cuando se abre desde Ajustes: al terminar solo se cierra.
  final bool repaso;

  const PantallaBienvenida({super.key, required this.motor, this.repaso = false});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _Pagina {
  final IconData icono;
  final String titulo;
  final String texto;
  final List<(IconData, String)> puntos;
  const _Pagina(this.icono, this.titulo, this.texto, [this.puntos = const []]);
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> {
  final PageController _control = PageController();
  int _pagina = 0;
  bool _cerrando = false;

  static const List<_Pagina> _paginas = [
    _Pagina(
      Icons.graphic_eq_rounded,
      'Bienvenido a $kNombreApp',
      'Tu música, sin conexión y sin anuncios. Todo se queda en tu teléfono.',
    ),
    _Pagina(
      Icons.lock_open_rounded,
      'Permisos que te voy a pedir',
      'Solo lo necesario. Android te los preguntará al empezar.',
      [
        (Icons.audiotrack_rounded, 'Audio: para encontrar tus canciones.'),
        (Icons.notifications_rounded, 'Notificaciones: para los controles en la barra y la pantalla de bloqueo.'),
        (Icons.mic_rounded, 'Micrófono: solo para animar el visualizador. No graba nada.'),
      ],
    ),
    _Pagina(
      Icons.touch_app_rounded,
      'Gestos en el reproductor',
      'Estos atajos están sobre la carátula grande.',
      [
        (Icons.swipe_rounded, 'Desliza a los lados: cambia de canción.'),
        (Icons.keyboard_double_arrow_right_rounded, 'Doble toque: salta 10 s (derecha adelanta, izquierda retrocede).'),
        (Icons.equalizer_rounded, 'Un toque: muestra el visualizador.'),
        (Icons.edit_rounded, 'Mantén presionado: edita título, artista y carátula.'),
        (Icons.keyboard_arrow_down_rounded, 'Desliza hacia abajo: cierra el reproductor.'),
      ],
    ),
    _Pagina(
      Icons.auto_awesome_rounded,
      'Hazla tuya',
      'En Ajustes puedes cambiar colores y tema claro u oscuro, el crossfade entre canciones, '
          'los botones de la notificación y qué carpetas se muestran. '
          'En Inicio hay listas inteligentes y arriba tienes la búsqueda.',
    ),
  ];

  Future<void> _terminar() async {
    if (_cerrando) return;
    _cerrando = true;
    if (widget.repaso) {
      Navigator.of(context).pop();
    } else {
      await widget.motor.terminarBienvenida();
    }
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _pagina == _paginas.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: ultima ? null : _terminar,
                child: Text(ultima ? '' : 'Saltar'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _control,
                itemCount: _paginas.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (context, i) {
                  final p = _paginas[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.acento.withValues(alpha: 0.16),
                          ),
                          child: Icon(p.icono, size: 56, color: context.acento),
                        ),
                        const SizedBox(height: 28),
                        Text(p.titulo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(p.texto,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: tSuave, fontSize: 15.5, height: 1.4)),
                        const SizedBox(height: 22),
                        for (final (icono, texto) in p.puntos)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icono, size: 22, color: context.acento),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(texto, style: const TextStyle(fontSize: 14.5, height: 1.35)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _paginas.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _pagina ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: i == _pagina ? context.acento : tLinea,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (ultima) {
                      _terminar();
                    } else {
                      _control.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(ultima ? (widget.repaso ? 'Cerrar' : 'Empezar') : 'Siguiente',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
