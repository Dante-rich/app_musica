import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'componentes.dart';
import 'motor.dart';
import 'utilidades.dart';

/// Búsqueda global: canciones, artistas, álbumes y carpetas a la vez.
/// Ignora acentos y mayúsculas, y acepta varias palabras en cualquier orden.
class PantallaBusqueda extends StatefulWidget {
  final MotorMusica motor;

  const PantallaBusqueda({super.key, required this.motor});

  @override
  State<PantallaBusqueda> createState() => _PantallaBusquedaState();
}

class _PantallaBusquedaState extends State<PantallaBusqueda> {
  final TextEditingController _texto = TextEditingController();
  String _q = '';

  MotorMusica get motor => widget.motor;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _abrirLista(String titulo, List<SongModel> lista) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: ListView.builder(
          itemCount: lista.length,
          itemBuilder: (context, i) =>
              FilaCancion(motor: motor, cancion: lista[i], contexto: lista),
        ),
      ),
    ));
  }

  Widget _titulo(String t, int n) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Text('$t · $n',
            style: TextStyle(fontWeight: FontWeight.bold, color: context.acento)),
      );

  @override
  Widget build(BuildContext context) {
    final hay = _q.trim().isNotEmpty;
    final canciones = !hay
        ? <SongModel>[]
        : motor.canciones
            .where((s) => coincide('${s.title} ${artistaDe(s)} ${albumDe(s)}', _q))
            .toList();
    final artistas =
        !hay ? <String>[] : motor.artistas.keys.where((a) => coincide(a, _q)).toList();
    final albumes = !hay
        ? <String>[]
        : motor.albumes.keys
            .where((a) => coincide('$a ${artistaDe(motor.albumes[a]!.first)}', _q))
            .toList();
    final carpetas = !hay
        ? <String>[]
        : motor.carpetas.keys.where((k) => coincide(nombreCarpeta(k), _q)).toList();
    final vacio = hay && canciones.isEmpty && artistas.isEmpty && albumes.isEmpty && carpetas.isEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _texto,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Buscar en toda tu música…',
            border: InputBorder.none,
            suffixIcon: hay
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _texto.clear();
                      setState(() => _q = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: !hay
          ? Center(
              child: Text('Escribe para buscar canciones, artistas,\nálbumes o carpetas.',
                  textAlign: TextAlign.center, style: TextStyle(color: tSuave)),
            )
          : vacio
              ? Center(child: Text('Sin resultados para "$_q".', style: TextStyle(color: tSuave)))
              : ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (artistas.isNotEmpty) ...[
                      _titulo('Artistas', artistas.length),
                      for (final a in artistas.take(5))
                        ListTile(
                          leading: caratula(motor.artistas[a]!.first, 48, context.acento),
                          title: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${motor.artistas[a]!.length} canciones'),
                          onTap: () => _abrirLista(a, motor.artistas[a]!),
                        ),
                    ],
                    if (albumes.isNotEmpty) ...[
                      _titulo('Álbumes', albumes.length),
                      for (final a in albumes.take(5))
                        ListTile(
                          leading: caratula(motor.albumes[a]!.first, 48, context.acento),
                          title: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(artistaDe(motor.albumes[a]!.first)),
                          onTap: () => _abrirLista(a, motor.albumes[a]!),
                        ),
                    ],
                    if (carpetas.isNotEmpty) ...[
                      _titulo('Carpetas', carpetas.length),
                      for (final k in carpetas.take(5))
                        ListTile(
                          leading: Icon(Icons.folder_rounded, color: context.acento),
                          title: Text(nombreCarpeta(k), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${motor.carpetas[k]!.length} canciones'),
                          onTap: () => _abrirLista(nombreCarpeta(k), motor.carpetas[k]!),
                        ),
                    ],
                    if (canciones.isNotEmpty) ...[
                      _titulo('Canciones', canciones.length),
                      for (final s in canciones.take(60))
                        FilaCancion(motor: motor, cancion: s, contexto: canciones),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
