import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'motor.dart';
import 'utilidades.dart';

/// Abre la pantalla para editar título, artista, álbum y carátula de una canción.
/// Los cambios se guardan dentro de la app (el archivo de música no se modifica).
Future<void> mostrarEditorEtiquetas(
  BuildContext context,
  MotorMusica motor,
  SongModel cancion,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PantallaEditorEtiquetas(motor: motor, cancion: cancion),
    ),
  );
}

class PantallaEditorEtiquetas extends StatefulWidget {
  final MotorMusica motor;
  final SongModel cancion;

  const PantallaEditorEtiquetas({super.key, required this.motor, required this.cancion});

  @override
  State<PantallaEditorEtiquetas> createState() => _EstadoEditor();
}

class _EstadoEditor extends State<PantallaEditorEtiquetas> {
  late final TextEditingController _titulo;
  late final TextEditingController _artista;
  late final TextEditingController _album;
  String? _imagenNueva; // ruta temporal de la imagen elegida
  bool _quitarImagen = false;
  bool _guardando = false;

  MotorMusica get motor => widget.motor;
  SongModel get cancion => widget.cancion;

  @override
  void initState() {
    super.initState();
    final a = artistaDe(cancion);
    final al = albumDe(cancion);
    _titulo = TextEditingController(text: cancion.title);
    _artista = TextEditingController(text: a == 'Artista desconocido' ? '' : a);
    _album = TextEditingController(text: al == 'Álbum desconocido' ? '' : al);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _artista.dispose();
    _album.dispose();
    super.dispose();
  }

  Future<void> _elegirImagen() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 88,
      );
      if (x == null || !mounted) return;
      setState(() {
        _imagenNueva = x.path;
        _quitarImagen = false;
      });
    } catch (e) {
      motor.aviso('No se pudo abrir la galería: $e');
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await motor.guardarEtiquetas(
        cancion.id,
        titulo: _titulo.text,
        artista: _artista.text,
        album: _album.text,
      );
      if (_imagenNueva != null) {
        await motor.establecerCaratula(cancion.id, _imagenNueva!);
      } else if (_quitarImagen) {
        await motor.quitarCaratula(cancion.id);
      }
      motor.aviso('Cambios guardados.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      motor.aviso('No se pudo guardar: $e');
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _restablecer() async {
    await motor.guardarEtiquetas(cancion.id); // sin valores = vuelve al original
    if (caratulasPropias.containsKey(cancion.id)) {
      await motor.quitarCaratula(cancion.id);
    }
    motor.aviso('Se restauraron los datos originales.');
    if (mounted) Navigator.of(context).pop();
  }

  Widget _vistaCaratula(Color acento) {
    const lado = 190.0;
    if (_imagenNueva != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(File(_imagenNueva!), width: lado, height: lado, fit: BoxFit.cover),
      );
    }
    if (_quitarImagen) {
      return Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          color: const Color(0xFF29232F),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.music_note_rounded, color: acento, size: lado * 0.45),
      );
    }
    return caratula(cancion, lado, acento, radio: 18, size: 500, quality: 90);
  }

  @override
  Widget build(BuildContext context) {
    final acento = context.acento;
    final tienePropia = caratulasPropias.containsKey(cancion.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar canción'),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: _vistaCaratula(acento)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _elegirImagen,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Elegir imagen'),
              ),
              if (_imagenNueva != null || (tienePropia && !_quitarImagen))
                TextButton.icon(
                  onPressed: () => setState(() {
                    _imagenNueva = null;
                    _quitarImagen = tienePropia;
                  }),
                  icon: const Icon(Icons.hide_image_outlined),
                  label: const Text('Quitar mi carátula'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _titulo,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _artista,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Artista',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _album,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Álbum',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Los cambios se guardan dentro de la app. El archivo de música original no se modifica. '
            'La notificación se actualiza la próxima vez que cargues la canción.',
            style: TextStyle(color: tSuave, fontSize: 12),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: _restablecer,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restablecer datos originales'),
          ),
        ],
      ),
    );
  }
}
