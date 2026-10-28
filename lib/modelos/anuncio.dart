// Un anuncio tal como llega de GET /api/anuncios (ver API.md del panel)

class Anuncio { // Molde con los datos de un anuncio
  final int id; // Número del anuncio
  final String titulo; // Título
  final String mensaje; // Texto
  final String tipo; // "todos" (para todos) o "area" (solo cerca de la iglesia, Paso 10)
  final DateTime? fechaInicio; // Primer día (solo "todos")
  final DateTime? fechaFin; // Último día (solo "todos")
  final DateTime? visibleHasta; // Hasta cuándo se muestra (null = siempre)

  const Anuncio({ // Constructor
    required this.id, // Obligatorio
    required this.titulo, // Obligatorio
    required this.mensaje, // Obligatorio
    required this.tipo, // Obligatorio
    this.fechaInicio, // Opcional
    this.fechaFin, // Opcional
    this.visibleHasta, // Opcional
  }); // Fin del constructor

  bool get esParaTodos => tipo == 'todos'; // true si es para todos (los "area" los mostrará la geocerca)

  bool vigente(DateTime ahora) => visibleHasta == null || visibleHasta!.isAfter(ahora); // ¿Se sigue mostrando a esta hora?

  factory Anuncio.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en un Anuncio
    final programacion = json['programacion'] as Map<String, dynamic>?; // Bloque de fechas (solo "todos")
    return Anuncio( // Crea el objeto
      id: json['id'] as int, // Número
      titulo: json['titulo'] as String? ?? '', // Título
      mensaje: json['mensaje'] as String? ?? '', // Texto
      tipo: json['tipo'] as String? ?? 'todos', // Tipo
      fechaInicio: DateTime.tryParse(programacion?['fecha_inicio'] as String? ?? ''), // "2026-10-06" → fecha (null si no hay)
      fechaFin: DateTime.tryParse(programacion?['fecha_fin'] as String? ?? ''), // Fecha de fin
      visibleHasta: DateTime.tryParse(json['visible_hasta'] as String? ?? '')?.toLocal(), // Fecha y hora → hora del teléfono
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Anuncio
