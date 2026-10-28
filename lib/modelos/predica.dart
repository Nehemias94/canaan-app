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
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Predica
