import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart'
    show JustAudioPlatform;
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'registro_errores.dart';
import 'utilidades.dart';

/// Aquí vive toda la lógica de la app: reproductor, biblioteca, favoritos,
/// listas, historial, temporizador, ecualizador, etc.
/// Las pantallas solo muestran lo que este motor les dice.
/// Plataforma de audio "de verdad", guardada ANTES de que cualquier plugin
/// la reemplace. Se usa solo para el segundo reproductor del crossfade.
JustAudioPlatform? plataformaAudioOriginal;

class MotorMusica extends ChangeNotifier {
  static const List<Color> coloresDisponibles = [
    Color(0xFF9B5CFF),
    Color(0xFF3988FF),
    Color(0xFF20C997),
    Color(0xFFFF5263),
    Color(0xFFFFA726),
    Color(0xFFEC407A),
    Color(0xFF26C6DA),
    Color(0xFFFFD54F),
  ];

  late SharedPreferences _prefs;
  bool _cerrado = false;

  // --- Reproductor ---------------------------------------------------------
  final OnAudioQuery consulta = OnAudioQuery();
  final AndroidEqualizer ecualizador = AndroidEqualizer();
  final AndroidLoudnessEnhancer potenciador = AndroidLoudnessEnhancer();
  double potenciadorDb = 0; // 0 a 12 dB
  double gravesRef = 0; // 0 a 1
  late final AudioPlayer reproductor = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [ecualizador, potenciador]),
  );
  ConcatenatingAudioSource? _fuente;
  bool _eqListo = false;

  // --- Tema ----------------------------------------------------------------
  final ValueNotifier<Color> acentoBase = ValueNotifier<Color>(const Color(0xFF9B5CFF));
  final ValueNotifier<Color?> acentoDinamico = ValueNotifier<Color?>(null);
  final ValueNotifier<bool> usarDinamico = ValueNotifier<bool>(true);
  final ValueNotifier<bool> amoled = ValueNotifier<bool>(false);
  /// 0 = automático (según el teléfono), 1 = claro, 2 = oscuro.
  final ValueNotifier<int> modoTema = ValueNotifier<int>(0);
  /// true mientras se muestra la guía de bienvenida (solo la primera vez).
  final ValueNotifier<bool> esperandoBienvenida = ValueNotifier<bool>(false);
  late final Listenable tema = Listenable.merge(
    <Listenable>[acentoBase, acentoDinamico, usarDinamico, amoled, modoTema],
  );
  final Map<int, Color?> _cacheColor = {};

  // --- Estado en vivo ------------------------------------------------------
  final ValueNotifier<SongModel?> cancionActual = ValueNotifier<SongModel?>(null);
  final ValueNotifier<List<SongModel>> cola = ValueNotifier<List<SongModel>>(<SongModel>[]);
  final ValueNotifier<DateTime?> suenoFin = ValueNotifier<DateTime?>(null);
  final ValueNotifier<Set<int>> favoritosVN = ValueNotifier<Set<int>>(<int>{});

  // --- Biblioteca ----------------------------------------------------------
  List<SongModel> _crudas = [];
  List<SongModel> canciones = [];
  Map<int, SongModel> porId = {};
  Map<String, List<SongModel>> albumes = {};
  Map<String, List<SongModel>> artistas = {};
  Map<String, List<SongModel>> carpetas = {};
  Map<String, List<SongModel>> generos = {};
  List<SongModel> descubre = [];
  List<SongModel> sinEscuchar = [];
  bool cargando = true;
  bool _leyendoBiblioteca = false;
  bool permisoDenegado = false;

  // --- Datos del usuario ---------------------------------------------------
  Set<int> favoritos = {};
  Map<String, List<int>> listas = {};
  Set<int> ocultas = {};
  Map<int, int> conteos = {};
  /// Milisegundos realmente escuchados por canción (solo cuenta mientras suena).
  Map<int, int> tiempos = {};

  // --- Etiquetas y carátulas editadas dentro de la app -----------------------
  /// id -> {titulo, artista, album}. El archivo de música NO se modifica.
  Map<int, Map<String, String>> etiquetas = {};
  List<SongModel> _originales = [];

  // --- Filtros de biblioteca -------------------------------------------------
  Set<String> carpetasBloqueadas = {};
  bool bloquearRuido = false;
  bool modoManual = false;
  Set<int> elegidas = {};

  // --- Fundido (crossfade) y visualizador -----------------------------------
  final ValueNotifier<int> fundidoSeg = ValueNotifier<int>(0);
  final ValueNotifier<int> visualizador = ValueNotifier<int>(1); // 0 off,1 barras,2 ondas,3 espejo
  bool espectroPreguntado = false;

  // --- Notificación (se aplica al volver a abrir la app) y colores propios ---
  bool notifMantener = false; // la notificación se queda al pausar
  bool notifFija = true; // no se puede quitar mientras suena
  bool notifUsarColor = false; // usa tu color de acento en la notificación
  List<Color> coloresPropios = [];
  Timer? _timerFundido;
  bool _desvaneciendoSueno = false;
  double _volAplicado = 1.0;
  int _fadeInMs = 1200;
  int? _restanteAnterior;

  // --- Crossfade real (segundo reproductor) ---------------------------------
  AudioPlayer? _sec;
  bool _secFallo = false;
  bool _secListo = false;
  bool _preparando = false;
  int? _idPreparado;
  bool _enFundidoReal = false;
  bool _traspasando = false;
  int? _indicePreparado;
  int _ultimoRestanteMs = 1 << 30;
  int _errores = 0;
  int _fundidoTotalMs = 1;
  double _volSec = 0.0;
  final ValueNotifier<bool> verEspectro = ValueNotifier<bool>(false);
  List<int> recientes = [];
  Map<int, String> letras = {};

  // --- Ajustes -------------------------------------------------------------
  String orden = 'Título';
  int duracionMinimaMs = 30000;
  bool saltarSilencio = false;
  bool albumesEnCuadricula = true;

  // --- Internos ------------------------------------------------------------
  final List<StreamSubscription<dynamic>> _subs = [];
  final StreamController<String> _avisos = StreamController<String>.broadcast();
  Timer? _timerEstado;
  Timer? _timerTiempo;
  DateTime? _ultimoTick;
  int _tickDesdeGuardado = 0;
  Timer? _timerCola;
  Timer? _timerSueno;
  bool _contadaActual = false;

  Stream<String> get avisos => _avisos.stream;

  void aviso(String texto) {
    if (!_avisos.isClosed) _avisos.add(texto);
  }

  void _notificar() {
    if (!_cerrado) notifyListeners();
  }

  // ===========================================================================
  // Inicio
  // ===========================================================================

  Future<void> iniciar() async {
    _prefs = await SharedPreferences.getInstance();
    _cargarPreferencias();
    await _aplicarModosGuardados();
    _escuchar();
    // Primera vez: se muestra la bienvenida y los permisos se piden al terminarla.
    if (esperandoBienvenida.value) return;
    await _cargarCache(); // muestra tu música al instante mientras se actualiza
    await cargarCanciones();
    await _restaurar();
  }

  Future<void> terminarBienvenida() async {
    await _prefs.setBool('bienvenida_vista', true);
    esperandoBienvenida.value = false;
    await cargarCanciones();
    await _restaurar();
  }

  @override
  void dispose() {
    _cerrado = true;
    _guardarEstado();
    for (final s in _subs) {
      s.cancel();
    }
    _timerEstado?.cancel();
    _timerTiempo?.cancel();
    _timerFundido?.cancel();
    _sec?.dispose();
    _timerCola?.cancel();
    _timerSueno?.cancel();
    _avisos.close();
    reproductor.dispose();
    acentoBase.dispose();
    acentoDinamico.dispose();
    usarDinamico.dispose();
    amoled.dispose();
    modoTema.dispose();
    esperandoBienvenida.dispose();
    cancionActual.dispose();
    cola.dispose();
    suenoFin.dispose();
    favoritosVN.dispose();
    super.dispose();
  }

  void _cargarPreferencias() {
    favoritos = (_prefs.getStringList('favoritos_musica') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    favoritosVN.value = Set<int>.from(favoritos);

    ocultas = (_prefs.getStringList('ocultas_musica') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();

    recientes = (_prefs.getStringList('recientes_musica') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList();

    try {
      final texto = _prefs.getString('listas_musica');
      if (texto != null) {
        final datos = jsonDecode(texto) as Map<String, dynamic>;
        listas = datos.map(
          (nombre, ids) => MapEntry(
            nombre,
            (ids as List).map((id) => (id as num).toInt()).toList(),
          ),
        );
      }
    } catch (_) {
      listas = {};
    }

    try {
      final texto = _prefs.getString('conteos_musica');
      if (texto != null) {
        final datos = jsonDecode(texto) as Map<String, dynamic>;
        conteos = datos.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
      }
    } catch (_) {
      conteos = {};
    }

    try {
      final texto = _prefs.getString('tiempos_musica');
      if (texto != null) {
        final datos = jsonDecode(texto) as Map<String, dynamic>;
        tiempos = datos.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
      }
    } catch (_) {
      tiempos = {};
    }

    try {
      final texto = _prefs.getString('letras_musica');
      if (texto != null) {
        final datos = jsonDecode(texto) as Map<String, dynamic>;
        letras = datos.map((k, v) => MapEntry(int.parse(k), v as String));
      }
    } catch (_) {
      letras = {};
    }

    orden = _prefs.getString('orden_biblioteca') ?? 'Título';
    duracionMinimaMs = _prefs.getInt('duracion_minima') ?? 30000;
    fundidoSeg.value = _prefs.getInt('fundido_seg') ?? 0;
    visualizador.value = (_prefs.getInt('visualizador') ?? 1).clamp(1, 3);
    verEspectro.value = _prefs.getBool('ver_espectro') ?? false;
    espectroPreguntado = _prefs.getBool('espectro_preguntado') ?? false;
    notifMantener = _prefs.getBool('notif_mantener') ?? false;
    notifFija = _prefs.getBool('notif_ongoing') ?? true;
    notifUsarColor = _prefs.getBool('notif_usar_color') ?? false;
    coloresPropios = (_prefs.getStringList('colores_propios') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .map(Color.new)
        .toList();
    bloquearRuido = _prefs.getBool('bloquear_ruido') ?? false;
    modoManual = _prefs.getBool('modo_manual') ?? false;
    carpetasBloqueadas =
        (_prefs.getStringList('carpetas_bloqueadas') ?? <String>[]).toSet();
    elegidas = (_prefs.getStringList('canciones_elegidas') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    try {
      final texto = _prefs.getString('etiquetas_musica');
      if (texto != null) {
        final datos = jsonDecode(texto) as Map<String, dynamic>;
        etiquetas = datos.map((k, v) => MapEntry(
              int.parse(k),
              (v as Map<String, dynamic>).map((a, b) => MapEntry(a, b as String)),
            ));
      }
    } catch (_) {
      etiquetas = {};
    }
    try {
      final texto = _prefs.getString('caratulas_propias');
      caratulasPropias.clear();
      if (texto != null) {
        final datos = jsonDecode(texto) as Map<String, dynamic>;
        datos.forEach((k, v) {
          if (File(v as String).existsSync()) caratulasPropias[int.parse(k)] = v;
        });
      }
    } catch (_) {
      caratulasPropias.clear();
    }
    saltarSilencio = _prefs.getBool('saltar_silencio') ?? false;
    albumesEnCuadricula = _prefs.getBool('albumes_cuadricula') ?? true;
    amoled.value = _prefs.getBool('amoled') ?? false;
    modoTema.value = _prefs.getInt('modo_tema') ?? 0;
    usarDinamico.value = _prefs.getBool('acento_dinamico') ?? true;
    final color = _prefs.getInt('color_acento');
    if (color != null) acentoBase.value = Color(color);
  }

  Future<void> _aplicarModosGuardados() async {
    try {
      final modo = (_prefs.getInt('modo_repetir') ?? 0).clamp(0, LoopMode.values.length - 1).toInt();
      await reproductor.setLoopMode(LoopMode.values[modo]);
      await reproductor.setShuffleModeEnabled(_prefs.getBool('modo_aleatorio') ?? false);
      final velocidad = _prefs.getDouble('velocidad') ?? 1.0;
      if (velocidad != 1.0) await reproductor.setSpeed(velocidad);
      if (saltarSilencio) await reproductor.setSkipSilenceEnabled(true);
    } catch (_) {}
  }

  // ===========================================================================
  // Escuchar al reproductor
  // ===========================================================================

  void _escuchar() {
    // La canción actual se lee de la etiqueta de cada fuente: así siempre es
    // correcta aunque reordenes o quites canciones de la cola.
    _subs.add(reproductor.sequenceStateStream.listen((estado) {
      final tag = estado?.currentSource?.tag;
      if (tag is MediaItem) {
        final c = porId[int.tryParse(tag.id) ?? -1];
        if (c != null) _alCambiarCancion(c);
      }
    }));

    // La cola se lee directamente del reproductor.
    _subs.add(reproductor.sequenceStream.listen((secuencia) {
      final lista = <SongModel>[];
      for (final fuente in (secuencia ?? <IndexedAudioSource>[])) {
        final tag = fuente.tag;
        if (tag is MediaItem) {
          final c = porId[int.tryParse(tag.id) ?? -1];
          if (c != null) lista.add(c);
        }
      }
      cola.value = lista;
      _programarGuardadoCola(lista);
    }));

    _subs.add(reproductor.loopModeStream.listen((m) => _prefs.setInt('modo_repetir', m.index)));
    _subs.add(reproductor.playingStream.listen(_alCambiarPlaying));
    _subs.add(reproductor.shuffleModeEnabledStream.listen((v) => _prefs.setBool('modo_aleatorio', v)));
    _subs.add(reproductor.speedStream.listen((v) => _prefs.setDouble('velocidad', v)));

    _subs.add(reproductor.playingStream.listen((sonando) {
      if (!sonando) _guardarEstado();
    }));

    _subs.add(reproductor.playbackEventStream.listen(
      (e) {
        if (e.processingState == ProcessingState.ready) _errores = 0;
      },
      onError: (Object e, StackTrace st) {
        _errores++;
        if (_errores <= 3 && reproductor.hasNext) {
          aviso('No se pudo reproducir una canción; paso a la siguiente.');
          unawaited(reproductor.seekToNext().catchError((Object _) {}));
        } else if (_errores <= 1) {
          aviso('No se pudo reproducir esta canción.');
        }
      },
    ));

    // Cada segundo: suma el tiempo REAL que la música estuvo sonando.
    _ultimoTick = DateTime.now();
    _timerTiempo = Timer.periodic(const Duration(seconds: 1), (_) => _sumarTiempo());
    _timerFundido = Timer.periodic(const Duration(milliseconds: 100), (_) => _tickFundido());

    // Cada 5 segundos: guardar posición y contar reproducciones.
    _timerEstado = Timer.periodic(const Duration(seconds: 5), (_) {
      if (reproductor.playing) {
        _guardarEstado();
        _contarReproduccion();
      }
    });
  }

  void _sumarTiempo() {
    final ahora = DateTime.now();
    final antes = _ultimoTick ?? ahora;
    _ultimoTick = ahora;
    final c = cancionActual.value;
    if (c == null || !reproductor.playing) return;
    if (reproductor.processingState != ProcessingState.ready) return;
    // Se limita el salto por si la app estuvo dormida.
    final ms = ahora.difference(antes).inMilliseconds.clamp(0, 2000);
    if (ms == 0) return;
    tiempos[c.id] = (tiempos[c.id] ?? 0) + ms;
    _tickDesdeGuardado += ms;
    if (_tickDesdeGuardado >= 10000) {
      _tickDesdeGuardado = 0;
      _guardarTiempos();
    }
  }

  /// Total de milisegundos escuchados en toda la app.
  int get tiempoTotalMs => tiempos.values.fold<int>(0, (a, b) => a + b);

  void _alCambiarCancion(SongModel c) {
    if (cancionActual.value?.id == c.id) return;
    cancionActual.value = c;
    _contadaActual = false;
    // Si la canción anterior estaba por terminar, la nueva entra con el fundido completo.
    final cf = fundidoSeg.value * 1000;
    _fadeInMs = (cf > 0 && _restanteAnterior != null && _restanteAnterior! < cf + 1500) ? cf : 1200;
    _restanteAnterior = null;
    if (_enFundidoReal) unawaited(_traspaso(c));
    _registrarReciente(c);
    unawaited(_actualizarAcento(c));
    _guardarEstado();
    _notificar();
  }

  void _registrarReciente(SongModel c) {
    recientes.remove(c.id);
    recientes.insert(0, c.id);
    if (recientes.length > 50) recientes = recientes.sublist(0, 50);
    _prefs.setStringList('recientes_musica', recientes.map((e) => e.toString()).toList());
  }

  void _contarReproduccion() {
    final c = cancionActual.value;
    if (c == null || _contadaActual) return;
    if (reproductor.position.inSeconds >= 20) {
      _contadaActual = true;
      conteos[c.id] = (conteos[c.id] ?? 0) + 1;
      _guardarConteos();
      _notificar();
    }
  }

  Future<void> _guardarEstado() async {
    final c = cancionActual.value;
    if (c == null) return;
    await _prefs.setInt('ultima_id', c.id);
    await _prefs.setInt('ultima_pos', reproductor.position.inMilliseconds);
    await _prefs.setInt('ultima_idx', reproductor.currentIndex ?? 0);
  }

  void _programarGuardadoCola(List<SongModel> lista) {
    if (lista.isEmpty) return; // no borrar lo guardado durante el arranque
    _timerCola?.cancel();
    _timerCola = Timer(const Duration(seconds: 1), () {
      _prefs.setStringList('ultima_cola', lista.map((s) => s.id.toString()).toList());
    });
  }

  Future<void> _restaurar() async {
    if (canciones.isEmpty || reproductor.audioSource != null) return;
    final id = _prefs.getInt('ultima_id');
    if (id == null) return;
    final pos = _prefs.getInt('ultima_pos') ?? 0;
    final pista = _prefs.getInt('ultima_idx') ?? 0;

    final ids = _prefs.getStringList('ultima_cola') ?? <String>[];
    var lista = ids
        .map(int.tryParse)
        .map((x) => x == null ? null : porId[x])
        .whereType<SongModel>()
        .where((s) => (s.uri ?? '').isNotEmpty)
        .toList();
    if (lista.isEmpty) {
      lista = canciones.where((s) => (s.uri ?? '').isNotEmpty).toList();
    }

    var indice = (pista >= 0 && pista < lista.length && lista[pista].id == id)
        ? pista
        : lista.indexWhere((s) => s.id == id);
    if (indice < 0) return;

    await _cargar(
      lista,
      indice,
      posicion: Duration(milliseconds: pos),
      iniciar: false,
      silencioso: true,
    );
  }

  // ===========================================================================
  // Permisos y biblioteca
  // ===========================================================================

  Future<bool> _solicitarPermisos() async {
    var estado = await Permission.audio.status;
    if (!estado.isGranted) estado = await Permission.audio.request();
    if (!estado.isGranted) {
      estado = await Permission.storage.status;
      if (!estado.isGranted) estado = await Permission.storage.request();
    }
    if (estado.isGranted) {
      // Permiso para mostrar la notificación del reproductor (Android 13+).
      if (!(await Permission.notification.status).isGranted) {
        await Permission.notification.request();
      }
    }
    return estado.isGranted;
  }

  Future<void> cargarCanciones() async {
    if (_leyendoBiblioteca) return;
    _leyendoBiblioteca = true;
    cargando = _crudas.isEmpty; // con copia guardada no se muestra la ruedita
    permisoDenegado = false;
    _notificar();
    try {
      final permiso = await _solicitarPermisos();
      if (!permiso) {
        permisoDenegado = true;
        cargando = false;
        _notificar();
        return;
      }
      final resultado = await _consultarCanciones();
      _originales = resultado;
      _crudas = _originales.map(_conEtiquetas).toList();
      cargando = false;
      _aplicarFiltros();
      unawaited(_guardarCache());
    } catch (e) {
      cargando = false;
      _notificar();
      RegistroErrores.anotar('Carga de biblioteca', '$e');
      aviso('No pude leer tu música en este momento. Intenta de nuevo en unos segundos.');
    } finally {
      _leyendoBiblioteca = false;
    }
  }

  // Copia de la biblioteca para que la app abra al instante ---------------------
  Future<File> _archivoCache() async {
    final d = await getApplicationSupportDirectory();
    return File('${d.path}/biblioteca_cache.json');
  }

  Future<void> _cargarCache() async {
    try {
      final f = await _archivoCache();
      if (!await f.exists()) return;
      final lista = jsonDecode(await f.readAsString()) as List;
      final guardadas =
          lista.map((e) => SongModel(Map<dynamic, dynamic>.from(e as Map))).toList();
      if (guardadas.isEmpty) return;
      _originales = guardadas;
      _crudas = _originales.map(_conEtiquetas).toList();
      cargando = false;
      _aplicarFiltros();
    } catch (_) {}
  }

  Future<void> _guardarCache() async {
    try {
      final f = await _archivoCache();
      await f.writeAsString(jsonEncode(_originales.map((s) => s.getMap).toList()));
    } catch (_) {}
  }

  /// Al volver a la app tras mucho tiempo, Android puede tardar un instante en
  /// reconectar el plugin de música ("lateinit ... not been initialized").
  /// Se reintenta unas veces en silencio antes de rendirse.
  Future<List<SongModel>> _consultarCanciones() async {
    Object? ultimo;
    for (var intento = 0; intento < 5; intento++) {
      try {
        return await consulta.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
      } catch (e) {
        ultimo = e;
        final t = e.toString().toLowerCase();
        final transitorio = t.contains('lateinit') ||
            t.contains('not been initialized') ||
            t.contains('activity') ||
            t.contains('null');
        if (!transitorio) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (intento + 1)));
        if (_cerrado) break;
      }
    }
    throw ultimo ?? StateError('No se pudo leer la biblioteca');
  }

  void _aplicarFiltros() {
    canciones = _crudas.where(_pasaFiltros).toList();
    _indexar();
    _notificar();
  }

  // ===========================================================================
  // Filtros de biblioteca
  // ===========================================================================

  static const List<String> _palabrasRuido = <String>[
    'whatsapp', 'recorder', 'recording', 'grabacion', 'grabaci',
    'notification', 'ringtone', 'alarm', 'llamada', 'voice note',
    'voicenote', 'voice_note', 'voice memo', 'sound_recorder', 'call',
  ];

  bool _esRuido(SongModel s) {
    final ruta = s.data.toLowerCase().replaceAll('\\', '/');
    final carpeta = ruta.contains('/') ? ruta.substring(0, ruta.lastIndexOf('/')) : ruta;
    for (final p in _palabrasRuido) {
      if (p == 'call') {
        // "call" solo cuenta si es una carpeta completa (evita falsos positivos).
        if (carpeta.split('/').any((seg) => seg == 'call' || seg == 'calls' || seg == 'callrecorder')) {
          return true;
        }
      } else if (carpeta.contains(p)) {
        return true;
      }
    }
    return false;
  }

  bool _pasaFiltros(SongModel s) {
    if (ocultas.contains(s.id)) return false;
    if (modoManual) return elegidas.contains(s.id);
    if ((s.duration ?? 0) < duracionMinimaMs) return false;
    if (carpetasBloqueadas.contains(carpetaDe(s))) return false;
    if (bloquearRuido && _esRuido(s)) return false;
    return true;
  }

  /// Carpetas con su número de canciones (sin aplicar filtros), de mayor a menor.
  List<MapEntry<String, int>> get carpetasConConteo {
    final m = <String, int>{};
    for (final s in _crudas) {
      final c = carpetaDe(s);
      m[c] = (m[c] ?? 0) + 1;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Todas las canciones del teléfono (menos las ocultas), para elegir a mano.
  List<SongModel> get todasLasCanciones =>
      _crudas.where((s) => !ocultas.contains(s.id)).toList();

  Future<void> configurarFiltros({
    Set<String>? carpetas,
    bool? ruido,
    bool? manual,
    Set<int>? soloEstas,
  }) async {
    if (carpetas != null) carpetasBloqueadas = carpetas;
    if (ruido != null) bloquearRuido = ruido;
    if (manual != null) {
      modoManual = manual;
      // Al activar el modo manual por primera vez, se parte de lo que ya ves.
      if (manual && elegidas.isEmpty && soloEstas == null) {
        elegidas = canciones.map((s) => s.id).toSet();
      }
    }
    if (soloEstas != null) elegidas = soloEstas;
    await _prefs.setStringList('carpetas_bloqueadas', carpetasBloqueadas.toList());
    await _prefs.setBool('bloquear_ruido', bloquearRuido);
    await _prefs.setBool('modo_manual', modoManual);
    await _prefs.setStringList('canciones_elegidas', elegidas.map((e) => e.toString()).toList());
    _aplicarFiltros();
  }

  // ===========================================================================
  // Etiquetas y carátulas (se guardan en la app, no en el archivo)
  // ===========================================================================

  SongModel _conEtiquetas(SongModel s) {
    final e = etiquetas[s.id];
    if (e == null) return s;
    final m = Map<dynamic, dynamic>.from(s.getMap);
    if ((e['titulo'] ?? '').isNotEmpty) m['title'] = e['titulo'];
    if ((e['artista'] ?? '').isNotEmpty) m['artist'] = e['artista'];
    if ((e['album'] ?? '').isNotEmpty) m['album'] = e['album'];
    return SongModel(m);
  }

  Future<void> _guardarEtiquetas() => _prefs.setString(
      'etiquetas_musica',
      jsonEncode(etiquetas.map((k, v) => MapEntry(k.toString(), v))));

  Future<void> _guardarCaratulas() => _prefs.setString(
      'caratulas_propias',
      jsonEncode(caratulasPropias.map((k, v) => MapEntry(k.toString(), v))));

  /// Rehace la biblioteca con las etiquetas actuales y refresca lo que suena.
  void _reconstruir(int id) {
    _crudas = _originales.map(_conEtiquetas).toList();
    _aplicarFiltros();
    final actual = cancionActual.value;
    if (actual != null) {
      final nueva = porId[actual.id];
      if (nueva != null) {
        // Copia nueva para que las pantallas se enteren aunque sea la misma canción.
        cancionActual.value = SongModel(Map<dynamic, dynamic>.from(nueva.getMap));
      }
    }
    cola.value = cola.value.map((s) => porId[s.id] ?? s).toList();
    if (cancionActual.value?.id == id) {
      _cacheColor.remove(id);
      unawaited(_actualizarAcento(cancionActual.value!));
    }
  }

  Future<void> guardarEtiquetas(int id, {String? titulo, String? artista, String? album}) async {
    final i = _originales.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final o = _originales[i];
    final m = <String, String>{};
    void poner(String clave, String? nuevo, String? original) {
      final n = (nuevo ?? '').trim();
      if (n.isNotEmpty && n != (original ?? '').trim()) m[clave] = n;
    }

    poner('titulo', titulo, o.title);
    poner('artista', artista, o.artist);
    poner('album', album, o.album);
    if (m.isEmpty) {
      etiquetas.remove(id);
    } else {
      etiquetas[id] = m;
    }
    await _guardarEtiquetas();
    _reconstruir(id);
  }

  Future<void> establecerCaratula(int id, String rutaTemporal) async {
    final base = await getApplicationSupportDirectory();
    final carpeta = Directory('${base.path}/caratulas');
    if (!carpeta.existsSync()) carpeta.createSync(recursive: true);
    final destino = '${carpeta.path}/${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(rutaTemporal).copy(destino);
    final vieja = caratulasPropias[id];
    if (vieja != null) {
      try {
        await File(vieja).delete();
      } catch (_) {}
    }
    caratulasPropias[id] = destino;
    await _guardarCaratulas();
    _reconstruir(id);
  }

  Future<void> quitarCaratula(int id) async {
    final vieja = caratulasPropias.remove(id);
    if (vieja != null) {
      try {
        await File(vieja).delete();
      } catch (_) {}
    }
    await _guardarCaratulas();
    _reconstruir(id);
  }

  // ===========================================================================
  // Fundido entre canciones (crossfade) y visualizador
  // ===========================================================================

  void setFundido(int seg) {
    fundidoSeg.value = seg;
    _prefs.setInt('fundido_seg', seg);
    if (seg == 0 && _enFundidoReal) _abortarFundido();
    if (seg == 0 && _volAplicado != 1.0) {
      _volAplicado = 1.0;
      reproductor.setVolume(1.0).catchError((Object _) {});
    }
  }

  void setVisualizador(int estilo) {
    visualizador.value = estilo;
    _prefs.setInt('visualizador', estilo);
  }

  void alternarEspectro() {
    verEspectro.value = !verEspectro.value;
    _prefs.setBool('ver_espectro', verEspectro.value);
  }

  void marcarEspectroPreguntado() {
    espectroPreguntado = true;
    _prefs.setBool('espectro_preguntado', true);
  }

  /// Cada 100 ms ajusta el volumen: baja al final de la canción y sube al empezar
  /// la siguiente. (just_audio solo permite un reproductor, así que es un fundido
  /// de salida + entrada, no dos canciones sonando a la vez.)
  // ---------------------------------------------------------------------------
  // Crossfade REAL: la canción siguiente empieza a sonar (en un segundo
  // reproductor) mientras la actual todavía está terminando. Al acabar la actual,
  // el reproductor principal toma el relevo en la misma posición.
  // Si algo falla, se usa el fundido simple de abajo.
  // ---------------------------------------------------------------------------

  Future<T> _conPlataformaOriginal<T>(Future<T> Function() f) async {
    final original = plataformaAudioOriginal;
    if (original == null) return f();
    final actual = JustAudioPlatform.instance;
    JustAudioPlatform.instance = original;
    try {
      return await f();
    } finally {
      JustAudioPlatform.instance = actual;
    }
  }

  /// La canción que sonará después (respeta aleatorio y repetir) y su posición en la cola.
  (SongModel, int)? _siguienteCancion() {
    final i = reproductor.loopMode == LoopMode.one
        ? reproductor.currentIndex
        : reproductor.nextIndex;
    final seq = reproductor.sequence;
    if (i == null || seq == null || i < 0 || i >= seq.length) return null;
    final tag = seq[i].tag;
    if (tag is! MediaItem) return null;
    final id = int.tryParse(tag.id);
    final c = id == null ? null : porId[id];
    return c == null ? null : (c, i);
  }

  Future<void> _prepararSecundario(SongModel sig, int indice) async {
    if (_preparando || (sig.uri ?? '').isEmpty) return;
    _preparando = true;
    _secListo = false;
    try {
      _sec ??= AudioPlayer(
        handleInterruptions: false,
        androidApplyAudioAttributes: false,
      );
      final s = _sec!;
      await _conPlataformaOriginal(() => s.setAudioSource(
            AudioSource.uri(Uri.parse(sig.uri!)),
            preload: true,
          ));
      await s.setVolume(0);
      await s.setSpeed(reproductor.speed);
      _volSec = 0;
      _idPreparado = sig.id;
      _indicePreparado = indice;
      _secListo = true;
    } catch (_) {
      _secFallo = true; // este teléfono no lo permite: se usa el fundido simple
      _secListo = false;
    } finally {
      _preparando = false;
    }
  }

  void _fijarVolumenes(double principal, double secundario) {
    if ((principal - _volAplicado).abs() > 0.01) {
      _volAplicado = principal;
      reproductor.setVolume(principal).catchError((Object _) {});
    }
    if ((secundario - _volSec).abs() > 0.01) {
      _volSec = secundario;
      _sec?.setVolume(secundario).catchError((Object _) {});
    }
  }

  void _iniciarFundidoReal(int restanteMs) {
    final s = _sec;
    if (s == null) return;
    _enFundidoReal = true;
    _fundidoTotalMs = max(1, restanteMs);
    _volSec = 0;
    s.setVolume(0).catchError((Object _) {});
    unawaited(s.play().catchError((Object _) {}));
  }

  void _abortarFundido() {
    _enFundidoReal = false;
    _traspasando = false;
    _secListo = false;
    _idPreparado = null;
    _indicePreparado = null;
    _volSec = 0;
    final s = _sec;
    if (s != null) {
      s.pause().catchError((Object _) {});
      s.setVolume(0).catchError((Object _) {});
    }
    _volAplicado = 1.0;
    reproductor.setVolume(1.0).catchError((Object _) {});
  }

  void _alCambiarPlaying(bool suena) {
    final s = _sec;
    if (s == null || !_enFundidoReal) return;
    if (suena) {
      unawaited(s.play().catchError((Object _) {}));
    } else {
      s.pause().catchError((Object _) {});
    }
  }

  /// Índice actual de la canción preparada (la cola pudo cambiar mientras tanto).
  int? _indiceVigente(int? preferido) {
    final id = _idPreparado;
    final seq = reproductor.sequence;
    if (id == null || seq == null) return null;
    bool coincide(int i) {
      if (i < 0 || i >= seq.length) return false;
      final t = seq[i].tag;
      return t is MediaItem && t.id == id.toString();
    }

    if (preferido != null && coincide(preferido)) return preferido;
    for (var i = 0; i < seq.length; i++) {
      if (coincide(i)) return i;
    }
    return null;
  }

  /// El principal ya pasó a la canción siguiente: se alinea con el secundario
  /// y se hace un relevo suave (los dos suenan lo mismo, así no se nota).
  Future<void> _traspaso(SongModel nueva) async {
    final s = _sec;
    final destino = _indiceVigente(_indicePreparado);
    // Si el cambio llegó cuando la canción casi terminaba, fue automático.
    // Si no, el usuario cambió de canción a mano: solo se sigue si eligió la misma.
    final automatico = _ultimoRestanteMs < 800;
    if (s == null || destino == null || (!automatico && nueva.id != _idPreparado)) {
      _abortarFundido();
      return;
    }
    _enFundidoReal = false;
    _traspasando = true;
    try {
      await reproductor.setVolume(0);
      _volAplicado = 0;
      var extra = 160;
      for (var i = 0; i < 2; i++) {
        final t0 = DateTime.now();
        // Con "index" se garantiza que el principal toque la MISMA canción que
        // el secundario, aunque el orden aleatorio o la repetición difieran.
        await reproductor.seek(s.position + Duration(milliseconds: extra), index: destino);
        final tardo = DateTime.now().difference(t0).inMilliseconds;
        final dif = (s.position - reproductor.position).inMilliseconds;
        if (dif.abs() < 60) break;
        extra = tardo + 20;
      }
      for (var i = 1; i <= 5; i++) {
        final v = i / 5;
        _volAplicado = v;
        await reproductor.setVolume(v);
        await s.setVolume(1 - v);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await s.pause();
    } catch (_) {
      _secFallo = true;
    } finally {
      _volSec = 0;
      _volAplicado = 1.0;
      reproductor.setVolume(1.0).catchError((Object _) {});
      _idPreparado = null;
      _indicePreparado = null;
      _secListo = false;
      _traspasando = false;
    }
  }

  void _tickFundido() {
    final seg = fundidoSeg.value;
    if (_desvaneciendoSueno || _cerrado || _traspasando) return;
    if (seg <= 0) return;
    if (_secFallo || plataformaAudioOriginal == null) {
      _tickFundidoSimple();
      return;
    }
    if (!reproductor.playing) return;
    final dur = reproductor.duration;
    if (dur == null || dur.inMilliseconds <= 0) return;
    final restante = dur.inMilliseconds - reproductor.position.inMilliseconds;
    final cfMs = min(seg * 1000, dur.inMilliseconds ~/ 2);

    if (_enFundidoReal) {
      if (restante > _fundidoTotalMs + 1200) {
        // La posición volvió al principio: o la canción se repitió sola
        // (repetir una / una sola canción en la cola) o el usuario retrocedió.
        final actual = cancionActual.value;
        if (actual != null &&
            actual.id == _idPreparado &&
            reproductor.position.inMilliseconds < 4000 &&
            _ultimoRestanteMs < 800) {
          unawaited(_traspaso(actual));
        } else {
          _abortarFundido();
        }
        return;
      }
      _ultimoRestanteMs = restante;
      final p = (1 - restante / _fundidoTotalMs).clamp(0.0, 1.0).toDouble();
      _fijarVolumenes(cos(p * pi / 2), sin(p * pi / 2));
      return;
    }
    if (_volAplicado != 1.0) {
      _volAplicado = 1.0;
      reproductor.setVolume(1.0).catchError((Object _) {});
    }
    final sigInfo = _siguienteCancion();
    if (sigInfo == null) return;
    final sig = sigInfo.$1;
    if (restante <= cfMs + 5000 &&
        (_idPreparado != sig.id || _indicePreparado != sigInfo.$2) &&
        !_preparando) {
      unawaited(_prepararSecundario(sig, sigInfo.$2));
    }
    if (_secListo && _idPreparado == sig.id && restante <= cfMs && restante > 150) {
      _ultimoRestanteMs = restante;
      _iniciarFundidoReal(restante);
    }
  }

  /// Fundido simple (respaldo): baja el volumen al final y lo sube al empezar.
  void _tickFundidoSimple() {
    final seg = fundidoSeg.value;
    if (_desvaneciendoSueno || _cerrado) return;
    if (seg <= 0) return;
    if (!reproductor.playing) return;
    final dur = reproductor.duration;
    if (dur == null || dur.inMilliseconds <= 0) return;
    final pos = reproductor.position.inMilliseconds;
    final restante = dur.inMilliseconds - pos;
    _restanteAnterior = restante;

    final maxVentana = dur.inMilliseconds ~/ 2;
    final ventana = min(seg * 1000, maxVentana);
    final entrada = min(_fadeInMs, maxVentana);

    var v = 1.0;
    final hayLuego = reproductor.hasNext || reproductor.loopMode != LoopMode.off;
    if (hayLuego && ventana > 0 && restante < ventana) {
      v = min(v, restante / ventana);
    }
    if (entrada > 0 && pos < entrada) {
      v = min(v, pos / entrada);
    }
    v = v.clamp(0.0, 1.0).toDouble();
    // Curva de potencia constante: suena más natural que una recta.
    v = sin(v * pi / 2);
    if ((v - _volAplicado).abs() > 0.015) {
      _volAplicado = v;
      reproductor.setVolume(v).catchError((Object _) {});
    }
  }

  void _indexar() {
    porId = {for (final s in canciones) s.id: s};

    final a = <String, List<SongModel>>{};
    final r = <String, List<SongModel>>{};
    final c = <String, List<SongModel>>{};
    final g = <String, List<SongModel>>{};
    for (final s in canciones) {
      (a[albumDe(s)] ??= <SongModel>[]).add(s);
      (r[artistaDe(s)] ??= <SongModel>[]).add(s);
      (c[carpetaDe(s)] ??= <SongModel>[]).add(s);
      final gen = generoDe(s);
      if (gen != null) (g[gen] ??= <SongModel>[]).add(s);
    }

    int porPista(SongModel x, SongModel y) {
      final t = (x.track ?? 0).compareTo(y.track ?? 0);
      if (t != 0) return t;
      return x.title.toLowerCase().compareTo(y.title.toLowerCase());
    }

    for (final lista in a.values) {
      lista.sort(porPista);
    }

    Map<String, List<SongModel>> ordenar(Map<String, List<SongModel>> m) {
      final claves = m.keys.toList()
        ..sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
      return {for (final k in claves) k: m[k]!};
    }

    albumes = ordenar(a);
    artistas = ordenar(r);
    carpetas = ordenar(c);
    generos = ordenar(g);

    final mezcla = List<SongModel>.of(canciones)..shuffle(Random());
    descubre = mezcla.take(14).toList();
    sinEscuchar = (canciones.where((s) => !conteos.containsKey(s.id)).toList()
          ..shuffle(Random()))
        .take(14)
        .toList();
  }

  // Listas para la pantalla de inicio -----------------------------------------

  List<SongModel> get recientesCanciones =>
      recientes.map((id) => porId[id]).whereType<SongModel>().toList();

  List<SongModel> get masEscuchadas {
    final e = conteos.entries.where((x) => porId.containsKey(x.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return e.take(15).map((x) => porId[x.key]!).toList();
  }

  List<SongModel> get agregadasRecientemente {
    final l = List<SongModel>.of(canciones)
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return l.take(15).toList();
  }

  List<SongModel> get cancionesFavoritas =>
      canciones.where((s) => favoritos.contains(s.id)).toList();

  List<SongModel> get cancionesOcultas =>
      _crudas.where((s) => ocultas.contains(s.id)).toList();

  int get reproduccionesTotales => conteos.values.fold<int>(0, (a, b) => a + b);

  // ===========================================================================
  // Reproducción
  // ===========================================================================

  AudioSource _fuenteDe(SongModel c) {
    return AudioSource.uri(
      Uri.parse(c.uri!),
      tag: MediaItem(
        id: c.id.toString(),
        title: c.title,
        artist: artistaDe(c),
        album: albumDe(c),
        duration: c.duration != null ? Duration(milliseconds: c.duration!) : null,
        artUri: caratulasPropias[c.id] != null
            ? Uri.file(caratulasPropias[c.id]!)
            : (c.albumId != null
                ? Uri.parse('content://media/external/audio/albumart/${c.albumId}')
                : null),
      ),
    );
  }

  List<SongModel> _validas(List<SongModel> lista) =>
      lista.where((s) => (s.uri ?? '').isNotEmpty).toList();

  /// Reproduce [inicial] y deja en la cola todas las canciones de [lista].
  Future<void> reproducir(List<SongModel> lista, SongModel inicial) async {
    final validas = _validas(lista);
    final indice = validas.indexWhere((s) => s.id == inicial.id);
    if (indice < 0) {
      aviso('No se encontró la ubicación de esta canción.');
      return;
    }
    await _cargar(validas, indice);
  }

  Future<void> _cargar(
    List<SongModel> lista,
    int indice, {
    Duration posicion = Duration.zero,
    bool iniciar = true,
    bool silencioso = false,
  }) async {
    try {
      if (_enFundidoReal || _traspasando) _abortarFundido();
      _alCambiarCancion(lista[indice]);
      final nueva = ConcatenatingAudioSource(children: lista.map(_fuenteDe).toList());
      _fuente = nueva;
      await reproductor.setAudioSource(
        nueva,
        initialIndex: indice,
        initialPosition: posicion,
      );
      if (!_eqListo) {
        _eqListo = true;
        unawaited(_cargarEcualizador());
      }
      if (iniciar) unawaited(reproductor.play());
    } catch (e) {
      final t = e.toString().toLowerCase();
      // Tocar otra canción mientras carga la anterior cancela la carga: no es un error.
      if (t.contains('abort') || t.contains('interrupted')) return;
      if (!silencioso) aviso('No se pudo reproducir la canción. ¿Se borró o movió el archivo?');
    }
  }

  Future<void> reproducirAleatorio(List<SongModel> lista) async {
    final validas = _validas(lista);
    if (validas.isEmpty) return;
    final inicial = validas[Random().nextInt(validas.length)];
    await reproducir(validas, inicial);
    await reproductor.setShuffleModeEnabled(true);
    await reproductor.shuffle();
  }

  Future<void> anterior() async {
    if (reproductor.position.inSeconds > 3 || !reproductor.hasPrevious) {
      await reproductor.seek(Duration.zero);
    } else {
      await reproductor.seekToPrevious();
    }
  }

  Future<void> siguiente() async {
    if (reproductor.hasNext) await reproductor.seekToNext();
  }

  Future<void> alternarAleatorio() async {
    final activar = !reproductor.shuffleModeEnabled;
    if (activar) await reproductor.shuffle();
    await reproductor.setShuffleModeEnabled(activar);
  }

  Future<void> alternarRepeticion() async {
    final nuevo = switch (reproductor.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await reproductor.setLoopMode(nuevo);
  }

  // --- Cola ------------------------------------------------------------------

  Future<void> tocarDespues(List<SongModel> lista) async {
    final validas = _validas(lista);
    if (validas.isEmpty) return;
    final f = _fuente;
    if (f == null || reproductor.audioSource == null) {
      await _cargar(validas, 0);
      return;
    }
    final posicion = (reproductor.currentIndex ?? -1) + 1;
    await f.insertAll(posicion, validas.map(_fuenteDe).toList());
    aviso(validas.length == 1
        ? 'Se reproducirá a continuación.'
        : '${validas.length} canciones se reproducirán a continuación.');
  }

  Future<void> agregarALaCola(List<SongModel> lista) async {
    final validas = _validas(lista);
    if (validas.isEmpty) return;
    final f = _fuente;
    if (f == null || reproductor.audioSource == null) {
      await _cargar(validas, 0);
      return;
    }
    await f.addAll(validas.map(_fuenteDe).toList());
    aviso(validas.length == 1
        ? 'Agregada al final de la cola.'
        : '${validas.length} canciones agregadas a la cola.');
  }

  Future<void> moverEnCola(int viejo, int nuevo) async {
    await _fuente?.move(viejo, nuevo);
  }

  Future<void> quitarDeCola(int indice) async {
    if (cola.value.length <= 1) {
      aviso('La cola no puede quedar vacía.');
      return;
    }
    await _fuente?.removeAt(indice);
  }

  Future<void> saltarACola(int indice) async {
    await reproductor.seek(Duration.zero, index: indice);
    unawaited(reproductor.play());
  }

  // ===========================================================================
  // Favoritos, listas, ocultas
  // ===========================================================================

  Future<void> _guardarFavoritos() =>
      _prefs.setStringList('favoritos_musica', favoritos.map((e) => e.toString()).toList());
  Future<void> _guardarListas() => _prefs.setString('listas_musica', jsonEncode(listas));
  Future<void> _guardarConteos() => _prefs.setString(
      'conteos_musica', jsonEncode(conteos.map((k, v) => MapEntry(k.toString(), v))));
  Future<void> _guardarTiempos() => _prefs.setString(
      'tiempos_musica', jsonEncode(tiempos.map((k, v) => MapEntry(k.toString(), v))));
  Future<void> _guardarOcultas() =>
      _prefs.setStringList('ocultas_musica', ocultas.map((e) => e.toString()).toList());
  Future<void> _guardarLetras() => _prefs.setString(
      'letras_musica', jsonEncode(letras.map((k, v) => MapEntry(k.toString(), v))));

  void alternarFavorito(int id) {
    if (!favoritos.remove(id)) favoritos.add(id);
    favoritosVN.value = Set<int>.from(favoritos);
    _guardarFavoritos();
    _notificar();
  }

  void agregarFavoritos(Iterable<int> ids) {
    favoritos.addAll(ids);
    favoritosVN.value = Set<int>.from(favoritos);
    _guardarFavoritos();
    _notificar();
  }

  bool crearLista(String nombre) {
    final n = nombre.trim();
    if (n.isEmpty || listas.containsKey(n)) return false;
    listas[n] = <int>[];
    _guardarListas();
    _notificar();
    return true;
  }

  bool renombrarLista(String viejo, String nuevo) {
    final n = nuevo.trim();
    if (n.isEmpty || (n != viejo && listas.containsKey(n)) || !listas.containsKey(viejo)) {
      return false;
    }
    final copia = <String, List<int>>{};
    listas.forEach((k, v) => copia[k == viejo ? n : k] = v);
    listas = copia;
    _guardarListas();
    _notificar();
    return true;
  }

  void eliminarLista(String nombre) {
    listas.remove(nombre);
    _guardarListas();
    _notificar();
  }

  int agregarALista(String nombre, Iterable<int> ids) {
    final l = listas[nombre];
    if (l == null) return 0;
    var agregadas = 0;
    for (final id in ids) {
      if (!l.contains(id)) {
        l.add(id);
        agregadas++;
      }
    }
    if (agregadas > 0) {
      _guardarListas();
      _notificar();
    }
    return agregadas;
  }

  void quitarDeLista(String nombre, int id) {
    listas[nombre]?.remove(id);
    _guardarListas();
    _notificar();
  }

  /// Guarda lo que hay en la cola como una lista de reproducción nueva.
  bool guardarColaComoLista(String nombre) {
    if (!crearLista(nombre)) return false;
    agregarALista(nombre, cola.value.map((s) => s.id));
    return true;
  }

  void ocultarCancion(int id) {
    ocultas.add(id);
    _guardarOcultas();
    _aplicarFiltros();
  }

  void mostrarCancion(int id) {
    ocultas.remove(id);
    _guardarOcultas();
    _aplicarFiltros();
  }

  // ===========================================================================
  // Ajustes
  // ===========================================================================

  void setOrden(String nuevo) {
    orden = nuevo;
    _prefs.setString('orden_biblioteca', nuevo);
    _notificar();
  }

  void setAlbumesEnCuadricula(bool v) {
    albumesEnCuadricula = v;
    _prefs.setBool('albumes_cuadricula', v);
    _notificar();
  }

  void setDuracionMinima(int ms) {
    duracionMinimaMs = ms;
    _prefs.setInt('duracion_minima', ms);
    _aplicarFiltros();
  }

  Future<void> setSaltarSilencio(bool v) async {
    saltarSilencio = v;
    _prefs.setBool('saltar_silencio', v);
    _notificar();
    try {
      await reproductor.setSkipSilenceEnabled(v);
    } catch (_) {}
  }

  void setModoTema(int v) {
    modoTema.value = v;
    _prefs.setInt('modo_tema', v);
  }

  void setAmoled(bool v) {
    amoled.value = v;
    _prefs.setBool('amoled', v);
  }

  void setAcentoBase(Color c) {
    acentoBase.value = c;
    _prefs.setInt('color_acento', c.toARGB32());
  }

  void setNotifMantener(bool v) {
    notifMantener = v;
    _prefs.setBool('notif_mantener', v);
    _notificar();
  }

  void setNotifFija(bool v) {
    notifFija = v;
    _prefs.setBool('notif_ongoing', v);
    _notificar();
  }

  void setNotifUsarColor(bool v) {
    notifUsarColor = v;
    _prefs.setBool('notif_usar_color', v);
    _notificar();
  }

  /// Guarda un color elegido por ti (máximo 8) y lo aplica como acento.
  void agregarColorPropio(Color c) {
    coloresPropios.removeWhere((x) => x.toARGB32() == c.toARGB32());
    coloresPropios.insert(0, c);
    if (coloresPropios.length > 8) coloresPropios = coloresPropios.sublist(0, 8);
    _prefs.setStringList(
        'colores_propios', coloresPropios.map((e) => e.toARGB32().toString()).toList());
    setAcentoBase(c);
    _notificar();
  }

  void quitarColorPropio(Color c) {
    coloresPropios.removeWhere((x) => x.toARGB32() == c.toARGB32());
    _prefs.setStringList(
        'colores_propios', coloresPropios.map((e) => e.toARGB32().toString()).toList());
    _notificar();
  }

  void setUsarDinamico(bool v) {
    usarDinamico.value = v;
    _prefs.setBool('acento_dinamico', v);
    if (v) {
      final c = cancionActual.value;
      if (c != null) unawaited(_actualizarAcento(c));
    }
  }

  // ===========================================================================
  // Color según la carátula
  // ===========================================================================

  Future<void> _actualizarAcento(SongModel c) async {
    if (!usarDinamico.value) return;
    if (_cacheColor.containsKey(c.id)) {
      acentoDinamico.value = _cacheColor[c.id];
      return;
    }
    try {
      final propia = caratulasPropias[c.id];
      final bytes = (propia != null && File(propia).existsSync())
          ? await File(propia).readAsBytes()
          : await consulta.queryArtwork(c.id, ArtworkType.AUDIO);
      Color? color;
      if (bytes != null && bytes.isNotEmpty) color = await colorDominante(bytes);
      _cacheColor[c.id] = color;
      if (!_cerrado && cancionActual.value?.id == c.id) acentoDinamico.value = color;
    } catch (_) {}
  }

  // ===========================================================================
  // Ecualizador
  // ===========================================================================

  Future<void> _cargarEcualizador() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final activo = _prefs.getBool('eq_activo') ?? false;
      final guardadas = _prefs.getString('eq_bandas');
      final params = await ecualizador.parameters;
      if (guardadas != null) {
        final lista = (jsonDecode(guardadas) as List).map((e) => (e as num).toDouble()).toList();
        for (var i = 0; i < params.bands.length && i < lista.length; i++) {
          final g = lista[i].clamp(params.minDecibels, params.maxDecibels).toDouble();
          await params.bands[i].setGain(g);
        }
      }
      await ecualizador.setEnabled(activo);
    } catch (_) {}
    try {
      potenciadorDb = _prefs.getDouble('pot_db') ?? 0;
      gravesRef = _prefs.getDouble('graves_ref') ?? 0;
      await potenciador.setTargetGain(potenciadorDb);
      await potenciador.setEnabled(potenciadorDb > 0);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> ajustarPotenciador(double db, {bool guardar = false}) async {
    potenciadorDb = db.clamp(0.0, 12.0).toDouble();
    try {
      await potenciador.setTargetGain(potenciadorDb);
      await potenciador.setEnabled(potenciadorDb > 0);
    } catch (_) {}
    if (guardar) await _prefs.setDouble('pot_db', potenciadorDb);
    notifyListeners();
  }

  Future<void> ajustarGraves(AndroidEqualizerParameters p, double v, {bool guardar = false}) async {
    gravesRef = v.clamp(0.0, 1.0).toDouble();
    try {
      if (gravesRef > 0 && !ecualizador.enabled) {
        await ecualizador.setEnabled(true);
        await guardarEcualizadorActivo(true);
      }
      if (p.bands.isNotEmpty) await p.bands[0].setGain(gravesRef * p.maxDecibels);
      if (p.bands.length > 1) await p.bands[1].setGain(gravesRef * p.maxDecibels * 0.5);
    } catch (_) {}
    if (guardar) {
      await _prefs.setDouble('graves_ref', gravesRef);
      await guardarEcualizador(p);
    }
    notifyListeners();
  }

  Future<void> guardarEcualizador(AndroidEqualizerParameters p, {bool? activo}) async {
    await _prefs.setString('eq_bandas', jsonEncode(p.bands.map((b) => b.gain).toList()));
    if (activo != null) await _prefs.setBool('eq_activo', activo);
  }

  Future<void> guardarEcualizadorActivo(bool activo) => _prefs.setBool('eq_activo', activo);

  // ===========================================================================
  // Temporizador de sueño
  // ===========================================================================

  void programarSueno(Duration d, {bool desvanecer = true}) {
    _timerSueno?.cancel();
    suenoFin.value = DateTime.now().add(d);
    _timerSueno = Timer(d, () => _terminarSueno(desvanecer));
  }

  bool programarSuenoFinDeCancion() {
    final dur = reproductor.duration;
    if (dur == null) return false;
    var resto = dur - reproductor.position;
    if (resto.isNegative) resto = Duration.zero;
    programarSueno(resto, desvanecer: false);
    return true;
  }

  void cancelarSueno() {
    _timerSueno?.cancel();
    _timerSueno = null;
    suenoFin.value = null;
  }

  Future<void> _terminarSueno(bool desvanecer) async {
    suenoFin.value = null;
    _desvaneciendoSueno = true;
    try {
      if (desvanecer) {
        for (var i = 9; i >= 0; i--) {
          await reproductor.setVolume(i / 10);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
      await reproductor.pause();
      await reproductor.setVolume(1.0);
      _volAplicado = 1.0;
    } catch (_) {
    } finally {
      _desvaneciendoSueno = false;
    }
  }

  // Saltar X segundos (doble toque en la carátula)
  Future<void> saltar(int segundos) async {
    try {
      final dur = reproductor.duration ?? Duration.zero;
      var destino = reproductor.position + Duration(seconds: segundos);
      if (destino < Duration.zero) destino = Duration.zero;
      if (dur > Duration.zero && destino > dur) destino = dur;
      await reproductor.seek(destino);
    } catch (_) {}
  }

  // Listas inteligentes -------------------------------------------------------
  List<SongModel> get listaNuncaEscuchadas =>
      canciones.where((s) => (conteos[s.id] ?? 0) == 0).toList();

  List<SongModel> get listaNuevas30Dias {
    final limite = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
    final l = canciones.where((s) => (s.dateAdded ?? 0) >= limite).toList()
      ..sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return l;
  }

  List<SongModel> get listaTopEscuchadas {
    final e = conteos.entries.where((x) => x.value > 0 && porId.containsKey(x.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return e.take(50).map((x) => porId[x.key]!).toList();
  }

  List<SongModel> get listaOlvidadas {
    final rec = recientes.take(40).toSet();
    return canciones.where((s) => (conteos[s.id] ?? 0) > 0 && !rec.contains(s.id)).toList();
  }

  List<SongModel> get listaLargas =>
      canciones.where((s) => (s.duration ?? 0) >= 6 * 60 * 1000).toList();

  List<SongModel> get listaCortas =>
      canciones.where((s) => (s.duration ?? 0) > 0 && (s.duration ?? 0) <= 2 * 60 * 1000).toList();

  // ===========================================================================
  // Letras
  // ===========================================================================

  Future<String?> letraDe(SongModel c) async {
    final guardada = letras[c.id];
    if (guardada != null && guardada.trim().isNotEmpty) return guardada;
    try {
      final ruta = c.data;
      final punto = ruta.lastIndexOf('.');
      if (punto > 0) {
        final archivo = File('${ruta.substring(0, punto)}.lrc');
        if (await archivo.exists()) {
          return utf8.decode(await archivo.readAsBytes(), allowMalformed: true);
        }
      }
    } catch (_) {}
    return null;
  }

  void guardarLetra(int id, String texto) {
    if (texto.trim().isEmpty) {
      letras.remove(id);
    } else {
      letras[id] = texto;
    }
    _guardarLetras();
    _notificar();
  }

  // ===========================================================================
  // Copia de seguridad
  // ===========================================================================

  String exportarCopia() {
    return jsonEncode(<String, dynamic>{
      'version': 2,
      'favoritos': favoritos.toList(),
      'listas': listas,
      'conteos': conteos.map((k, v) => MapEntry(k.toString(), v)),
      'tiempos': tiempos.map((k, v) => MapEntry(k.toString(), v)),
      'recientes': recientes,
      'ocultas': ocultas.toList(),
      'letras': letras.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  Future<bool> importarCopia(String texto) async {
    try {
      final datos = jsonDecode(texto) as Map<String, dynamic>;

      final favs = (datos['favoritos'] as List? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();

      final nuevasListas = <String, List<int>>{};
      final rawListas = datos['listas'] as Map<String, dynamic>? ?? <String, dynamic>{};
      rawListas.forEach((nombre, ids) {
        nuevasListas[nombre] = (ids as List).map((e) => (e as num).toInt()).toList();
      });

      final nuevosConteos = <int, int>{};
      final rawConteos = datos['conteos'] as Map<String, dynamic>? ?? <String, dynamic>{};
      rawConteos.forEach((k, v) => nuevosConteos[int.parse(k)] = (v as num).toInt());

      final nuevosTiempos = <int, int>{};
      final rawTiempos = datos['tiempos'] as Map<String, dynamic>? ?? <String, dynamic>{};
      rawTiempos.forEach((k, v) => nuevosTiempos[int.parse(k)] = (v as num).toInt());

      final nuevosRecientes = (datos['recientes'] as List? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toList();
      final nuevasOcultas = (datos['ocultas'] as List? ?? <dynamic>[])
          .map((e) => (e as num).toInt())
          .toSet();

      final nuevasLetras = <int, String>{};
      final rawLetras = datos['letras'] as Map<String, dynamic>? ?? <String, dynamic>{};
      rawLetras.forEach((k, v) => nuevasLetras[int.parse(k)] = v as String);

      favoritos = favs;
      favoritosVN.value = Set<int>.from(favoritos);
      listas = nuevasListas;
      conteos = nuevosConteos;
      tiempos = nuevosTiempos;
      recientes = nuevosRecientes;
      ocultas = nuevasOcultas;
      letras = nuevasLetras;

      await _guardarFavoritos();
      await _guardarListas();
      await _guardarConteos();
      await _guardarTiempos();
      await _guardarOcultas();
      await _guardarLetras();
      await _prefs.setStringList('recientes_musica', recientes.map((e) => e.toString()).toList());

      _aplicarFiltros();
      return true;
    } catch (_) {
      return false;
    }
  }
}
