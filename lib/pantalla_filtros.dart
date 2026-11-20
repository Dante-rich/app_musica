import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'motor.dart';
import 'utilidades.dart';

/// Decide qué música aparece en la app: bloquear carpetas, ocultar WhatsApp y
/// grabaciones automáticamente, o elegir a mano solo las canciones que quieras.
class PantallaFiltros extends StatelessWidget {
  final MotorMusica motor;

  const PantallaFiltros({super.key, required this.motor});

  @override
  Widget build(BuildContext context) {
    final acento = context.acento;
    return Scaffold(
      appBar: AppBar(title: const Text('Filtros de biblioteca')),
      body: ListenableBuilder(
        listenable: motor,
        builder: (context, _) {
          final carpetas = motor.carpetasConConteo;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Text(
                'Ahora ves ${motor.canciones.length} canciones.',
                style: TextStyle(color: tSuave),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.auto_fix_high_rounded, color: acento),
                title: const Text('Filtro inteligente'),
                subtitle: const Text(
                    'Oculta audios de WhatsApp, grabaciones de voz, notificaciones, tonos y alarmas'),
                value: motor.bloquearRuido,
                activeThumbColor: acento,
                onChanged: motor.modoManual ? null : (v) => motor.configurarFiltros(ruido: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.checklist_rounded, color: acento),
                title: const Text('Elegir yo las canciones'),
                subtitle: const Text('Solo aparecen las que marques. Ignora los demás filtros'),
                value: motor.modoManual,
                activeThumbColor: acento,
                onChanged: (v) => motor.configurarFiltros(manual: v),
              ),
              if (motor.modoManual)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.library_add_check_rounded, color: acento),
                  title: Text('Elegir canciones (${motor.elegidas.length})'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PantallaElegirCanciones(motor: motor),
                    ),
                  ),
                ),
              Divider(color: tLinea, height: 28),
              const Text(
                'Carpetas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                motor.modoManual
                    ? 'Desactiva el modo manual para usar las carpetas.'
                    : 'Apaga el interruptor de una carpeta para bloquearla.',
                style: TextStyle(color: tSuave, fontSize: 12),
              ),
              const SizedBox(height: 6),
              for (final e in carpetas)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(nombreCarpeta(e.key), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${e.value} canciones · ${e.key}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: !motor.carpetasBloqueadas.contains(e.key),
                  activeThumbColor: acento,
                  onChanged: motor.modoManual
                      ? null
                      : (incluida) {
                          final nuevo = Set<String>.from(motor.carpetasBloqueadas);
                          if (incluida) {
                            nuevo.remove(e.key);
                          } else {
                            nuevo.add(e.key);
                          }
                          motor.configurarFiltros(carpetas: nuevo);
                        },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Lista de TODAS las canciones del teléfono con casillas para elegir.
class PantallaElegirCanciones extends StatefulWidget {
  final MotorMusica motor;

  const PantallaElegirCanciones({super.key, required this.motor});

  @override
  State<PantallaElegirCanciones> createState() => _EstadoElegir();
}

class _EstadoElegir extends State<PantallaElegirCanciones> {
  late final List<SongModel> _todas;
  late final Set<int> _sel;
  final TextEditingController _buscar = TextEditingController();
  String _texto = '';

  @override
  void initState() {
    super.initState();
    _todas = widget.motor.todasLasCanciones;
    _sel = Set<int>.from(widget.motor.elegidas);
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  List<SongModel> get _visibles {
    final t = _texto.trim().toLowerCase();
    if (t.isEmpty) return _todas;
    return _todas
        .where((s) =>
            s.title.toLowerCase().contains(t) ||
            artistaDe(s).toLowerCase().contains(t) ||
            s.data.toLowerCase().contains(t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final acento = context.acento;
    final visibles = _visibles;
    return Scaffold(
      appBar: AppBar(
        title: Text('Elegir canciones (${_sel.length})'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => setState(() {
              final ids = visibles.map((s) => s.id);
              if (v == 'todas') {
                _sel.addAll(ids);
              } else {
                _sel.removeAll(ids);
              }
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'todas', child: Text('Marcar las que se ven')),
              PopupMenuItem(value: 'ninguna', child: Text('Desmarcar las que se ven')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _buscar,
              onChanged: (v) => setState(() => _texto = v),
              decoration: InputDecoration(
                hintText: 'Buscar por título, artista o carpeta',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: context.panelElevado,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: visibles.length,
        itemBuilder: (context, i) {
          final s = visibles[i];
          return CheckboxListTile(
            value: _sel.contains(s.id),
            activeColor: acento,
            title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${artistaDe(s)} · ${nombreCarpeta(carpetaDe(s))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: caratula(s, 44, acento),
            onChanged: (v) => setState(() {
              if (v == true) {
                _sel.add(s.id);
              } else {
                _sel.remove(s.id);
              }
            }),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () async {
              await widget.motor.configurarFiltros(soloEstas: _sel);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text('Guardar (${_sel.length})'),
          ),
        ),
      ),
    );
  }
}
