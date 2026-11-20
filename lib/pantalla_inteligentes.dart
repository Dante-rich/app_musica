import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'componentes.dart';
import 'motor.dart';
import 'utilidades.dart';

class PantallaInteligentes extends StatelessWidget {
  final MotorMusica motor;

  const PantallaInteligentes({super.key, required this.motor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listas inteligentes')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          final listas = <_Inteligente>[
            _Inteligente('Nunca escuchadas', Icons.new_releases_outlined, motor.listaNuncaEscuchadas),
            _Inteligente('Nuevas (últimos 30 días)', Icons.fiber_new_rounded, motor.listaNuevas30Dias),
            _Inteligente('Top 50 más escuchadas', Icons.emoji_events_outlined, motor.listaTopEscuchadas),
            _Inteligente('Olvidadas', Icons.history_toggle_off_rounded, motor.listaOlvidadas),
            _Inteligente('Favoritas', Icons.favorite_border_rounded, motor.cancionesFavoritas),
            _Inteligente('Largas (más de 6 min)', Icons.timelapse_rounded, motor.listaLargas),
            _Inteligente('Cortas (menos de 2 min)', Icons.bolt_rounded, motor.listaCortas),
          ];
          return ListView(
            children: [
              for (final l in listas)
                ListTile(
                  leading: Icon(l.icono, color: context.acento),
                  title: Text(l.titulo),
                  subtitle: Text('${l.canciones.length} canciones'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: l.canciones.isNotEmpty,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _DetalleLista(motor: motor, lista: l))),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Inteligente {
  final String titulo;
  final IconData icono;
  final List<SongModel> canciones;
  _Inteligente(this.titulo, this.icono, this.canciones);
}

class _DetalleLista extends StatelessWidget {
  final MotorMusica motor;
  final _Inteligente lista;

  const _DetalleLista({required this.motor, required this.lista});

  @override
  Widget build(BuildContext context) {
    final c = lista.canciones;
    return Scaffold(
      appBar: AppBar(
        title: Text(lista.titulo),
        actions: [
          IconButton(
            tooltip: 'Reproducir en orden aleatorio',
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () {
              if (c.isEmpty) return;
              final mezcla = List<SongModel>.of(c)..shuffle();
              tocarCancion(context, motor, mezcla, mezcla.first);
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: c.length,
        itemBuilder: (context, i) =>
            FilaCancion(motor: motor, cancion: c[i], contexto: c),
      ),
    );
  }
}
