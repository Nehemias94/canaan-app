// Un anuncio tal como llega de GET /api/anuncios (ver API.md del panel)

class ZonaAnuncio { // Área (círculo) donde avisa un anuncio "Solo área"
  final double latitud; // Centro
  final double longitud; // Centro
  final int radioMetros; // Radio en metros
  final bool propia; // true = área propia del anuncio; false = la de la iglesia

  const ZonaAnuncio({required this.latitud, required this.longitud, required this.radioMetros, this.propia = false}); // Constructor

  Map<String, dynamic> aJson() => {'latitud': latitud, 'longitud': longitud, 'radio_metros': radioMetros, 'propia': propia}; // Como datos (copia guardada)

  static ZonaAnuncio? desdeJson(Map<String, dynamic>? json) { // De la API (null si no hay)
    if (json == null || json['latitud'] == null || json['longitud'] == null) return null; // Sin área
    return ZonaAnuncio( // Crea el objeto
      latitud: (json['latitud'] as num).toDouble(), // Centro
      longitud: (json['longitud'] as num).toDouble(), // Centro
      radioMetros: (json['radio_metros'] as num?)?.toInt() ?? 200, // Radio (200 si no viene)
      propia: json['propia'] == true, // ¿Propia?
    ); // Fin
  } // Fin de desdeJson

  String get firma => '$latitud,$longitud,$radioMetros'; // Texto para saber si cambió (ej: "13.69,-89.21,200")
} // Fin de ZonaAnuncio

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
  final String? imagenUrl; // Imagen o flyer (null si no tiene)
  final String? botonTexto; // Texto del botón (ej: "Inscríbete")
  final String? botonUrl; // Enlace del botón
  final ZonaAnuncio? zona; // Solo "area": dónde avisa (null en copias viejas: se usa la de la iglesia)
  final String disparo; // Solo "area": "llegar" (al entrar) o "salir" (al irse)
  final int minutos; // Solo "area" al llegar: minutos adentro antes de avisar (0 = enseguida)

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
    this.imagenUrl, // Opcional
    this.botonTexto, // Opcional
    this.botonUrl, // Opcional
    this.zona, // Opcional
    this.disparo = 'llegar', // Por defecto, al llegar
    this.minutos = 0, // Por defecto, enseguida
  }); // Fin del constructor

  bool get alSalir => disparo == 'salir'; // ¿Avisa al irse?

  bool get esParaTodos => tipo == 'todos'; // true si es para todos (los "area" los mostrará la geocerca)

  bool enVentana(DateTime ahora) => tipo == 'area' && iniciaEn != null && terminaEn != null && !ahora.isBefore(iniciaEn!) && ahora.isBefore(terminaEn!); // Solo "area": ¿estamos dentro de su ventana de tiempo?

  bool vigente(DateTime ahora) => visibleHasta == null || visibleHasta!.isAfter(ahora); // ¿Se sigue mostrando a esta hora?

  Map<String, dynamic> aJson() => { // Lo contrario de desdeJson: el anuncio como datos (para guardar una copia en el teléfono)
        'id': id, // Número
        'titulo': titulo, // Título
        'mensaje': mensaje, // Texto
        'tipo': tipo, // Tipo
        'imagen_url': imagenUrl, // Imagen
        'boton': botonTexto == null || botonUrl == null ? null : {'texto': botonTexto, 'url': botonUrl}, // Botón
        'visible_hasta': visibleHasta?.toUtc().toIso8601String(), // Fecha y hora (en UTC: al leerla vuelve a la hora del teléfono)
        'programacion': fechaInicio == null && fechaFin == null ? null : { // Fechas (solo "todos")
          'fecha_inicio': fechaInicio?.toIso8601String().substring(0, 10), // "2026-10-06"
          'fecha_fin': fechaFin?.toIso8601String().substring(0, 10), // "2026-10-12"
        }, // Fin de las fechas
        'ventana': iniciaEn == null && terminaEn == null ? null : { // Ventana (solo "area")
          'inicia_en': iniciaEn?.toUtc().toIso8601String(), // Inicio
          'termina_en': terminaEn?.toUtc().toIso8601String(), // Fin
        }, // Fin de la ventana
        'zona': zona?.aJson(), // Área
        'disparo': tipo == 'area' ? {'evento': disparo, 'minutos': minutos} : null, // Cuándo avisa
      }; // Fin de aJson

  factory Anuncio.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en un Anuncio
    final programacion = json['programacion'] as Map<String, dynamic>?; // Bloque de fechas (solo "todos")
    final ventana = json['ventana'] as Map<String, dynamic>?; // Ventana de tiempo (solo "area")
    final disparo = json['disparo'] as Map<String, dynamic>?; // Cuándo avisa (solo "area")
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
      imagenUrl: json['imagen_url'] as String?, // Imagen (flyer)
      botonTexto: (json['boton'] as Map<String, dynamic>?)?['texto'] as String?, // Texto del botón
      botonUrl: (json['boton'] as Map<String, dynamic>?)?['url'] as String?, // Enlace del botón
      zona: ZonaAnuncio.desdeJson(json['zona'] as Map<String, dynamic>?), // Área (null si no viene)
      disparo: disparo?['evento'] == 'salir' ? 'salir' : 'llegar', // Al llegar o al salir
      minutos: (disparo?['minutos'] as num?)?.toInt() ?? 0, // Minutos adentro
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de Anuncio
