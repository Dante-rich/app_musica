import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'componentes.dart';
import 'motor.dart';
import 'pantalla_bienvenida.dart';
import 'pantalla_ecualizador.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_filtros.dart';
import 'registro_errores.dart';
import 'selector_color.dart';
import 'utilidades.dart';

class PantallaAjustes extends StatelessWidget {
  final MotorMusica motor;

  const PantallaAjustes({super.key, required this.motor});

  Future<void> _duracionMinima(BuildContext context) async {
    final opciones = <int, String>{
      0: 'Mostrar todo',
      15000: 'Ocultar menores de 15 segundos',
      30000: 'Ocultar menores de 30 segundos',
      60000: 'Ocultar menores de 1 minuto',
    };
    final elegido = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Audios cortos'),
        children: [
          for (final e in opciones.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Row(
                children: [
                  Expanded(child: Text(e.value)),
                  if (motor.duracionMinimaMs == e.key)
                    Icon(Icons.check_rounded, color: ctx.acento),
                ],
              ),
            ),
        ],
      ),
    );
    if (elegido != null) motor.setDuracionMinima(elegido);
  }

  Future<void> _elegirColor(BuildContext context) async {
    final c = await pedirColor(context, motor.acentoBase.value);
    if (c != null) motor.agregarColorPropio(c);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        motor,
        motor.tema,
        motor.suenoFin,
        motor.fundidoSeg,
        motor.visualizador,
      ]),
      builder: (context, _) {
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Ajustes',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(4, 2, 4, 20),
                child: Text('Personaliza tu reproductor',
                    style: TextStyle(color: tSuave)),
              ),

              // ---------------- Apariencia ----------------
              _grupo(context, 'Apariencia', Icons.palette_rounded, [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                      ButtonSegment(value: 1, icon: Icon(Icons.light_mode_rounded), label: Text('Claro')),
                      ButtonSegment(value: 2, icon: Icon(Icons.dark_mode_rounded), label: Text('Oscuro')),
                    ],
                    selected: {motor.modoTema.value},
                    onSelectionChanged: (v) => motor.setModoTema(v.first),
                  ),
                ),
                _paleta(context),
                _interruptor(
                  context,
                  icono: Icons.auto_awesome_rounded,
                  titulo: 'Color según la carátula',
                  subtitulo: 'La app toma el color de la canción que suena',
                  valor: motor.usarDinamico.value,
                  alCambiar: motor.setUsarDinamico,
                ),
                _interruptor(
                  context,
                  icono: Icons.dark_mode_rounded,
                  titulo: 'Negro puro (AMOLED)',
                  subtitulo: 'Fondo totalmente negro; ahorra batería en pantallas OLED',
                  valor: motor.amoled.value,
                  alCambiar: motor.setAmoled,
                ),
              ]),

              // ---------------- Reproducción ----------------
              _grupo(context, 'Reproducción', Icons.play_circle_rounded, [
                _fila(
                  context,
                  icono: Icons.equalizer_rounded,
                  titulo: 'Ecualizador',
                  subtitulo: 'Graves, agudos y presets',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PantallaEcualizador(motor: motor)),
                  ),
                ),
                _fila(
                  context,
                  icono: Icons.bedtime_rounded,
                  titulo: 'Temporizador de sueño',
                  subtitulo: motor.suenoFin.value == null
                      ? 'Apagado'
                      : 'Se detendrá a las ${TimeOfDay.fromDateTime(motor.suenoFin.value!).format(context)}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => abrirTemporizador(context, motor),
                ),
                _interruptor(
                  context,
                  icono: Icons.fast_forward_rounded,
                  titulo: 'Saltar silencios',
                  subtitulo: 'Se saltan las pausas largas dentro de las canciones',
                  valor: motor.saltarSilencio,
                  alCambiar: motor.setSaltarSilencio,
                ),
                _crossfade(context),
                _visualizador(context),
              ]),

              // ---------------- Notificación y pantalla de bloqueo ----------------
              _grupo(context, 'Notificación y pantalla de bloqueo',
                  Icons.notifications_active_rounded, [
                _interruptor(
                  context,
                  icono: Icons.push_pin_rounded,
                  titulo: 'Notificación fija',
                  subtitulo: 'No se puede quitar mientras suena la música',
                  valor: motor.notifFija && !motor.notifMantener,
                  alCambiar: motor.notifMantener ? null : motor.setNotifFija,
                ),
                _interruptor(
                  context,
                  icono: Icons.pause_circle_outline_rounded,
                  titulo: 'Mantener al pausar',
                  subtitulo: 'La notificación y los controles siguen visibles aunque pauses',
                  valor: motor.notifMantener,
                  alCambiar: motor.setNotifMantener,
                ),
                _interruptor(
                  context,
                  icono: Icons.color_lens_rounded,
                  titulo: 'Usar mi color en la notificación',
                  subtitulo: 'Tiñe la notificación con tu color de acento',
                  valor: motor.notifUsarColor,
                  alCambiar: motor.setNotifUsarColor,
                ),
                _fila(
                  context,
                  icono: Icons.settings_applications_rounded,
                  titulo: 'Ajustes de Android',
                  subtitulo:
                      'Pantalla de bloqueo, sonido y prioridad de las notificaciones de esta app',
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  alTocar: openAppSettings,
                ),
                _nota(
                  'Los cambios de notificación se aplican al volver a abrir la app. '
                  'Para mostrar u ocultar los controles en la pantalla de bloqueo, '
                  'entra en Ajustes de Android → Notificaciones.',
                ),
              ]),

              // ---------------- Biblioteca ----------------
              _grupo(context, 'Biblioteca', Icons.library_music_rounded, [
                _fila(
                  context,
                  icono: Icons.filter_alt_rounded,
                  titulo: 'Filtros de biblioteca',
                  subtitulo: motor.modoManual
                      ? 'Modo manual: ${motor.elegidas.length} canciones elegidas'
                      : '${motor.carpetasBloqueadas.length} carpetas bloqueadas'
                          '${motor.bloquearRuido ? ' · WhatsApp y grabaciones ocultos' : ''}',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PantallaFiltros(motor: motor)),
                  ),
                ),
                _fila(
                  context,
                  icono: Icons.refresh_rounded,
                  titulo: 'Actualizar biblioteca',
                  subtitulo: '${motor.canciones.length} canciones encontradas',
                  alTocar: motor.cargarCanciones,
                ),
                _fila(
                  context,
                  icono: Icons.timer_outlined,
                  titulo: 'Audios cortos',
                  subtitulo: motor.duracionMinimaMs == 0
                      ? 'Se muestran todos'
                      : 'Se ocultan los de menos de ${motor.duracionMinimaMs ~/ 1000} s',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => _duracionMinima(context),
                ),
                _fila(
                  context,
                  icono: Icons.visibility_off_outlined,
                  titulo: 'Canciones ocultas',
                  subtitulo: '${motor.ocultas.length} ocultas',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PantallaOcultas(motor: motor)),
                  ),
                ),
              ]),

              // ---------------- Tu actividad ----------------
              _grupo(context, 'Tu actividad', Icons.insights_rounded, [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _dato(context, '${motor.canciones.length}', 'canciones'),
                      _dato(context, '${motor.favoritos.length}', 'favoritas'),
                      _dato(context, '${motor.listas.length}', 'listas'),
                      _dato(context, '${motor.reproduccionesTotales}', 'reproducciones'),
                    ],
                  ),
                ),
                _fila(
                  context,
                  icono: Icons.bar_chart_rounded,
                  titulo: 'Ver tu resumen completo',
                  subtitulo: 'Tus canciones, artistas y álbumes más escuchados',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PantallaEstadisticas(motor: motor)),
                  ),
                ),
              ]),

              // ---------------- Acerca de ----------------
              _grupo(context, 'Acerca de', Icons.info_rounded, [
                _fila(
                  context,
                  icono: Icons.music_note_rounded,
                  titulo: kNombreApp,
                  subtitulo: 'Reproductor de música local · versión $kVersionApp',
                ),
                _fila(
                  context,
                  icono: Icons.code_rounded,
                  titulo: 'Desarrollado por $kAutor',
                  subtitulo: 'Hecho con cariño en Guadalajara, México',
                ),
                _fila(
                  context,
                  icono: Icons.bug_report_outlined,
                  titulo: 'Registro de errores',
                  subtitulo: 'Para averiguar por qué falló algo',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const PantallaRegistroErrores())),
                ),
                _fila(
                  context,
                  icono: Icons.waving_hand_rounded,
                  titulo: 'Ver guía de bienvenida',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PantallaBienvenida(motor: motor, repaso: true))),
                ),
                _fila(
                  context,
                  icono: Icons.description_outlined,
                  titulo: 'Licencias de código abierto',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  alTocar: () => showLicensePage(
                    context: context,
                    applicationName: kNombreApp,
                    applicationVersion: kVersionApp,
                    applicationLegalese: 'Desarrollado por $kAutor',
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // Piezas de diseño
  // ------------------------------------------------------------------------

  /// Tarjeta con título e icono que agrupa varios ajustes.
  Widget _grupo(BuildContext context, String titulo, IconData icono, List<Widget> hijos) {
    final filas = <Widget>[];
    for (var i = 0; i < hijos.length; i++) {
      if (i > 0) {
        filas.add(Divider(height: 1, indent: 66, endIndent: 16, color: tLinea));
      }
      filas.add(hijos[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Row(
              children: [
                Icon(icono, size: 16, color: context.acento),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.bold,
                      color: tSuave,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: context.panelElevado,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(children: filas),
          ),
        ],
      ),
    );
  }

  Widget _cajaIcono(BuildContext context, IconData icono) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.acento.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icono, size: 20, color: context.acento),
      );

  Widget _fila(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    String? subtitulo,
    Widget? trailing,
    VoidCallback? alTocar,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: _cajaIcono(context, icono),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitulo == null
          ? null
          : Text(subtitulo, style: TextStyle(color: tSuave, fontSize: 12.5)),
      trailing: trailing,
      onTap: alTocar,
    );
  }

  Widget _interruptor(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool>? alCambiar,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      secondary: _cajaIcono(context, icono),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitulo, style: TextStyle(color: tSuave, fontSize: 12.5)),
      value: valor,
      activeThumbColor: context.acento,
      onChanged: alCambiar,
    );
  }

  Widget _nota(String texto) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Text(texto, style: TextStyle(color: tTenue, fontSize: 12)),
      );

  Widget _paleta(BuildContext context) {
    final actual = motor.acentoBase.value.toARGB32();
    Widget punto(Color color, {bool propio = false}) {
      final seleccionado = color.toARGB32() == actual;
      return GestureDetector(
        onTap: () => motor.setAcentoBase(color),
        onLongPress: propio ? () => motor.quitarColorPropio(color) : null,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: seleccionado ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: seleccionado ? const Icon(Icons.check_rounded, color: Colors.white) : null,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Color de acento', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'Elige uno de la paleta o crea el tuyo con el botón +',
            style: TextStyle(color: tSuave, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in MotorMusica.coloresDisponibles) punto(c),
              for (final c in motor.coloresPropios) punto(c, propio: true),
              GestureDetector(
                onTap: () => _elegirColor(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(colors: [
                      Color(0xFFFF4D4D),
                      Color(0xFFFFD24D),
                      Color(0xFF4DFF88),
                      Color(0xFF4DD2FF),
                      Color(0xFF9B5CFF),
                      Color(0xFFFF4D4D),
                    ]),
                    border: Border.all(color: tBorde, width: 2),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          if (motor.coloresPropios.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Mantén presionado uno de tus colores para borrarlo.',
                style: TextStyle(color: tTenue, fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _crossfade(BuildContext context) {
    final seg = motor.fundidoSeg.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _cajaIcono(context, Icons.compare_arrows_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Crossfade entre canciones',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      seg == 0
                          ? 'Apagado'
                          : 'La siguiente empieza $seg s antes de que termine la actual',
                      style: TextStyle(color: tSuave, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 12,
            divisions: 12,
            value: seg.toDouble(),
            label: seg == 0 ? 'Apagado' : '$seg s',
            onChanged: (v) => motor.setFundido(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _visualizador(BuildContext context) {
    final estilo = motor.visualizador.value.clamp(1, 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _cajaIcono(context, Icons.graphic_eq_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Visualizador de espectro',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'En el reproductor, toca la carátula para verlo',
                      style: TextStyle(color: tSuave, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 1, label: Text('Barras')),
                ButtonSegment(value: 2, label: Text('Ondas')),
                ButtonSegment(value: 3, label: Text('Espejo')),
              ],
              selected: {estilo},
              onSelectionChanged: (s) => motor.setVisualizador(s.first),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dato(BuildContext context, String valor, String etiqueta) => Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.acento,
            ),
          ),
          const SizedBox(height: 2),
          Text(etiqueta, style: TextStyle(color: tSuave, fontSize: 11)),
        ],
      );
}

// ---------------------------------------------------------------------------
// Canciones ocultas
// ---------------------------------------------------------------------------

class PantallaOcultas extends StatelessWidget {
  final MotorMusica motor;

  const PantallaOcultas({super.key, required this.motor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canciones ocultas')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          final lista = motor.cancionesOcultas;
          if (lista.isEmpty) {
            return Center(
              child: Text('No tienes canciones ocultas.',
                  style: TextStyle(color: tSuave)),
            );
          }
          return ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final c = lista[i];
              return ListTile(
                leading: caratula(c, 48, context.acento),
                title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(artistaDe(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: TextButton(
                  onPressed: () => motor.mostrarCancion(c.id),
                  child: const Text('Mostrar'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
