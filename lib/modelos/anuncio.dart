// Un anuncio tal como llega de GET /api/anuncios (ver API.md del panel)

class Anuncio { // Molde con los datos de un anuncio
  final int id; // Número del anuncio
  final String titulo; // Título
  final String mensaje; // Texto
  final String tipo; // "todos" (para todos) o "area" (solo cerca de la iglesia, Paso 10)
  final DateTime? fechaInicio; // Primer día (solo "todos")
  final DateTime? fechaFin; // Último día (solo "todos")
  final DateTime? visibleHasta; // Hasta cuándo se muestra (null = siempre)
  final DateTime? iniciaEn; // Solo "area": desde cuándo vale estar en la iglesia
  final DateTime? terminaEn; // Solo "area": hasta cuándo

  const Anuncio({ // Constructor
    required this.id, // Obligatorio
    required this.titulo, // Obligatorio
    required this.mensaje, // Obligatorio
    required this.tipo, // Obligatorio
    this.fechaInicio, // Opcional
    this.fechaFin, // Opcional
    this.visibleHasta, // Opcional
    this.iniciaEn, // Opcional
    this.terminaEn, // Opcional
  }); // Fin del constructor

  bool get esParaTodos => tipo == 'todos'; // true si es para todos (los "area" los mostrará la geocerca)

  bool enVentana(DateTime ahora) => tipo == 'area' && iniciaEn != null && terminaEn != null && !ahora.isBefore(iniciaEn!) && ahora.isBefore(terminaEn!); // Solo "area": ¿estamos dentro de su ventana de tiempo?

  bool vigente(DateTime ahora) => visibleHasta == null || visibleHasta!.isAfter(ahora); // ¿Se sigue mostrando a esta hora?

  Map<String, dynamic> aJson() => { // Lo contrario de desdeJson: el anuncio como datos (para guardar una copia en el teléfono)
        'id': id, // Número
        'titulo': titulo, // Título
        'mensaje': mensaje, // Texto
        'tipo': tipo, // Tipo
        'visible_hasta': visibleHasta?.toUtc().toIso8601String(), // Fecha y hora (en UTC: al leerla vuelve a la hora del teléfono)
        'programacion': fechaInicio == null && fechaFin == null ? null : { // Fechas (solo "todos")
          'fecha_inicio': fechaInicio?.toIso8601String().substring(0, 10), // "2026-10-06"
          'fecha_fin': fechaFin?.toIso8601String().substring(0, 10), // "2026-10-12"
        }, // Fin de las fechas
        'ventana': iniciaEn == null && terminaEn == null ? null : { // Ventana (solo "area")
          'inicia_en': iniciaEn?.toUtc().toIso8601String(), // Inicio
          'termina_en': terminaEn?.toUtc().toIso8601String(), // Fin
        }, // Fin de la ventana
      }; // Fin de aJson

  factory Anuncio.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en un Anuncio
    final programacion = json['programacion'] as Map<String, dynamic>?; // Bloque de fechas (solo "todos")
    final ventana = json['ventana'] as Map<String, dynamic>?; // Ventana de tiempo (solo "area")
    return Anuncio( // Crea el objeto
      id: json['id'] as int, // Número
      titulo: json['titulo'] as String? ?? '', // Título
      mensaje: json['mensaje'] as String? ?? '', // Texto
      tipo: json['tipo'] as String? ?? 'todos', // Tipo
      fechaInicio: DateTime.tryParse(programacion?['fecha_inicio'] as String? ?? ''), // "2026-10-06" → fecha (null si no hay)
      fechaFin: DateTime.tryParse(programacion?['fecha_fin'] as String? ?? ''), // Fecha de fin
      visibleHasta: DateTime.tryParse(json['visible_hasta'] as String? ?? '')?.toLocal(), // Fecha y hora → hora del teléfono
      iniciaEn: DateTime.tryParse(ventana?['inicia_en'] as String? ?? '')?.toLocal(), // Inicio de la ventana
      terminaEn: DateTime.tryParse(ventana?['termina_en'] as String? ?? '')?.toLocal(), // Fin de la ventana
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Anuncio
