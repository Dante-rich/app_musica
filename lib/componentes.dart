import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';

import 'editor_etiquetas.dart';
import 'motor.dart';
import 'pantalla_reproductor.dart';
import 'utilidades.dart';

// ---------------------------------------------------------------------------
// Fila de canción (lista vertical)
// ---------------------------------------------------------------------------

/// Reproduce la canción y abre el reproductor grande.
/// Si ya es la que suena, solo abre el reproductor sin reiniciarla.
Future<void> compartirCancion(SongModel c) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(c.data)],
        text: '${c.title} — ${artistaDe(c)}',
      ),
    );
  } catch (_) {}
}

void tocarCancion(
  BuildContext context,
  MotorMusica motor,
  List<SongModel> contexto,
  SongModel cancion,
) {
  if (motor.cancionActual.value?.id != cancion.id) {
    motor.reproducir(contexto, cancion);
  }
  abrirReproductor(context, motor);
}

class FilaCancion extends StatelessWidget {
  final MotorMusica motor;
  final SongModel cancion;
  final List<SongModel> contexto;
  final bool seleccionada;
  final bool modoSeleccion;
  final VoidCallback? alAlternarSeleccion;
  final VoidCallback? alMantener;
  final String? listaActual;

  const FilaCancion({
    super.key,
    required this.motor,
    required this.cancion,
    required this.contexto,
    this.seleccionada = false,
    this.modoSeleccion = false,
    this.alAlternarSeleccion,
    this.alMantener,
    this.listaActual,
  });

  @override
  Widget build(BuildContext contextoBuild) {
    final acento = contextoBuild.acento;
    return ValueListenableBuilder<SongModel?>(
      valueListenable: motor.cancionActual,
      builder: (context, actual, _) {
        final esActual = actual?.id == cancion.id;
        final esFavorito = motor.favoritos.contains(cancion.id);

        return ListTile(
          selected: seleccionada,
          selectedTileColor: acento.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              caratula(cancion, 52, acento),
              if (seleccionada)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: acento.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white),
                ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  cancion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: esActual ? FontWeight.bold : FontWeight.w500,
                    color: esActual ? acento : tTexto,
                  ),
                ),
              ),
              if (esFavorito)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.favorite_rounded, size: 14, color: acento),
                ),
            ],
          ),
          subtitle: Text(
            '${artistaDe(cancion)} • ${albumDe(cancion)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: modoSeleccion
              ? alAlternarSeleccion
              : () => tocarCancion(context, motor, contexto, cancion),
          onLongPress: alMantener,
          trailing: modoSeleccion ? null : _menu(context, esActual, esFavorito, acento),
        );
      },
    );
  }

  Widget _menu(BuildContext context, bool esActual, bool esFavorito, Color acento) {
    return PopupMenuButton<String>(
      icon: esActual
          ? StreamBuilder<bool>(
              stream: motor.reproductor.playingStream,
              initialData: motor.reproductor.playing,
              builder: (context, snap) =>
                  BarrasAnimadas(color: acento, activo: snap.data ?? false),
            )
          : Icon(Icons.more_vert_rounded, color: tSuave),
      onSelected: (opcion) {
        switch (opcion) {
          case 'reproducir':
            motor.reproducir(contexto, cancion);
            break;
          case 'despues':
            motor.tocarDespues([cancion]);
            break;
          case 'cola':
            motor.agregarALaCola([cancion]);
            break;
          case 'favorito':
            motor.alternarFavorito(cancion.id);
            break;
          case 'lista':
            mostrarAgregarALista(context, motor, [cancion]);
            break;
          case 'quitar':
            if (listaActual != null) motor.quitarDeLista(listaActual!, cancion.id);
            break;
          case 'info':
            mostrarInfoCancion(context, cancion);
            break;
          case 'editar':
            mostrarEditorEtiquetas(context, motor, cancion);
            break;
          case 'compartir':
            compartirCancion(cancion);
            break;
          case 'ocultar':
            motor.ocultarCancion(cancion.id);
            motor.aviso('Canción oculta. Puedes mostrarla en Ajustes.');
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'reproducir',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.play_arrow_rounded),
            title: Text('Reproducir'),
          ),
        ),
        const PopupMenuItem(
          value: 'despues',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.playlist_play_rounded),
            title: Text('Reproducir a continuación'),
          ),
        ),
        const PopupMenuItem(
          value: 'cola',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.queue_rounded),
            title: Text('Agregar a la cola'),
          ),
        ),
        PopupMenuItem(
          value: 'favorito',
          child: ListTile(
            dense: true,
            leading: Icon(esFavorito ? Icons.favorite : Icons.favorite_border),
            title: Text(esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos'),
          ),
        ),
        const PopupMenuItem(
          value: 'lista',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.playlist_add_rounded),
            title: Text('Agregar a una lista'),
          ),
        ),
        if (listaActual != null)
          const PopupMenuItem(
            value: 'quitar',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline_rounded),
              title: Text('Quitar de esta lista'),
            ),
          ),
        const PopupMenuItem(
          value: 'compartir',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.share_outlined),
            title: Text('Compartir'),
          ),
        ),
        const PopupMenuItem(
          value: 'editar',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar etiquetas y carátula'),
          ),
        ),
        const PopupMenuItem(
          value: 'info',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Información'),
          ),
        ),
        const PopupMenuItem(
          value: 'ocultar',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.visibility_off_outlined),
            title: Text('Ocultar de la biblioteca'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de canción (filas horizontales de Inicio)
// ---------------------------------------------------------------------------

class TarjetaCancion extends StatelessWidget {
  final MotorMusica motor;
  final SongModel cancion;
  final List<SongModel> contexto;
  final double ancho;

  const TarjetaCancion({
    super.key,
    required this.motor,
    required this.cancion,
    required this.contexto,
    this.ancho = 140,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => tocarCancion(context, motor, contexto, cancion),
        child: SizedBox(
          width: ancho,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              caratula(cancion, ancho, context.acento, radio: 16, size: 400),
              const SizedBox(height: 8),
              Text(
                cancion.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                artistaDe(cancion),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tSuave, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de álbum (cuadrícula)
// ---------------------------------------------------------------------------

class TarjetaAlbum extends StatelessWidget {
  final SongModel portada;
  final String titulo;
  final String subtitulo;
  final VoidCallback alTocar;

  const TarjetaAlbum({
    super.key,
    required this.portada,
    required this.titulo,
    required this.subtitulo,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: alTocar,
      child: LayoutBuilder(
        builder: (context, c) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              caratula(portada, c.maxWidth, context.acento, radio: 16, size: 400),
              const SizedBox(height: 8),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tSuave, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agregar canciones a una lista
// ---------------------------------------------------------------------------

const String _marcaNuevaLista = '__nueva_lista__';

Future<void> mostrarAgregarALista(
  BuildContext context,
  MotorMusica motor,
  List<SongModel> canciones,
) async {
  if (canciones.isEmpty) return;

  final elegido = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Agregar a una lista',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.add_rounded, color: ctx.acento),
              title: const Text('Nueva lista'),
              onTap: () => Navigator.pop(ctx, _marcaNuevaLista),
            ),
            ...motor.listas.keys.map(
              (nombre) => ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(nombre),
                subtitle: Text('${motor.listas[nombre]!.length} canciones'),
                onTap: () => Navigator.pop(ctx, nombre),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (elegido == null) return;

  var destino = elegido;
  if (elegido == _marcaNuevaLista) {
    if (!context.mounted) return;
    final nombre = await pedirTexto(
      context,
      titulo: 'Nueva lista de reproducción',
      etiqueta: 'Nombre de la lista',
      hint: 'Por ejemplo: Para entrenar',
      textoBoton: 'Crear',
    );
    if (nombre == null || nombre.isEmpty) return;
    if (!motor.crearLista(nombre)) {
      motor.aviso('Ya existe una lista con ese nombre.');
      return;
    }
    destino = nombre;
  }

  final agregadas = motor.agregarALista(destino, canciones.map((s) => s.id));
  if (agregadas == 0) {
    motor.aviso(canciones.length == 1
        ? 'Esta canción ya está en "$destino".'
        : 'Esas canciones ya estaban en "$destino".');
  } else {
    motor.aviso(agregadas == 1
        ? 'Agregada a "$destino".'
        : '$agregadas canciones agregadas a "$destino".');
  }
}

// ---------------------------------------------------------------------------
// Información de la canción
// ---------------------------------------------------------------------------

Future<void> mostrarInfoCancion(BuildContext context, SongModel c) {
  Widget fila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 82,
              child: Text(k, style: TextStyle(color: tSuave)),
            ),
            Expanded(child: Text(v)),
          ],
        ),
      );

  final genero = c.genre;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Información'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            fila('Título', c.title),
            fila('Artista', artistaDe(c)),
            fila('Álbum', albumDe(c)),
            if (genero != null && genero.isNotEmpty && genero != '<unknown>')
              fila('Género', genero),
            fila('Duración', formatoTiempo(Duration(milliseconds: c.duration ?? 0))),
            fila('Formato', c.fileExtension.toUpperCase()),
            fila('Tamaño', formatoTamano(c.size)),
            fila('Ruta', c.data),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Temporizador de sueño
// ---------------------------------------------------------------------------

Future<void> abrirTemporizador(BuildContext context, MotorMusica motor) async {
  final minutos = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Temporizador de sueño',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final m in [15, 30, 45, 60, 90])
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: Text('$m minutos'),
                onTap: () => Navigator.pop(ctx, m),
              ),
            ListTile(
              leading: const Icon(Icons.music_note_rounded),
              title: const Text('Al terminar la canción'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            if (motor.suenoFin.value != null)
              ListTile(
                leading: const Icon(Icons.timer_off_rounded),
                title: const Text('Cancelar temporizador'),
                onTap: () => Navigator.pop(ctx, 0),
              ),
          ],
        ),
      ),
    ),
  );

  if (minutos == null) return;
  if (minutos == 0) {
    motor.cancelarSueno();
    motor.aviso('Temporizador cancelado.');
  } else if (minutos == -1) {
    if (motor.programarSuenoFinDeCancion()) {
      motor.aviso('La música se detendrá al terminar esta canción.');
    } else {
      motor.aviso('Primero reproduce una canción.');
    }
  } else {
    motor.programarSueno(Duration(minutes: minutos));
    motor.aviso('La música se detendrá en $minutos minutos.');
  }
}

// ---------------------------------------------------------------------------
// Mini reproductor
// ---------------------------------------------------------------------------

class MiniReproductor extends StatelessWidget {
  final MotorMusica motor;
  final VoidCallback alAbrir;

  const MiniReproductor({super.key, required this.motor, required this.alAbrir});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SongModel?>(
      valueListenable: motor.cancionActual,
      builder: (context, cancion, _) {
        if (cancion == null) return const SizedBox.shrink();
        final acento = context.acento;

        return GestureDetector(
          // Desliza a los lados para cambiar de canción.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -300) {
              motor.siguiente();
            } else if (v > 300) {
              motor.anterior();
            }
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: alAbrir,
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 0),
              decoration: BoxDecoration(
                color: context.panelElevado,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: acento.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      caratula(cancion, 46, acento),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cancion.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              artistaDe(cancion),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tSuave, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: motor.reproductor.playerStateStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return IconButton(
                            onPressed: () => alternarPlayPausa(motor.reproductor),
                            icon: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 30,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: motor.siguiente,
                        icon: const Icon(Icons.skip_next_rounded, size: 29),
                      ),
                    ],
                  ),
                  BarraProgreso(reproductor: motor.reproductor, compacta: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
