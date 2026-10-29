// Datos de la iglesia tal como llegan de GET /api/iglesia (ver API.md del panel)

class Iglesia { // Molde con los datos que usa la app
  final String nombre; // Nombre de la iglesia
  final String? logoUrl; // Enlace del logo (null si no se ha subido; el "?" significa que puede venir vacío)
  final EnVivo enVivo; // Datos de la transmisión en vivo
  final AvisoUrgente avisoUrgente; // Aviso urgente (si hay uno activo)
  final RadioIglesia radio; // Datos de la radio en línea
  final double? latitud; // Ubicación del templo (para la geocerca; null si no se ha configurado)
  final double? longitud; // Ubicación del templo
  final int radioMetros; // Distancia que cuenta como "estar en la iglesia"
  final String? youtubeCanal; // Enlace del canal de YouTube de la iglesia (null si no se configuró en el panel)
  final String? whatsapp; // Número de WhatsApp para wa.me (null = el panel no quiere mostrar el botón)
  final Ofrendas ofrendas; // Ofrendas y diezmos (cuentas y QR)
  final VersiculoDia? versiculo; // Versículo del día (null si no hay)
  final Repeticion? repeticion; // Última transmisión terminada hace poco ("¿Te lo perdiste?"); null si no hay

  bool get tieneUbicacion => latitud != null && longitud != null; // ¿Se configuró la ubicación en el panel?

  bool get radioDisponible => radio.disponible; // Atajo: true si la radio está al aire en la app

  const Iglesia({ // Constructor: pide todos los datos con su nombre
    required this.nombre, // Obligatorio
    required this.logoUrl, // Obligatorio (aunque puede ser null)
    required this.enVivo, // Obligatorio
    required this.avisoUrgente, // Obligatorio
    required this.radio, // Obligatorio
    this.latitud, // Opcional
    this.longitud, // Opcional
    this.radioMetros = 200, // Por defecto 200 m
    this.youtubeCanal, // Opcional
    this.whatsapp, // Opcional
    this.ofrendas = const Ofrendas(mostrar: false), // Por defecto, sin ofrendas
    this.versiculo, // Opcional
    this.repeticion, // Opcional
  }); // Fin del constructor

  factory Iglesia.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en un objeto Iglesia
    return Iglesia( // Crea el objeto...
      nombre: json['nombre'] as String? ?? 'Canaán', // ...con el nombre (si no viene, "Canaán")
      logoUrl: json['logo_url'] as String?, // ...el logo (puede ser null)
      enVivo: EnVivo.desdeJson(json['en_vivo'] as Map<String, dynamic>? ?? {}), // ...el bloque en_vivo (si falta, vacío)
      avisoUrgente: AvisoUrgente.desdeJson(json['aviso_urgente'] as Map<String, dynamic>? ?? {}), // ...el aviso urgente
      radio: RadioIglesia.desdeJson(json['radio'] as Map<String, dynamic>? ?? {}), // ...la radio
      latitud: ((json['ubicacion'] as Map<String, dynamic>?)?['latitud'] as num?)?.toDouble(), // ...la latitud del templo (num → decimal)
      longitud: ((json['ubicacion'] as Map<String, dynamic>?)?['longitud'] as num?)?.toDouble(), // ...la longitud
      radioMetros: ((json['ubicacion'] as Map<String, dynamic>?)?['radio_metros'] as num?)?.toInt() ?? 200, // ...y el radio en metros
      youtubeCanal: (json['youtube'] as Map<String, dynamic>?)?['canal_url'] as String?, // ...el canal de YouTube (bloque "youtube")
      whatsapp: (json['contacto'] as Map<String, dynamic>?)?['whatsapp'] as String?, // ...el WhatsApp (bloque "contacto")
      ofrendas: Ofrendas.desdeJson(json['ofrendas'] as Map<String, dynamic>? ?? {}), // ...las ofrendas
      versiculo: json['versiculo_dia'] == null ? null : VersiculoDia.desdeJson(json['versiculo_dia'] as Map<String, dynamic>), // ...el versículo del día
      repeticion: json['repeticion'] == null ? null : Repeticion.desdeJson(json['repeticion'] as Map<String, dynamic>), // ...y la repetición del culto (si hubo transmisión en las últimas 12 h)
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

class RadioIglesia { // Radio en línea de la iglesia (bloque "radio" de /api/iglesia)
  final bool disponible; // true = está al aire en la app (24/7, o encendida desde el panel)
  final String? titulo; // Ej: "Culto dominical" o "Radio Canaán"
  final String? streamUrl; // Enlace del audio (lo que se reproduce)
  final String? modo; // "manual" (solo en cultos) o "siempre" (24/7)
  final DateTime? hasta; // Hora en que se apaga sola (solo en modo manual)

  const RadioIglesia({required this.disponible, this.titulo, this.streamUrl, this.modo, this.hasta}); // Constructor

  factory RadioIglesia.desdeJson(Map<String, dynamic> json) { // Convierte el JSON en RadioIglesia
    return RadioIglesia( // Crea el objeto
      disponible: json['disponible'] == true, // ¿Al aire?
      titulo: json['titulo'] as String?, // Título
      streamUrl: json['stream_url'] as String?, // Enlace del audio
      modo: json['modo'] as String?, // Modo
      hasta: DateTime.tryParse(json['hasta'] as String? ?? '')?.toLocal(), // Hora de apagado, convertida a la hora del teléfono (null si no hay)
    ); // Fin del objeto
  } // Fin de desdeJson
} // Fin de RadioIglesia

class Ofrendas { // Ofrendas y diezmos (bloque "ofrendas" de /api/iglesia)
  final bool mostrar; // true = mostrar la opción en Servicios
  final String? mensaje; // Mensaje de introducción
  final List<CuentaOfrenda> cuentas; // Cuentas bancarias
  final String? qrUrl; // Imagen del código QR (null si no hay)

  const Ofrendas({required this.mostrar, this.mensaje, this.cuentas = const [], this.qrUrl}); // Constructor

  factory Ofrendas.desdeJson(Map<String, dynamic> json) => Ofrendas( // Desde el JSON
        mostrar: json['mostrar'] == true, // ¿Mostrar?
        mensaje: json['mensaje'] as String?, // Mensaje
        cuentas: ((json['cuentas'] as List?) ?? []).map((c) => CuentaOfrenda.desdeJson(c as Map<String, dynamic>)).toList(), // Cuentas
        qrUrl: json['qr_url'] as String?, // QR
      ); // Fin
} // Fin de Ofrendas

class CuentaOfrenda { // Una cuenta bancaria para ofrendar
  final String banco; // Ej: "Banco Agrícola"
  final String? tipo; // Ej: "Ahorro"
  final String numero; // Número de cuenta
  final String? titular; // A nombre de

  const CuentaOfrenda({required this.banco, this.tipo, required this.numero, this.titular}); // Constructor

  factory CuentaOfrenda.desdeJson(Map<String, dynamic> json) => CuentaOfrenda( // Desde el JSON
        banco: json['banco'] as String? ?? '', // Banco
        tipo: json['tipo'] as String?, // Tipo
        numero: json['numero'] as String? ?? '', // Número
        titular: json['titular'] as String?, // Titular
      ); // Fin
} // Fin de CuentaOfrenda

class VersiculoDia { // Versículo del día (bloque "versiculo_dia")
  final String texto; // Texto
  final String referencia; // Cita, ej: "Juan 3:16"

  const VersiculoDia({required this.texto, required this.referencia}); // Constructor

  factory VersiculoDia.desdeJson(Map<String, dynamic> json) => VersiculoDia( // Desde el JSON
        texto: json['texto'] as String? ?? '', // Texto
        referencia: json['referencia'] as String? ?? '', // Cita
      ); // Fin
} // Fin de VersiculoDia

class Repeticion { // Repetición del último culto transmitido (bloque "repeticion" de /api/iglesia)
  final String titulo; // Título de la transmisión
  final String youtubeId; // Código del video de YouTube
  final DateTime? termino; // Cuándo terminó (hora del teléfono)

  const Repeticion({required this.titulo, required this.youtubeId, this.termino}); // Constructor

  factory Repeticion.desdeJson(Map<String, dynamic> json) => Repeticion( // Desde el JSON
        titulo: json['titulo'] as String? ?? 'Culto', // Título (o uno genérico)
        youtubeId: json['youtube_id'] as String? ?? '', // Código del video
        termino: DateTime.tryParse(json['termino'] as String? ?? '')?.toLocal(), // Fecha ISO del panel → hora del teléfono
      ); // Fin
} // Fin de Repeticion
