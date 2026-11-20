import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Nombre y versión que se muestran en la app (mantén la versión igual a la de pubspec.yaml).
const String kNombreApp = 'SoundThread';
const String kVersionApp = '1.0.1';
const String kAutor = 'Lemus. C';

// ---------------------------------------------------------------------------
// Colores del tema (se leen desde el tema actual, así cambian solos)
// ---------------------------------------------------------------------------

/// true cuando la app está en tema claro (lo actualiza main.dart).
bool modoClaroActivo = false;
Color get tSuave => modoClaroActivo ? const Color(0x99000000) : Colors.white60;
Color get tTenue => modoClaroActivo ? const Color(0x61000000) : Colors.white38;
Color get tBorde => modoClaroActivo ? const Color(0x3D000000) : Colors.white24;
Color get tLinea => modoClaroActivo ? const Color(0x1F000000) : Colors.white12;
Color get tTexto => modoClaroActivo ? const Color(0xDD000000) : Colors.white;

/// Minúsculas y sin acentos, para buscar sin importar cómo se escribió.
String normalizar(String t) {
  const de = 'áàäâãåéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const a = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
  final sb = StringBuffer();
  for (final r in t.runes) {
    final ch = String.fromCharCode(r);
    final i = de.indexOf(ch);
    sb.write(i >= 0 ? a[i] : ch);
  }
  return sb.toString().toLowerCase();
}

/// Todas las palabras de [consulta] deben aparecer en [texto], en cualquier orden.
bool coincide(String texto, String consulta) {
  final t = normalizar(texto);
  final palabras = normalizar(consulta).split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  for (final p in palabras) {
    if (!t.contains(p)) return false;
  }
  return true;
}

extension TemaContexto on BuildContext {
  Color get acento => Theme.of(this).colorScheme.primary;
  Color get fondoApp => Theme.of(this).scaffoldBackgroundColor;
  Color get panel => Theme.of(this).colorScheme.surface;
  Color get panelElevado => modoClaroActivo
      ? Color.alphaBlend(acento.withValues(alpha: 0.16), const Color(0xFFE6E3F0))
      : Color.alphaBlend(acento.withValues(alpha: 0.08), panel);
}

// ---------------------------------------------------------------------------
// Textos y formatos
// ---------------------------------------------------------------------------

String _limpiar(String? valor, String vacio) {
  if (valor == null) return vacio;
  final v = valor.trim();
  if (v.isEmpty || v == '<unknown>') return vacio;
  return v;
}

String artistaDe(SongModel c) => _limpiar(c.artist, 'Artista desconocido');
String albumDe(SongModel c) => _limpiar(c.album, 'Álbum desconocido');

String? generoDe(SongModel c) {
  final g = c.genre?.trim();
  if (g == null || g.isEmpty || g == '<unknown>') return null;
  return g;
}

String carpetaDe(SongModel c) {
  final ruta = c.data;
  final i = max(ruta.lastIndexOf('/'), ruta.lastIndexOf('\\'));
  return i > 0 ? ruta.substring(0, i) : 'Desconocida';
}

String nombreCarpeta(String ruta) {
  final i = max(ruta.lastIndexOf('/'), ruta.lastIndexOf('\\'));
  return (i >= 0 && i < ruta.length - 1) ? ruta.substring(i + 1) : ruta;
}

String formatoTiempo(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '${d.inMinutes}:$s';
}

String formatoDuracionLarga(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '$h h $m min';
  return '${max(1, d.inMinutes)} min';
}

String formatoTamano(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

Duration duracionTotal(Iterable<SongModel> lista) {
  return Duration(milliseconds: lista.fold<int>(0, (a, s) => a + (s.duration ?? 0)));
}

// ---------------------------------------------------------------------------
// Reproductor
// ---------------------------------------------------------------------------

Future<void> alternarPlayPausa(AudioPlayer p) async {
  if (p.playing) {
    await p.pause();
    return;
  }
  if (p.processingState == ProcessingState.completed) {
    await p.seek(Duration.zero, index: 0);
  }
  unawaited(p.play());
}

// ---------------------------------------------------------------------------
// Carátula
// ---------------------------------------------------------------------------

/// Carátulas elegidas por ti dentro de la app (id de canción -> ruta del archivo).
/// El motor la llena al iniciar y cada vez que cambias una carátula.
final Map<int, String> caratulasPropias = <int, String>{};

Widget caratula(
  SongModel cancion,
  double lado,
  Color acento, {
  double radio = 11,
  int size = 200,
  int quality = 50,
}) {
  final propia = caratulasPropias[cancion.id];
  if (propia != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: Image.file(
        File(propia),
        width: lado,
        height: lado,
        fit: BoxFit.cover,
        cacheWidth: (lado * 2).round().clamp(64, 1200),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          width: lado,
          height: lado,
          color: const Color(0xFF29232F),
          child: Icon(Icons.music_note_rounded, color: acento, size: lado * 0.5),
        ),
      ),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radio),
    child: QueryArtworkWidget(
      id: cancion.id,
      type: ArtworkType.AUDIO,
      artworkWidth: lado,
      artworkHeight: lado,
      artworkFit: BoxFit.cover,
      size: size,
      quality: quality,
      nullArtworkWidget: Container(
        width: lado,
        height: lado,
        color: const Color(0xFF29232F),
        child: Icon(Icons.music_note_rounded, color: acento, size: lado * 0.5),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Color dominante de una imagen (sin paquetes extra)
// ---------------------------------------------------------------------------

Future<Color?> colorDominante(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32, targetHeight: 32);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    codec.dispose();
    if (data == null) return null;

    final pesos = List<double>.filled(12, 0);
    final rs = List<double>.filled(12, 0);
    final gs = List<double>.filled(12, 0);
    final bs = List<double>.filled(12, 0);
    final total = data.lengthInBytes ~/ 4;

    for (var i = 0; i < total; i++) {
      final r = data.getUint8(i * 4);
      final g = data.getUint8(i * 4 + 1);
      final b = data.getUint8(i * 4 + 2);
      final a = data.getUint8(i * 4 + 3);
      if (a < 128) continue;
      final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
      if (hsv.saturation < 0.25 || hsv.value < 0.2) continue;
      final peso = hsv.saturation * hsv.value;
      final cubo = (hsv.hue ~/ 30) % 12;
      pesos[cubo] += peso;
      rs[cubo] += r * peso;
      gs[cubo] += g * peso;
      bs[cubo] += b * peso;
    }

    var mejor = 0;
    for (var i = 1; i < 12; i++) {
      if (pesos[i] > pesos[mejor]) mejor = i;
    }
    if (pesos[mejor] < 8) return null; // imagen casi gris: no hay color claro

    final color = Color.fromARGB(
      255,
      (rs[mejor] / pesos[mejor]).round().clamp(0, 255).toInt(),
      (gs[mejor] / pesos[mejor]).round().clamp(0, 255).toInt(),
      (bs[mejor] / pesos[mejor]).round().clamp(0, 255).toInt(),
    );
    final hsv = HSVColor.fromColor(color);
    return hsv
        .withSaturation(max(hsv.saturation, 0.5))
        .withValue(max(hsv.value, 0.75))
        .toColor();
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Letras (formato .lrc con marcas de tiempo)
// ---------------------------------------------------------------------------

class LineaLetra {
  final Duration tiempo;
  final String texto;
  const LineaLetra(this.tiempo, this.texto);
}

List<LineaLetra> parsearLrc(String texto) {
  final reg = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  final lineas = <LineaLetra>[];
  for (final linea in texto.split(RegExp(r'\r?\n'))) {
    final marcas = reg.allMatches(linea).toList();
    if (marcas.isEmpty) continue;
    final contenido = linea.replaceAll(reg, '').trim();
    for (final m in marcas) {
      final minutos = int.parse(m.group(1)!);
      final segundos = int.parse(m.group(2)!);
      final fraccion = m.group(3);
      var ms = 0;
      if (fraccion != null) {
        ms = int.parse(fraccion.padRight(3, '0').substring(0, 3));
      }
      lineas.add(LineaLetra(
        Duration(minutes: minutos, seconds: segundos, milliseconds: ms),
        contenido,
      ));
    }
  }
  lineas.sort((a, b) => a.tiempo.compareTo(b.tiempo));
  return lineas;
}

// ---------------------------------------------------------------------------
// Barra de progreso (mini reproductor y reproductor completo)
// ---------------------------------------------------------------------------

class BarraProgreso extends StatefulWidget {
  final AudioPlayer reproductor;
  final bool compacta;

  const BarraProgreso({
    super.key,
    required this.reproductor,
    this.compacta = false,
  });

  @override
  State<BarraProgreso> createState() => _BarraProgresoState();
}

class _BarraProgresoState extends State<BarraProgreso> {
  // Mientras arrastras mostramos este valor y solo hacemos seek al soltar.
  double? arrastrando;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.reproductor.durationStream,
      initialData: widget.reproductor.duration,
      builder: (context, snapDuracion) {
        final duracion = snapDuracion.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: widget.reproductor.positionStream,
          builder: (context, snapPosicion) {
            final posicion = snapPosicion.data ?? Duration.zero;
            final maximo = max(1.0, duracion.inMilliseconds.toDouble());
            final actual = arrastrando ?? posicion.inMilliseconds.toDouble();
            final valor = actual.clamp(0.0, maximo).toDouble();

            final slider = Slider(
              min: 0,
              max: maximo,
              value: valor,
              onChanged: (v) => setState(() => arrastrando = v),
              onChangeEnd: (v) async {
                await widget.reproductor.seek(Duration(milliseconds: v.round()));
                if (mounted) setState(() => arrastrando = null);
              },
            );

            if (widget.compacta) {
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: slider,
              );
            }

            return Column(
              children: [
                slider,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatoTiempo(Duration(milliseconds: valor.round())),
                        style: TextStyle(color: tSuave, fontSize: 12),
                      ),
                      Text(
                        formatoTiempo(duracion),
                        style: TextStyle(color: tSuave, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Barritas animadas (indican la canción que está sonando)
// ---------------------------------------------------------------------------

class BarrasAnimadas extends StatefulWidget {
  final Color color;
  final bool activo;
  final double tamano;

  const BarrasAnimadas({
    super.key,
    required this.color,
    required this.activo,
    this.tamano = 22,
  });

  @override
  State<BarrasAnimadas> createState() => _BarrasAnimadasState();
}

class _BarrasAnimadasState extends State<BarrasAnimadas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.activo) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant BarrasAnimadas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activo && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.activo && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * pi;
        final alturas = <double>[
          0.35 + 0.65 * ((sin(t) + 1) / 2),
          0.35 + 0.65 * ((sin(t + 2) + 1) / 2),
          0.35 + 0.65 * ((sin(t + 4) + 1) / 2),
        ];
        return SizedBox(
          width: widget.tamano,
          height: widget.tamano,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final a in alturas)
                Container(
                  width: widget.tamano * 0.2,
                  height: widget.tamano * (widget.activo ? a : 0.4),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogos
// ---------------------------------------------------------------------------

class _DialogoTexto extends StatefulWidget {
  final String titulo;
  final String? etiqueta;
  final String? hint;
  final String inicial;
  final int maxLineas;
  final String textoBoton;

  const _DialogoTexto({
    required this.titulo,
    required this.etiqueta,
    required this.hint,
    required this.inicial,
    required this.maxLineas,
    required this.textoBoton,
  });

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  late final TextEditingController _c = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: widget.maxLineas > 1 ? 5 : 1,
        maxLines: widget.maxLineas,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          hintText: widget.hint,
          alignLabelWithHint: true,
        ),
        onSubmitted: widget.maxLineas == 1
            ? (v) => Navigator.of(context).pop(v.trim())
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: Text(widget.textoBoton),
        ),
      ],
    );
  }
}

/// Pide un texto al usuario. Devuelve null si cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  String? etiqueta,
  String? hint,
  String inicial = '',
  int maxLineas = 1,
  String textoBoton = 'Aceptar',
}) async {
  final resultado = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoTexto(
      titulo: titulo,
      etiqueta: etiqueta,
      hint: hint,
      inicial: inicial,
      maxLineas: maxLineas,
      textoBoton: textoBoton,
    ),
  );
  // Esperamos a que termine la animación de salida del diálogo antes de
  // reconstruir pantallas (evita el error de Flutter con dependents.isEmpty).
  await Future<void>.delayed(const Duration(milliseconds: 350));
  return resultado;
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String textoBoton = 'Aceptar',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoBoton),
        ),
      ],
    ),
  );
  return r == true;
}
