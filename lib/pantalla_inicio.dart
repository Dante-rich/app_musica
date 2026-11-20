import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'componentes.dart';
import 'motor.dart';
import 'pantalla_busqueda.dart';
import 'pantalla_estadisticas.dart';
import 'pantalla_inteligentes.dart';
import 'utilidades.dart';

class PantallaInicio extends StatelessWidget {
  final MotorMusica motor;
  final VoidCallback alIrABiblioteca;

  const PantallaInicio({super.key, required this.motor, required this.alIrABiblioteca});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: motor,
      builder: (context, _) {
        final hora = DateTime.now().hour;
        final saludo = hora < 12
            ? 'Buenos días'
            : hora < 19
                ? 'Buenas tardes'
                : 'Buenas noches';

        final recientes = motor.recientesCanciones;
        final masEscuchadas = motor.masEscuchadas;
        final agregadas = motor.agregadasRecientemente;
        final hayMusica = motor.canciones.isNotEmpty;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(saludo,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.search_rounded, size: 28),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PantallaBusqueda(motor: motor))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Tu música, sin conexión.', style: TextStyle(color: tSuave)),
              const SizedBox(height: 18),
              if (motor.cargando && !hayMusica)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: context.acento)),
                )
              else if (!hayMusica)
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Column(
                    children: [
                      Icon(Icons.library_music_outlined, size: 70, color: context.acento),
                      const SizedBox(height: 14),
                      Text(
                        motor.permisoDenegado
                            ? 'Necesito permiso para leer tu música.'
                            : 'No encontré música en tu teléfono.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: motor.cargarCanciones,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Volver a intentar'),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _AccionRapida(
                        icono: Icons.shuffle_rounded,
                        texto: 'Aleatorio',
                        alTocar: () => motor.reproducirAleatorio(motor.canciones),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AccionRapida(
                        icono: Icons.favorite_rounded,
                        texto: 'Favoritas',
                        alTocar: () {
                          final l = motor.cancionesFavoritas;
                          if (l.isEmpty) {
                            motor.aviso('Aún no tienes favoritas.');
                          } else {
                            motor.reproducir(l, l.first);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _AccionRapida(
                        icono: Icons.trending_up_rounded,
                        texto: 'Más escuchadas',
                        alTocar: () {
                          if (masEscuchadas.isEmpty) {
                            motor.aviso('Escucha algunas canciones y aparecerán aquí.');
                          } else {
                            motor.reproducir(masEscuchadas, masEscuchadas.first);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AccionRapida(
                        icono: Icons.new_releases_rounded,
                        texto: 'Recién agregadas',
                        alTocar: () => motor.reproducir(agregadas, agregadas.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (recientes.isNotEmpty)
                  _FilaHorizontal(motor: motor, titulo: 'Seguir escuchando', lista: recientes),
                if (masEscuchadas.isNotEmpty)
                  _FilaHorizontal(motor: motor, titulo: 'Más escuchadas', lista: masEscuchadas),
                if (motor.conteos.isNotEmpty && motor.sinEscuchar.isNotEmpty)
                  _FilaHorizontal(
                    motor: motor,
                    titulo: 'Aún no las has escuchado',
                    lista: motor.sinEscuchar,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome_rounded, color: context.acento),
                    title: const Text('Listas inteligentes'),
                    subtitle: const Text('Nunca escuchadas, olvidadas, top, largas…'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PantallaInteligentes(motor: motor))),
                  ),
                ),
                _FilaHorizontal(motor: motor, titulo: 'Agregadas recientemente', lista: agregadas),
                if (motor.descubre.isNotEmpty)
                  _FilaHorizontal(motor: motor, titulo: 'Descubre algo', lista: motor.descubre),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${motor.canciones.length} canciones · ${formatoDuracionLarga(duracionTotal(motor.canciones))}'
                    ' · ${motor.reproduccionesTotales} reproducciones',
                    style: TextStyle(color: tTenue, fontSize: 12),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PantallaEstadisticas(motor: motor),
                      ),
                    ),
                    icon: const Icon(Icons.insights_rounded),
                    label: const Text('Ver tu resumen'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AccionRapida extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback alTocar;

  const _AccionRapida({required this.icono, required this.texto, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.panelElevado,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: modoClaroActivo ? context.acento.withValues(alpha: 0.25) : Colors.transparent),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.acento.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: context.acento),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaHorizontal extends StatelessWidget {
  final MotorMusica motor;
  final String titulo;
  final List<SongModel> lista;

  const _FilaHorizontal({required this.motor, required this.titulo, required this.lista});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: lista.length > 10 ? 10 : lista.length,
            itemBuilder: (context, i) => TarjetaCancion(
              motor: motor,
              cancion: lista[i],
              contexto: lista.take(10).toList(),
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}
