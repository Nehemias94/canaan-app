// Datos de la iglesia tal como llegan de GET /api/iglesia (ver API.md del panel)

class Iglesia { // Molde con los datos que usa la app
  final String nombre; // Nombre de la iglesia
  final String? logoUrl; // Enlace del logo (null si no se ha subido; el "?" significa que puede venir vacío)
  final EnVivo enVivo; // Datos de la transmisión en vivo
  final AvisoUrgente avisoUrgente; // Aviso urgente (si hay uno activo)
  final bool radioDisponible; // true si la radio está al aire en la app

  const Iglesia({ // Constructor: pide todos los datos con su nombre
    required this.nombre, // Obligatorio
    required this.logoUrl, // Obligatorio (aunque puede ser null)
    required this.enVivo, // Obligatorio
    required this.avisoUrgente, // Obligatorio
    required this.radioDisponible, // Obligatorio
  }); // Fin del constructor

  factory Iglesia.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en un objeto Iglesia
    return Iglesia( // Crea el objeto...
      nombre: json['nombre'] as String? ?? 'Canaán', // ...con el nombre (si no viene, "Canaán")
      logoUrl: json['logo_url'] as String?, // ...el logo (puede ser null)
      enVivo: EnVivo.desdeJson(json['en_vivo'] as Map<String, dynamic>? ?? {}), // ...el bloque en_vivo (si falta, vacío)
      avisoUrgente: AvisoUrgente.desdeJson(json['aviso_urgente'] as Map<String, dynamic>? ?? {}), // ...el aviso urgente
      radioDisponible: (json['radio'] as Map<String, dynamic>?)?['disponible'] == true, // ...y si la radio está disponible
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Iglesia

class EnVivo { // Datos de la transmisión en vivo
  final bool activo; // true si se está transmitiendo ahora
  final String? titulo; // Título de la transmisión
  final String? youtubeId; // Código del video de YouTube (para el reproductor, más adelante)

  const EnVivo({required this.activo, this.titulo, this.youtubeId}); // Constructor

  factory EnVivo.desdeJson(Map<String, dynamic> json) { // Convierte el JSON en EnVivo
    return EnVivo( // Crea el objeto
      activo: json['activo'] == true, // Solo es true si la API dice exactamente true
      titulo: json['titulo'] as String?, // Título (puede ser null)
      youtubeId: json['youtube_id'] as String?, // Código de YouTube (puede ser null)
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de EnVivo

class AvisoUrgente { // Aviso urgente que el panel puede mostrar en la app
  final bool activo; // true si hay un aviso vigente
  final String? titulo; // Título del aviso
  final String? mensaje; // Texto del aviso
  final String? nivel; // urgente | importante | informativo

  const AvisoUrgente({required this.activo, this.titulo, this.mensaje, this.nivel}); // Constructor

  factory AvisoUrgente.desdeJson(Map<String, dynamic> json) { // Convierte el JSON en AvisoUrgente
    return AvisoUrgente( // Crea el objeto
      activo: json['activo'] == true, // ¿Está vigente?
      titulo: json['titulo'] as String?, // Título
      mensaje: json['mensaje'] as String?, // Mensaje
      nivel: json['nivel'] as String?, // Nivel
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de AvisoUrgente
