import 'package:flutter/material.dart';

import 'componentes.dart';
import 'motor.dart';
import 'utilidades.dart';

/// Resumen de lo que más escuchas, calculado con el conteo de reproducciones.
class PantallaEstadisticas extends StatelessWidget {
  final MotorMusica motor;

  const PantallaEstadisticas({super.key, required this.motor});

  List<MapEntry<String, int>> _top(Map<String, int> m) {
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu resumen')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          if (motor.conteos.isEmpty && motor.tiempoTotalMs == 0) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Todavía no hay datos.\nEscucha algunas canciones (más de 20 segundos cada una) y tu resumen aparecerá aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tSuave),
                ),
              ),
            );
          }

          final porArtista = <String, int>{};
          final porAlbum = <String, int>{};
          motor.conteos.forEach((id, veces) {
            final s = motor.porId[id];
            if (s == null) return;
            porArtista[artistaDe(s)] = (porArtista[artistaDe(s)] ?? 0) + veces;
            porAlbum[albumDe(s)] = (porAlbum[albumDe(s)] ?? 0) + veces;
          });

          final topCanciones = motor.masEscuchadas.take(10).toList();
          final topArtistas = _top(porArtista);
          final topAlbumes = _top(porAlbum);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Tarjeta(
                      valor: '${motor.reproduccionesTotales}',
                      etiqueta: 'reproducciones',
                      icono: Icons.play_circle_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tarjeta(
                      valor: formatoDuracionLarga(Duration(milliseconds: motor.tiempoTotalMs)),
                      etiqueta: 'escuchados',
                      icono: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Tarjeta(
                      valor: '${motor.conteos.length}',
                      etiqueta: 'canciones distintas',
                      icono: Icons.music_note_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tarjeta(
                      valor: '${motor.favoritos.length}',
                      etiqueta: 'favoritas',
                      icono: Icons.favorite_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _titulo('Canciones más escuchadas'),
              const SizedBox(height: 6),
              for (var i = 0; i < topCanciones.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 74,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.acento,
                            ),
                          ),
                        ),
                        caratula(topCanciones[i], 48, context.acento),
                      ],
                    ),
                  ),
                  title: Text(topCanciones[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(artistaDe(topCanciones[i]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    '${motor.conteos[topCanciones[i].id] ?? 0}×',
                    style: TextStyle(color: tSuave),
                  ),
                  onTap: () => tocarCancion(context, motor, topCanciones, topCanciones[i]),
                ),
              const SizedBox(height: 22),
              _titulo('Artistas más escuchados'),
              const SizedBox(height: 8),
              _ranking(context, topArtistas),
              const SizedBox(height: 22),
              _titulo('Álbumes más escuchados'),
              const SizedBox(height: 8),
              _ranking(context, topAlbumes),
            ],
          );
        },
      ),
    );
  }

  Widget _titulo(String texto) => Text(
        texto,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      );

  Widget _ranking(BuildContext context, List<MapEntry<String, int>> datos) {
    if (datos.isEmpty) return const SizedBox.shrink();
    final maximo = datos.first.value.toDouble();
    return Column(
      children: [
        for (final e in datos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maximo == 0 ? 0 : e.value / maximo,
                          minHeight: 6,
                          color: context.acento,
                          backgroundColor: tLinea,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text('${e.value}×', style: TextStyle(color: tSuave)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final IconData icono;

  const _Tarjeta({required this.valor, required this.etiqueta, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.panelElevado,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: context.acento),
          const SizedBox(height: 10),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(etiqueta, style: TextStyle(color: tSuave, fontSize: 12)),
        ],
      ),
    );
  }
}
