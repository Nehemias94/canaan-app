import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../modelos/evento.dart'; // Molde de un evento
import '../servicios/preferencias.dart'; // Eventos con 🔔
import '../servicios/recordatorios.dart'; // Avisos del teléfono
import '../servicios/servicios_app.dart'; // Avisar al panel (contar interesados)
import '../tema.dart'; // Colores (context.cc)

Future<void> alternarRecordatorioEvento(BuildContext context, Evento evento) async { // Activa o quita la 🔔 de un evento y avisa a la persona qué pasó
  final mensajero = ScaffoldMessenger.of(context); // Para avisar (se toma antes de esperar)
  if (Preferencias.recordatoriosEventos.value.contains(evento.id)) { // Ya estaba: lo quita
    await Recordatorios.desactivarEvento(evento.id); // Cancela los avisos
    _avisarPanel(evento.id, false); // Un interesado menos (en segundo plano)
    mensajero.showSnackBar(const SnackBar(content: Text('Recordatorio quitado.'))); // Aviso
    return; // Listo
  } // Fin del if
  final cuando = await Recordatorios.activarEvento(evento); // Programa (devuelve cuándo avisará, o null)
  if (cuando != null) _avisarPanel(evento.id, true); // Un interesado más (en segundo plano)
  mensajero.showSnackBar(SnackBar(content: Text(cuando != null // ¿Se pudo?
      ? '🔔 Listo: te avisaremos $cuando.' // Sí: "un día antes (9:00 am) y 1 hora antes de empezar"
      : !Recordatorios.soportado // No: ¿por qué?
          ? 'Los recordatorios funcionan en la app del teléfono.' // Navegador
          : Recordatorios.avisosDeEvento(evento, DateTime.now()).isEmpty // ¿Ya no queda ningún aviso?
              ? 'Este evento ya está por empezar: no hay recordatorios pendientes.' // Muy tarde
              : 'Activa el permiso de notificaciones de Canaán para recibir el recordatorio.'))); // Sin permiso
} // Fin de alternarRecordatorioEvento

void _avisarPanel(int eventoId, bool activo) { // Cuenta (o descuenta) un interesado en el panel; si falla (sin internet), no pasa nada
  ServiciosApp.conLlave((t) => ServiciosApp.api.marcarInteres(token: t, eventoId: eventoId, activo: activo)).catchError((_) {}); // Sin esperar
} // Fin de _avisarPanel

class CampanitaEvento extends StatelessWidget { // Botón 🔔 de un evento (dorada = activada)
  const CampanitaEvento({super.key, required this.evento}); // Constructor

  final Evento evento; // Datos del evento

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return ValueListenableBuilder<Set<int>>( // Se redibuja cuando cambian los recordatorios
      valueListenable: Preferencias.recordatoriosEventos, // Eventos con 🔔
      builder: (context, ids, _) { // Botón según el estado
        final activo = ids.contains(evento.id); // ¿Activada?
        return IconButton( // Campanita
          tooltip: activo ? 'Quitar recordatorio' : 'Recordarme este evento', // Texto de ayuda (y para lectores de pantalla)
          visualDensity: VisualDensity.compact, // Compacta
          icon: Icon(activo ? Icons.notifications_active : Icons.notifications_none, color: activo ? context.cc.dorado : context.cc.suave), // Dorada si está activa
          onPressed: () => alternarRecordatorioEvento(context, evento), // Activa o quita
        ); // Fin del botón
      }, // Fin de builder
    ); // Fin de ValueListenableBuilder
  } // Fin de build
} // Fin de CampanitaEvento
