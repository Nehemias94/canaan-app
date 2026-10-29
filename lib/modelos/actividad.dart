// Una actividad del horario tal como llega de GET /api/actividades (ver API.md del panel)

class Actividad { // Molde con los datos de un culto o actividad
  final int id; // Número de la actividad
  final String nombre; // Ej: "Culto general"
  final int diaSemana; // 0 = domingo … 6 = sábado
  final String dia; // Ej: "Domingo" (ya listo para mostrar)
  final String horario; // Ej: "10:00 am – 12:00 pm" (ya listo para mostrar)
  final String? lugar; // Dónde es (puede venir vacío)
  final String? descripcion; // Detalle (puede venir vacío)
  final bool seTransmite; // true = se transmite en vivo
  final bool enCurso; // true = está ocurriendo ahora
  final DateTime? proxima; // Próxima vez que ocurre (hora del teléfono); null si no vino

  const Actividad({ // Constructor
    required this.id, // Obligatorio
    required this.nombre, // Obligatorio
    required this.diaSemana, // Obligatorio
    required this.dia, // Obligatorio
    required this.horario, // Obligatorio
    this.lugar, // Opcional
    this.descripcion, // Opcional
    this.seTransmite = false, // Por defecto, no se transmite
    this.enCurso = false, // Por defecto, no está en curso
    this.proxima, // Opcional
  }); // Fin del constructor

  factory Actividad.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en una Actividad
    return Actividad( // Crea el objeto
      id: json['id'] as int, // Número
      nombre: json['nombre'] as String? ?? '', // Nombre
      diaSemana: json['dia_semana'] as int? ?? 0, // Día de la semana (número)
      dia: json['dia'] as String? ?? '', // Día de la semana (texto)
      horario: json['horario'] as String? ?? '', // Horario en texto
      lugar: json['lugar'] as String?, // Lugar
      descripcion: json['descripcion'] as String?, // Descripción
      seTransmite: json['se_transmite'] == true, // ¿Se transmite?
      enCurso: json['en_curso'] == true, // ¿Está ocurriendo ahora?
      proxima: DateTime.tryParse(json['proxima'] as String? ?? '')?.toLocal(), // Próxima fecha (ISO del panel → hora del teléfono)
    ); // Fin del objeto
  } // Fin de desdeJson

  String textoParaCompartir() => [ // Un culto: lo que se comparte, un dato por renglón
        '⛪ $nombre', // Nombre
        '📅 Cada ${dia.toLowerCase()} · $horario', // "Cada domingo · 10:00 am – 12:00 pm"
        if (lugar != null && lugar!.isNotEmpty) '📍 $lugar', // Lugar
        if (seTransmite) '🔴 Se transmite en vivo en la app Canaán', // En vivo
        '¡Te esperamos!', // Invitación
      ].join('\n'); // Fin de textoParaCompartir

  static String horarioCompleto(List<Actividad> actividades) { // Toda la semana, agrupada por día (las actividades ya vienen ordenadas)
    final renglones = <String>['📅 Horario de cultos']; // Título
    int? diaAnterior; // Día del renglón anterior
    for (final a in actividades) { // Cada actividad
      if (a.diaSemana != diaAnterior) { renglones..add('')..add(a.dia.toUpperCase()); diaAnterior = a.diaSemana; } // Encabezado del día (con un renglón en blanco antes)
      renglones.add('• ${a.nombre} · ${a.horario}${(a.lugar ?? '').isNotEmpty ? ' · ${a.lugar}' : ''}${a.seTransmite ? ' 🔴' : ''}'); // "• Culto general · 10:00 am – 12:00 pm · Templo 🔴"
    } // Fin del for
    if (actividades.any((a) => a.seTransmite)) renglones..add('')..add('🔴 = se transmite en vivo en la app Canaán'); // Explica el punto rojo
    return renglones.join('\n'); // Todo junto
  } // Fin de horarioCompleto
} // Fin de Actividad
