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
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Actividad
