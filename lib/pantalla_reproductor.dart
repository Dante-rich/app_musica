import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'componentes.dart';
import 'editor_etiquetas.dart';
import 'visualizador.dart';
import 'motor.dart';
import 'pantalla_ecualizador.dart';
import 'utilidades.dart';

void abrirReproductor(BuildContext context, MotorMusica motor) {
  if (motor.cancionActual.value == null) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => PantallaReproductor(motor: motor),
      transitionsBuilder: (_, animation, __, child) {
        final desplazamiento = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(desplazamiento), child: child);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Reproductor completo
// ---------------------------------------------------------------------------

double _dobleToqueX = 0;

class PantallaReproductor extends StatelessWidget {
  final MotorMusica motor;

  const PantallaReproductor({super.key, required this.motor});

  AudioPlayer get rep => motor.reproductor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: motor.cancionActual,
      builder: (context, cancion, _) {
        if (cancion == null) return const Scaffold();
        final acento = context.acento;
        final fondoColor = Color.alphaBlend(acento.withValues(alpha: 0.30), context.fondoApp);

        return Stack(
          fit: StackFit.expand,
          children: [
            _fondoDesenfocado(context, cancion),
            Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fondoColor.withValues(alpha: 0.55),
                context.fondoApp.withValues(alpha: 0.93),
              ],
              stops: const [0.0, 0.75],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
              ),
              title: const Text(
                'REPRODUCIENDO',
                style: TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final lado = min(
                    min(c.maxWidth - 48, 350.0),
                    max(160.0, c.maxHeight * 0.40),
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Desliza la carátula: izquierda/derecha cambia de canción,
                        // hacia abajo cierra el reproductor.
                        GestureDetector(
                          onTap: motor.alternarEspectro,
                          onDoubleTapDown: (d) => _dobleToqueX = d.localPosition.dx,
                          onDoubleTap: () {
                            final adelante = _dobleToqueX > lado / 2;
                            motor.saltar(adelante ? 10 : -10);
                            motor.aviso(adelante ? '+10 s' : '−10 s');
                          },
                          onLongPress: () => mostrarEditorEtiquetas(context, motor, cancion),
                          onHorizontalDragEnd: (d) {
                            final v = d.primaryVelocity ?? 0;
                            if (v < -250) {
                              motor.siguiente();
                            } else if (v > 250) {
                              motor.anterior();
                            }
                          },
                          onVerticalDragEnd: (d) {
                            if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
                          },
                          child: ValueListenableBuilder<bool>(
                            valueListenable: motor.verEspectro,
                            builder: (context, ver, _) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: ver
                                ? VisualizadorEspectro(
                                    key: const ValueKey('espectro'),
                                    motor: motor,
                                    lado: lado,
                                    fondo: Opacity(
                                      opacity: 0.35,
                                      child: caratula(cancion, lado, acento,
                                          radio: 25, size: 800, quality: 100),
                                    ),
                                  )
                                : Container(
                              key: ValueKey(cancion.id),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: acento.withValues(alpha: 0.25),
                                    blurRadius: 40,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: caratula(cancion, lado, acento,
                                  radio: 25, size: 800, quality: 100),
                            ),
                          ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _titulo(context, cancion),
                        const SizedBox(height: 14),
                        BarraProgreso(reproductor: rep),
                        const SizedBox(height: 10),
                        _controles(context),
                        const SizedBox(height: 16),
                        _extras(context),
                        const SizedBox(height: 16),
                        _siguiente(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
            ),
          ],
        );
      },
    );
  }

  /// Carátula muy desenfocada como fondo de toda la pantalla.
  Widget _fondoDesenfocado(BuildContext context, SongModel cancion) {
    final tam = MediaQuery.of(context).size;
    final propia = caratulasPropias[cancion.id];
    return SizedBox.expand(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: propia != null
            ? Image.file(File(propia), fit: BoxFit.cover, cacheWidth: 200)
            : QueryArtworkWidget(
                id: cancion.id,
                type: ArtworkType.AUDIO,
                artworkWidth: tam.width,
                artworkHeight: tam.height,
                artworkFit: BoxFit.cover,
                size: 200,
                nullArtworkWidget: Container(color: context.panel),
              ),
      ),
    );
  }

  Widget _titulo(BuildContext context, SongModel cancion) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cancion.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                artistaDe(cancion),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tSuave, fontSize: 15),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<Set<int>>(
          valueListenable: motor.favoritosVN,
          builder: (context, favoritos, _) {
            final esFavorito = favoritos.contains(cancion.id);
            return IconButton(
              onPressed: () => motor.alternarFavorito(cancion.id),
              icon: Icon(
                esFavorito ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: esFavorito ? context.acento : tSuave,
                size: 28,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _controles(BuildContext context) {
    final acento = context.acento;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StreamBuilder<bool>(
          stream: rep.shuffleModeEnabledStream,
          initialData: rep.shuffleModeEnabled,
          builder: (context, snap) => IconButton(
            onPressed: motor.alternarAleatorio,
            icon: Icon(
              Icons.shuffle_rounded,
              color: (snap.data ?? false) ? acento : tSuave,
              size: 25,
            ),
          ),
        ),
        IconButton(
          onPressed: motor.anterior,
          icon: const Icon(Icons.skip_previous_rounded, size: 38),
        ),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: acento,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: acento.withValues(alpha: 0.3), blurRadius: 20)],
          ),
          child: StreamBuilder<PlayerState>(
            stream: rep.playerStateStream,
            builder: (context, snap) {
              final estado = snap.data;
              final playing = estado?.playing ?? false;
              final cargando = estado?.processingState == ProcessingState.loading ||
                  estado?.processingState == ProcessingState.buffering;
              final sobre = Theme.of(context).colorScheme.onPrimary;
              if (cargando) {
                return Padding(
                  padding: const EdgeInsets.all(22),
                  child: CircularProgressIndicator(strokeWidth: 2, color: sobre),
                );
              }
              return IconButton(
                onPressed: () => alternarPlayPausa(rep),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: sobre,
                  size: 42,
                ),
              );
            },
          ),
        ),
        IconButton(
          onPressed: motor.siguiente,
          icon: const Icon(Icons.skip_next_rounded, size: 38),
        ),
        StreamBuilder<LoopMode>(
          stream: rep.loopModeStream,
          initialData: rep.loopMode,
          builder: (context, snap) {
            final modo = snap.data ?? LoopMode.off;
            return IconButton(
              onPressed: motor.alternarRepeticion,
              icon: Icon(
                modo == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                color: modo == LoopMode.off ? tSuave : acento,
                size: 25,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _extras(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StreamBuilder<double>(
          stream: rep.speedStream,
          initialData: rep.speed,
          builder: (context, snap) {
            final velocidad = snap.data ?? 1.0;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _verVelocidadTono(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: context.panelElevado,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed_rounded, size: 18, color: context.acento),
                    const SizedBox(width: 6),
                    Text('${velocidad.toStringAsFixed(2)}x'),
                  ],
                ),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Letra',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PantallaLetra(motor: motor)),
          ),
          icon: const Icon(Icons.lyrics_outlined),
        ),
        IconButton(
          tooltip: 'Temporizador de sueño',
          onPressed: () => abrirTemporizador(context, motor),
          icon: const Icon(Icons.bedtime_outlined),
        ),
        IconButton(
          tooltip: 'Ecualizador',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PantallaEcualizador(motor: motor)),
          ),
          icon: const Icon(Icons.equalizer_rounded),
        ),
        IconButton(
          tooltip: 'Cola de reproducción',
          onPressed: () => _verCola(context),
          icon: const Icon(Icons.queue_music_rounded),
        ),
      ],
    );
  }

  /// Muestra qué canción viene después (cuando el modo aleatorio está apagado).
  Widget _siguiente(BuildContext context) {
    return StreamBuilder<bool>(
      stream: rep.shuffleModeEnabledStream,
      initialData: rep.shuffleModeEnabled,
      builder: (context, snapAleatorio) {
        if (snapAleatorio.data ?? false) return const SizedBox.shrink();
        return ValueListenableBuilder<List<SongModel>>(
          valueListenable: motor.cola,
          builder: (context, cola, _) {
            return StreamBuilder<int?>(
              stream: rep.currentIndexStream,
              initialData: rep.currentIndex,
              builder: (context, snap) {
                final i = snap.data;
                if (i == null || i + 1 >= cola.length) return const SizedBox.shrink();
                final prox = cola[i + 1];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.panelElevado,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      caratula(prox, 44, context.acento),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('A continuación',
                                style: TextStyle(color: tSuave, fontSize: 11)),
                            Text(prox.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(artistaDe(prox),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: tSuave, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: motor.siguiente,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _verVelocidadTono(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Velocidad y tono',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _ControlDeslizante(
                titulo: 'Velocidad',
                flujo: rep.speedStream,
                inicial: rep.speed,
                minimo: 0.5,
                maximo: 2.0,
                divisiones: 30,
                alCambiar: (v) => rep.setSpeed(v),
              ),
              _ControlDeslizante(
                titulo: 'Tono',
                flujo: rep.pitchStream,
                inicial: rep.pitch,
                minimo: 0.5,
                maximo: 1.5,
                divisiones: 20,
                alCambiar: (v) => rep.setPitch(v),
              ),
              TextButton.icon(
                onPressed: () {
                  rep.setSpeed(1.0);
                  rep.setPitch(1.0);
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Restablecer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verCola(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HojaCola(motor: motor),
    );
  }
}

// ---------------------------------------------------------------------------
// Cola de reproducción (arrastra para reordenar)
// ---------------------------------------------------------------------------

class _ControlDeslizante extends StatelessWidget {
  final String titulo;
  final Stream<double> flujo;
  final double inicial;
  final double minimo;
  final double maximo;
  final int divisiones;
  final void Function(double) alCambiar;

  const _ControlDeslizante({
    required this.titulo,
    required this.flujo,
    required this.inicial,
    required this.minimo,
    required this.maximo,
    required this.divisiones,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: flujo,
      initialData: inicial,
      builder: (context, snap) {
        final v = (snap.data ?? 1.0).clamp(minimo, maximo).toDouble();
        return Row(
          children: [
            SizedBox(width: 80, child: Text(titulo)),
            Expanded(
              child: Slider(
                min: minimo,
                max: maximo,
                divisions: divisiones,
                value: v,
                onChanged: alCambiar,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${v.toStringAsFixed(2)}x',
                textAlign: TextAlign.end,
                style: TextStyle(color: tSuave),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HojaCola extends StatefulWidget {
  final MotorMusica motor;

  const _HojaCola({required this.motor});

  @override
  State<_HojaCola> createState() => _HojaColaState();
}

class _HojaColaState extends State<_HojaCola> {
  static const double altoFila = 64;
  late final ScrollController _c = ScrollController(
    initialScrollOffset: max(0, (widget.motor.reproductor.currentIndex ?? 0) - 2) * altoFila,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _guardarComoLista() async {
    final motor = widget.motor;
    final nombre = await pedirTexto(
      context,
      titulo: 'Guardar cola como lista',
      etiqueta: 'Nombre de la lista',
      textoBoton: 'Guardar',
    );
    if (!mounted || nombre == null || nombre.isEmpty) return;
    if (motor.guardarColaComoLista(nombre)) {
      motor.aviso('Lista "$nombre" creada con ${motor.cola.value.length} canciones.');
    } else {
      motor.aviso('Ya existe una lista con ese nombre.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final motor = widget.motor;
    final acento = context.acento;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Cola de reproducción',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ValueListenableBuilder<List<SongModel>>(
                  valueListenable: motor.cola,
                  builder: (context, cola, _) => Text('${cola.length}',
                      style: TextStyle(color: tSuave)),
                ),
                IconButton(
                  tooltip: 'Guardar como lista',
                  onPressed: _guardarComoLista,
                  icon: const Icon(Icons.playlist_add_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<SongModel>>(
              valueListenable: motor.cola,
              builder: (context, cola, _) {
                return StreamBuilder<int?>(
                  stream: motor.reproductor.currentIndexStream,
                  initialData: motor.reproductor.currentIndex,
                  builder: (context, snap) {
                    final actual = snap.data;
                    return ReorderableListView.builder(
                      scrollController: _c,
                      buildDefaultDragHandles: false,
                      itemCount: cola.length,
                      onReorder: (viejo, nuevo) {
                        if (nuevo > viejo) nuevo -= 1;
                        motor.moverEnCola(viejo, nuevo);
                      },
                      itemBuilder: (context, i) {
                        final c = cola[i];
                        final esActual = i == actual;
                        return ListTile(
                          key: ValueKey('cola_${i}_${c.id}'),
                          dense: true,
                          leading: caratula(c, 44, acento),
                          title: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
                              color: esActual ? acento : tTexto,
                            ),
                          ),
                          subtitle: Text(artistaDe(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => motor.saltarACola(i),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (esActual)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.equalizer_rounded, color: acento, size: 20),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Quitar de la cola',
                                onPressed: () => motor.quitarDeCola(i),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.drag_handle_rounded, color: tSuave),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Letra (sincronizada si tiene marcas de tiempo [mm:ss.xx])
// ---------------------------------------------------------------------------

class PantallaLetra extends StatefulWidget {
  final MotorMusica motor;

  const PantallaLetra({super.key, required this.motor});

  @override
  State<PantallaLetra> createState() => _PantallaLetraState();
}

class _PantallaLetraState extends State<PantallaLetra> {
  int? _id;
  String? _texto;
  bool _cargando = true;
  List<LineaLetra>? _lrc;
  List<GlobalKey> _llaves = [];
  int _lineaActual = -1;

  MotorMusica get motor => widget.motor;

  @override
  void initState() {
    super.initState();
    motor.cancionActual.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    motor.cancionActual.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar({bool forzar = false}) async {
    final c = motor.cancionActual.value;
    if (c == null) return;
    if (!forzar && c.id == _id) return;
    _id = c.id;
    if (mounted) setState(() => _cargando = true);

    final texto = await motor.letraDe(c);
    if (!mounted || motor.cancionActual.value?.id != c.id) return;

    List<LineaLetra>? lrc;
    if (texto != null) {
      final lineas = parsearLrc(texto);
      if (lineas.isNotEmpty) lrc = lineas;
    }
    setState(() {
      _texto = texto;
      _lrc = lrc;
      _llaves = List<GlobalKey>.generate(lrc?.length ?? 0, (_) => GlobalKey());
      _lineaActual = -1;
      _cargando = false;
    });
  }

  Future<void> _editar() async {
    final c = motor.cancionActual.value;
    if (c == null) return;
    final texto = await pedirTexto(
      context,
      titulo: 'Letra de la canción',
      hint: 'Pega aquí la letra. Si tiene marcas como [01:23.45] se sincronizará.',
      inicial: _texto ?? '',
      maxLineas: 12,
      textoBoton: 'Guardar',
    );
    if (!mounted || texto == null) return;
    motor.guardarLetra(c.id, texto);
    await _cargar(forzar: true);
  }

  @override
  Widget build(BuildContext context) {
    final cancion = motor.cancionActual.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          cancion?.title ?? 'Letra',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Editar letra',
            onPressed: _editar,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) {
      return Center(child: CircularProgressIndicator(color: context.acento));
    }
    if (_texto == null || _texto!.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_outlined, size: 64, color: context.acento),
              const SizedBox(height: 16),
              const Text(
                'No hay letra para esta canción.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes pegarla tú mismo, o poner un archivo .lrc con el mismo nombre junto a la canción.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tSuave),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _editar,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar letra'),
              ),
            ],
          ),
        ),
      );
    }

    final lrc = _lrc;
    if (lrc == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(_texto!, style: const TextStyle(fontSize: 18, height: 1.7)),
      );
    }

    return StreamBuilder<Duration>(
      stream: motor.reproductor.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        var activa = -1;
        for (var i = 0; i < lrc.length; i++) {
          if (lrc[i].tiempo <= pos) {
            activa = i;
          } else {
            break;
          }
        }

        if (activa != _lineaActual && activa >= 0) {
          _lineaActual = activa;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _llaves[activa].currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(
                ctx,
                alignment: 0.35,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
            }
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 120),
              for (var i = 0; i < lrc.length; i++)
                GestureDetector(
                  key: _llaves[i],
                  onTap: () => motor.reproductor.seek(lrc[i].tiempo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: i == activa ? 24 : 19,
                        fontWeight: i == activa ? FontWeight.bold : FontWeight.w500,
                        color: i == activa ? context.acento : tTenue,
                        height: 1.35,
                      ),
                      child: Text(lrc[i].texto.isEmpty ? '♪' : lrc[i].texto),
                    ),
                  ),
                ),
              const SizedBox(height: 240),
            ],
          ),
        );
      },
    );
  }
}
