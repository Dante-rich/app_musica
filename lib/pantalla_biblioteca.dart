import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import 'componentes.dart';
import 'motor.dart';
import 'utilidades.dart';

enum TipoDetalle { ninguno, album, artista, genero, carpeta, lista }

class PantallaBiblioteca extends StatefulWidget {
  final MotorMusica motor;

  const PantallaBiblioteca({super.key, required this.motor});

  @override
  State<PantallaBiblioteca> createState() => EstadoBiblioteca();
}

class EstadoBiblioteca extends State<PantallaBiblioteca> {
  static const List<String> secciones = [
    'Canciones',
    'Álbumes',
    'Artistas',
    'Géneros',
    'Carpetas',
    'Favoritos',
    'Listas',
  ];

  final TextEditingController _buscador = TextEditingController();
  final ScrollController _scrollCanciones = ScrollController();
  final ScrollController _scrollGrid = ScrollController();
  final Set<int> _seleccion = <int>{};

  String _seccion = 'Canciones';
  TipoDetalle _detalle = TipoDetalle.ninguno;
  String? _clave;
  String _busqueda = '';

  MotorMusica get motor => widget.motor;
  bool get _enDetalle => _detalle != TipoDetalle.ninguno;

  @override
  void dispose() {
    _buscador.dispose();
    _scrollCanciones.dispose();
    _scrollGrid.dispose();
    super.dispose();
  }

  /// Lo llama la pantalla principal al pulsar "atrás". Devuelve true si
  /// manejó el gesto (cerró una selección o un detalle).
  bool retroceder() {
    if (_seleccion.isNotEmpty) {
      setState(_seleccion.clear);
      return true;
    }
    if (_enDetalle) {
      setState(() {
        _detalle = TipoDetalle.ninguno;
        _clave = null;
      });
      return true;
    }
    return false;
  }

  void _abrirDetalle(TipoDetalle tipo, String clave) {
    setState(() {
      _detalle = tipo;
      _clave = clave;
      _seleccion.clear();
    });
  }

  void _alternarSeleccion(int id) {
    setState(() {
      if (!_seleccion.remove(id)) _seleccion.add(id);
    });
  }

  // ---------------------------------------------------------------------------
  // Datos
  // ---------------------------------------------------------------------------

  void _ordenar(List<SongModel> l) {
    switch (motor.orden) {
      case 'Artista':
        l.sort((a, b) => artistaDe(a).toLowerCase().compareTo(artistaDe(b).toLowerCase()));
        break;
      case 'Recientes':
        l.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
      case 'Duración':
        l.sort((a, b) => (a.duration ?? 0).compareTo(b.duration ?? 0));
        break;
      case 'Más escuchadas':
        l.sort((a, b) => (motor.conteos[b.id] ?? 0).compareTo(motor.conteos[a.id] ?? 0));
        break;
      default:
        break;
    }
  }

  List<SongModel> _filtrarBusqueda(Iterable<SongModel> base) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return base.toList();
    return base
        .where((s) => coincide('${s.title} ${artistaDe(s)} ${albumDe(s)}', q))
        .toList();
  }

  List<SongModel> _cancionesDelDetalle() {
    switch (_detalle) {
      case TipoDetalle.album:
        return motor.albumes[_clave] ?? <SongModel>[];
      case TipoDetalle.artista:
        final l = List<SongModel>.of(motor.artistas[_clave] ?? <SongModel>[]);
        _ordenar(l);
        return l;
      case TipoDetalle.genero:
        final l = List<SongModel>.of(motor.generos[_clave] ?? <SongModel>[]);
        _ordenar(l);
        return l;
      case TipoDetalle.carpeta:
        final l = List<SongModel>.of(motor.carpetas[_clave] ?? <SongModel>[]);
        _ordenar(l);
        return l;
      case TipoDetalle.lista:
        final ids = motor.listas[_clave] ?? <int>[];
        return ids.map((id) => motor.porId[id]).whereType<SongModel>().toList();
      case TipoDetalle.ninguno:
        return <SongModel>[];
    }
  }

  List<SongModel> _cancionesVisibles() {
    if (_enDetalle) return _cancionesDelDetalle();
    if (_seccion == 'Canciones' || _seccion == 'Favoritos') {
      final base = _seccion == 'Favoritos' ? motor.cancionesFavoritas : motor.canciones;
      final l = _filtrarBusqueda(base);
      _ordenar(l);
      return l;
    }
    return <SongModel>[];
  }

  String _tituloDetalle() {
    if (_detalle == TipoDetalle.carpeta) return nombreCarpeta(_clave ?? '');
    return _clave ?? '';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[motor, motor.cancionActual]),
      builder: (context, _) {
        final visibles = _cancionesVisibles();
        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _barraSuperior(context, visibles),
              if (!_enDetalle) ...[
                _campoBusqueda(),
                SizedBox(
                  height: 48,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    children: [for (final s in secciones) _chip(context, s)],
                  ),
                ),
              ],
              Expanded(child: _contenido(context, visibles)),
            ],
          ),
        );
      },
    );
  }

  Widget _barraSuperior(BuildContext context, List<SongModel> visibles) {
    final acento = context.acento;

    if (_seleccion.isNotEmpty) {
      final elegidas = _seleccion.map((id) => motor.porId[id]).whereType<SongModel>().toList();
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cancelar',
              onPressed: () => setState(_seleccion.clear),
              icon: const Icon(Icons.close_rounded),
            ),
            Expanded(
              child: Text(
                '${_seleccion.length} seleccionadas',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            IconButton(
              tooltip: 'Seleccionar todo',
              onPressed: () => setState(() => _seleccion.addAll(visibles.map((s) => s.id))),
              icon: const Icon(Icons.select_all_rounded),
            ),
            IconButton(
              tooltip: 'Favoritos',
              onPressed: () {
                motor.agregarFavoritos(_seleccion);
                setState(_seleccion.clear);
                motor.aviso('Agregadas a favoritos.');
              },
              icon: const Icon(Icons.favorite_border_rounded),
            ),
            IconButton(
              tooltip: 'Agregar a la cola',
              onPressed: () {
                motor.agregarALaCola(elegidas);
                setState(_seleccion.clear);
              },
              icon: const Icon(Icons.queue_rounded),
            ),
            IconButton(
              tooltip: 'Agregar a una lista',
              onPressed: () async {
                await mostrarAgregarALista(context, motor, elegidas);
                if (mounted) setState(_seleccion.clear);
              },
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          if (_enDetalle)
            IconButton(onPressed: retroceder, icon: const Icon(Icons.arrow_back_rounded))
          else
            Icon(Icons.graphic_eq_rounded, color: acento, size: 29),
          SizedBox(width: _enDetalle ? 4 : 10),
          Expanded(
            child: Text(
              _enDetalle ? _tituloDetalle() : kNombreApp,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          if (!_enDetalle)
            IconButton(
              tooltip: 'Actualizar biblioteca',
              onPressed: motor.cargarCanciones,
              icon: motor.cargando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: acento),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }

  Widget _campoBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: _buscador,
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar canciones, álbumes o artistas...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _busqueda.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _buscador.clear();
                    setState(() => _busqueda = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: context.panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String nombre) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: ChoiceChip(
        label: Text(nombre),
        selected: _seccion == nombre,
        selectedColor: context.acento.withValues(alpha: 0.28),
        onSelected: (_) => setState(() {
          _seccion = nombre;
          _seleccion.clear();
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Contenido
  // ---------------------------------------------------------------------------

  Widget _contenido(BuildContext context, List<SongModel> visibles) {
    if (motor.cargando && motor.canciones.isEmpty) {
      return Center(child: CircularProgressIndicator(color: context.acento));
    }
    if (motor.canciones.isEmpty) return _estadoVacio(context);
    if (_enDetalle) return _vistaDetalle(context, visibles);

    switch (_seccion) {
      case 'Álbumes':
        return _vistaAlbumes(context);
      case 'Artistas':
        return _vistaArtistas(context);
      case 'Géneros':
        return _vistaGeneros(context);
      case 'Carpetas':
        return _vistaCarpetas(context);
      case 'Listas':
        return _vistaListas(context);
      default:
        if (visibles.isEmpty) return _sinResultados();
        return _listaCanciones(visibles, mostrarOrden: true);
    }
  }

  Widget _sinResultados() => Center(
        child: Text('No hay elementos para mostrar.', style: TextStyle(color: tSuave)),
      );

  Widget _estadoVacio(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music_outlined, size: 76, color: context.acento),
            const SizedBox(height: 18),
            const Text('Tu música aparecerá aquí',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              motor.permisoDenegado
                  ? 'Permite el acceso a los archivos de audio y vuelve a intentar.'
                  : 'No encontré canciones. Revisa que tengas música en el teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tSuave),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: motor.cargarCanciones,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Volver a intentar'),
            ),
            if (motor.permisoDenegado)
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Abrir ajustes del teléfono'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cabeceraSimple(String texto, [Widget? accion]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: TextStyle(color: tSuave))),
          if (accion != null) accion,
        ],
      ),
    );
  }

  // --- Canciones -------------------------------------------------------------

  Widget _listaCanciones(
    List<SongModel> lista, {
    String? listaNombre,
    bool mostrarOrden = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('${lista.length} canciones',
                    style: TextStyle(color: tSuave)),
              ),
              if (mostrarOrden)
                PopupMenuButton<String>(
                  tooltip: 'Ordenar',
                  icon: const Icon(Icons.sort_rounded),
                  onSelected: motor.setOrden,
                  itemBuilder: (_) => [
                    for (final o in ['Título', 'Artista', 'Recientes', 'Duración', 'Más escuchadas'])
                      CheckedPopupMenuItem<String>(
                        value: o,
                        checked: motor.orden == o,
                        child: Text(o),
                      ),
                  ],
                ),
              IconButton.filledTonal(
                tooltip: 'Reproducir en aleatorio',
                onPressed: () => motor.reproducirAleatorio(lista),
                icon: const Icon(Icons.shuffle_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Reproducir todo',
                onPressed: () => motor.reproducir(lista, lista.first),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollCanciones,
            interactive: true,
            child: ListView.builder(
              controller: _scrollCanciones,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final c = lista[i];
                return FilaCancion(
                  key: ValueKey('fila_${c.id}'),
                  motor: motor,
                  cancion: c,
                  contexto: lista,
                  seleccionada: _seleccion.contains(c.id),
                  modoSeleccion: _seleccion.isNotEmpty,
                  alAlternarSeleccion: () => _alternarSeleccion(c.id),
                  alMantener: () {
                    HapticFeedback.selectionClick();
                    _alternarSeleccion(c.id);
                  },
                  listaActual: listaNombre,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Álbumes ---------------------------------------------------------------

  Widget _vistaAlbumes(BuildContext context) {
    final q = _busqueda.trim().toLowerCase();
    final claves = motor.albumes.keys
        .where((a) =>
            q.isEmpty ||
            coincide('$a ${artistaDe(motor.albumes[a]!.first)}', q))
        .toList();
    if (claves.isEmpty) return _sinResultados();

    final cuadricula = motor.albumesEnCuadricula;
    return Column(
      children: [
        _cabeceraSimple(
          '${claves.length} álbumes',
          IconButton(
            tooltip: cuadricula ? 'Ver como lista' : 'Ver como cuadrícula',
            onPressed: () => motor.setAlbumesEnCuadricula(!cuadricula),
            icon: Icon(cuadricula ? Icons.view_list_rounded : Icons.grid_view_rounded),
          ),
        ),
        Expanded(
          child: cuadricula
              ? GridView.builder(
                  controller: _scrollGrid,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: claves.length,
                  itemBuilder: (context, i) {
                    final nombre = claves[i];
                    final l = motor.albumes[nombre]!;
                    return TarjetaAlbum(
                      portada: l.first,
                      titulo: nombre,
                      subtitulo: '${artistaDe(l.first)} · ${l.length}',
                      alTocar: () => _abrirDetalle(TipoDetalle.album, nombre),
                    );
                  },
                )
              : ListView.builder(
                  itemCount: claves.length,
                  itemBuilder: (context, i) {
                    final nombre = claves[i];
                    final l = motor.albumes[nombre]!;
                    return ListTile(
                      leading: caratula(l.first, 54, context.acento),
                      title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${artistaDe(l.first)} · ${l.length} canciones'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _abrirDetalle(TipoDetalle.album, nombre),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Artistas --------------------------------------------------------------

  Widget _vistaArtistas(BuildContext context) {
    final q = _busqueda.trim().toLowerCase();
    final claves =
        motor.artistas.keys.where((a) => q.isEmpty || coincide(a, q)).toList();
    if (claves.isEmpty) return _sinResultados();
    return ListView.builder(
      itemCount: claves.length,
      itemBuilder: (context, i) {
        final nombre = claves[i];
        final l = motor.artistas[nombre]!;
        return ListTile(
          leading: caratula(l.first, 54, context.acento, radio: 27),
          title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${l.length} canciones'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _abrirDetalle(TipoDetalle.artista, nombre),
        );
      },
    );
  }

  // --- Carpetas --------------------------------------------------------------

  Widget _vistaGeneros(BuildContext context) {
    final q = _busqueda.trim().toLowerCase();
    final claves =
        motor.generos.keys.where((g) => q.isEmpty || coincide(g, q)).toList();
    if (claves.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tus canciones no tienen género en sus etiquetas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tSuave),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: claves.length,
      itemBuilder: (context, i) {
        final nombre = claves[i];
        final l = motor.generos[nombre]!;
        return ListTile(
          leading: caratula(l.first, 54, context.acento),
          title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${l.length} canciones'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _abrirDetalle(TipoDetalle.genero, nombre),
        );
      },
    );
  }

  Widget _vistaCarpetas(BuildContext context) {
    final q = _busqueda.trim().toLowerCase();
    final claves = motor.carpetas.keys
        .where((k) => q.isEmpty || coincide(nombreCarpeta(k), q))
        .toList();
    if (claves.isEmpty) return _sinResultados();
    return ListView.builder(
      itemCount: claves.length,
      itemBuilder: (context, i) {
        final ruta = claves[i];
        final l = motor.carpetas[ruta]!;
        return ListTile(
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.acento.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.folder_rounded, color: context.acento),
          ),
          title: Text(nombreCarpeta(ruta), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${l.length} canciones · $ruta', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _abrirDetalle(TipoDetalle.carpeta, ruta),
        );
      },
    );
  }

  // --- Listas de reproducción --------------------------------------------------

  Future<void> _crearLista() async {
    final nombre = await pedirTexto(
      context,
      titulo: 'Nueva lista de reproducción',
      etiqueta: 'Nombre de la lista',
      hint: 'Por ejemplo: Para entrenar',
      textoBoton: 'Crear',
    );
    if (!mounted || nombre == null || nombre.isEmpty) return;
    if (motor.crearLista(nombre)) {
      motor.aviso('Lista "$nombre" creada.');
    } else {
      motor.aviso('Ya existe una lista con ese nombre.');
    }
  }

  Future<void> _renombrarLista(String viejo) async {
    final nuevo = await pedirTexto(
      context,
      titulo: 'Renombrar lista',
      etiqueta: 'Nuevo nombre',
      inicial: viejo,
      textoBoton: 'Guardar',
    );
    if (!mounted || nuevo == null || nuevo.isEmpty || nuevo == viejo) return;
    if (motor.renombrarLista(viejo, nuevo)) {
      if (_clave == viejo) setState(() => _clave = nuevo);
    } else {
      motor.aviso('No se pudo renombrar (¿ya existe ese nombre?).');
    }
  }

  Future<void> _eliminarLista(String nombre) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar lista',
      texto: '¿Quieres eliminar la lista "$nombre"?',
      textoBoton: 'Eliminar',
    );
    if (!ok || !mounted) return;
    motor.eliminarLista(nombre);
    if (_detalle == TipoDetalle.lista && _clave == nombre) {
      setState(() {
        _detalle = TipoDetalle.ninguno;
        _clave = null;
      });
    }
  }

  Widget _vistaListas(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _crearLista,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear lista de reproducción'),
            ),
          ),
        ),
        Expanded(
          child: motor.listas.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Todavía no tienes listas.\nCrea una para organizar tu música.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tSuave),
                    ),
                  ),
                )
              : ListView(
                  children: motor.listas.keys.map((nombre) {
                    final ids = motor.listas[nombre] ?? <int>[];
                    final canciones =
                        ids.map((id) => motor.porId[id]).whereType<SongModel>().toList();
                    return ListTile(
                      leading: canciones.isNotEmpty
                          ? caratula(canciones.first, 52, context.acento, radio: 12)
                          : Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: context.acento.withValues(alpha: 0.17),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.queue_music_rounded, color: context.acento),
                            ),
                      title: Text(nombre),
                      subtitle: Text('${canciones.length} canciones'),
                      onTap: () => _abrirDetalle(TipoDetalle.lista, nombre),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) {
                          if (op == 'reproducir' && canciones.isNotEmpty) {
                            motor.reproducir(canciones, canciones.first);
                          } else if (op == 'renombrar') {
                            _renombrarLista(nombre);
                          } else if (op == 'eliminar') {
                            _eliminarLista(nombre);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'reproducir', child: Text('Reproducir')),
                          PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
                          PopupMenuItem(value: 'eliminar', child: Text('Eliminar lista')),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // --- Detalle (álbum, artista, carpeta o lista) -------------------------------

  Widget _vistaDetalle(BuildContext context, List<SongModel> lista) {
    final acento = context.acento;
    var subtitulo = '${lista.length} canciones · ${formatoDuracionLarga(duracionTotal(lista))}';
    if (_detalle == TipoDetalle.album && lista.isNotEmpty) {
      subtitulo = '${artistaDe(lista.first)}\n$subtitulo';
    }

    final Widget portada = lista.isNotEmpty && _detalle != TipoDetalle.carpeta
        ? caratula(lista.first, 104, acento, radio: 16, size: 400)
        : Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: acento.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _detalle == TipoDetalle.carpeta ? Icons.folder_rounded : Icons.queue_music_rounded,
              color: acento,
              size: 48,
            ),
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              portada,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tituloDetalle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitulo, style: TextStyle(color: tSuave, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: lista.isEmpty ? null : () => motor.reproducir(lista, lista.first),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Reproducir'),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Aleatorio',
                          onPressed: lista.isEmpty ? null : () => motor.reproducirAleatorio(lista),
                          icon: const Icon(Icons.shuffle_rounded),
                        ),
                        if (_detalle == TipoDetalle.lista)
                          PopupMenuButton<String>(
                            onSelected: (op) {
                              if (op == 'renombrar') _renombrarLista(_clave!);
                              if (op == 'eliminar') _eliminarLista(_clave!);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
                              PopupMenuItem(value: 'eliminar', child: Text('Eliminar lista')),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Text('Esta lista está vacía.', style: TextStyle(color: tSuave)),
                )
              : _listaCanciones(
                  lista,
                  listaNombre: _detalle == TipoDetalle.lista ? _clave : null,
                ),
        ),
      ],
    );
  }
}
