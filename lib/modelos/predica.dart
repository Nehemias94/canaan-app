// Una prédica tal como llega de GET /api/predicas (ver API.md del panel)

class Predica { // Molde con los datos de una prédica
  final int id; // Número de la prédica
  final String titulo; // Título
  final String? predicador; // Quién predicó (puede venir vacío)
  final DateTime? fecha; // Fecha de la prédica
  final String? descripcion; // Resumen o versículos
  final bool destacada; // true = se muestra arriba con estilo especial
  final String? youtubeId; // Código del video (para el reproductor, más adelante)
  final String? youtubeUrl; // Enlace completo de YouTube
  final String? miniaturaUrl; // Imagen de vista previa del video
  final int reproducciones; // Veces vista desde la app
  final int? serieId; // Serie a la que pertenece (null = suelta)
  final String? serieNombre; // Nombre de la serie
  final int? serieParte; // Número de parte
  final int serieTotal; // Partes de la serie
  final int? siguienteId; // Siguiente parte (null = es la última o no tiene serie)
  final String? siguienteTitulo; // Título de la siguiente parte
  final int? siguienteParte; // Número de la siguiente parte
  final String? bosquejo; // Bosquejo (texto)
  final String? bosquejoPdfUrl; // Bosquejo (PDF)

  bool get tieneBosquejo => (bosquejo ?? '').trim().isNotEmpty || bosquejoPdfUrl != null; // ¿Hay algo que mostrar en "Ver bosquejo"?

  const Predica({ // Constructor
    required this.id, // Obligatorio
    required this.titulo, // Obligatorio
    this.predicador, // Opcional
    this.fecha, // Opcional
    this.descripcion, // Opcional
    this.destacada = false, // Por defecto, no destacada
    this.youtubeId, // Opcional
    this.youtubeUrl, // Opcional
    this.miniaturaUrl, // Opcional
    this.reproducciones = 0, // Por defecto, 0 vistas
    this.serieId, this.serieNombre, this.serieParte, this.serieTotal = 0, // Serie (opcional)
    this.siguienteId, this.siguienteTitulo, this.siguienteParte, // Siguiente parte (opcional)
    this.bosquejo, this.bosquejoPdfUrl, // Bosquejo (opcional)
  }); // Fin del constructor

  factory Predica.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en una Predica
    return Predica( // Crea el objeto
      id: json['id'] as int, // Número
      titulo: json['titulo'] as String? ?? '(Sin título)', // Título (por si viniera vacío)
      predicador: json['predicador'] as String?, // Predicador
      fecha: DateTime.tryParse(json['fecha'] as String? ?? ''), // Fecha "2026-10-05" → DateTime (null si no se puede leer)
      descripcion: json['descripcion'] as String?, // Descripción
      destacada: json['destacada'] == true, // ¿Destacada?
      youtubeId: json['youtube_id'] as String?, // Código de YouTube
      youtubeUrl: json['youtube_url'] as String?, // Enlace de YouTube
      miniaturaUrl: json['miniatura_url'] as String?, // Miniatura
      reproducciones: json['reproducciones'] as int? ?? 0, // Vistas (0 si no viene)
      serieId: (json['serie'] as Map<String, dynamic>?)?['id'] as int?, // Serie
      serieNombre: (json['serie'] as Map<String, dynamic>?)?['nombre'] as String?, // Nombre de la serie
      serieParte: ((json['serie'] as Map<String, dynamic>?)?['parte'] as num?)?.toInt(), // Parte
      serieTotal: ((json['serie'] as Map<String, dynamic>?)?['total'] as num?)?.toInt() ?? 0, // Total de partes
      siguienteId: ((json['serie'] as Map<String, dynamic>?)?['siguiente'] as Map<String, dynamic>?)?['id'] as int?, // Siguiente parte
      siguienteTitulo: ((json['serie'] as Map<String, dynamic>?)?['siguiente'] as Map<String, dynamic>?)?['titulo'] as String?, // Su título
      siguienteParte: (((json['serie'] as Map<String, dynamic>?)?['siguiente'] as Map<String, dynamic>?)?['parte'] as num?)?.toInt(), // Su número
      bosquejo: json['bosquejo'] as String?, // Bosquejo (texto)
      bosquejoPdfUrl: json['bosquejo_pdf_url'] as String?, // Bosquejo (PDF)
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Predica

class SerieResumen { // Una serie para los botones de filtro (GET /api/series)
  const SerieResumen({required this.id, required this.nombre, this.partes = 0}); // Constructor

  final int id; // Número
  final String nombre; // Nombre
  final int partes; // Cuántas prédicas tiene

  factory SerieResumen.desdeJson(Map<String, dynamic> json) => SerieResumen(id: json['id'] as int, nombre: json['nombre'] as String? ?? '', partes: (json['partes'] as num?)?.toInt() ?? 0); // Desde el JSON
} // Fin de SerieResumen
