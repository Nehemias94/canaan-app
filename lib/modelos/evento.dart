// Un evento especial tal como llega de GET /api/eventos (ver API.md del panel)

import '../tema.dart'; // fechaLarga (para mostrar la fecha)

class Evento { // Molde con los datos de un evento (campamento, aniversario, concierto…)
  final int id; // Número (para el recordatorio)
  final String titulo; // Nombre
  final String? descripcion; // Detalle (puede venir vacío)
  final DateTime iniciaEn; // Inicio (hora del teléfono)
  final DateTime? terminaEn; // Fin (null = termina ese mismo día)
  final String? lugar; // Lugar
  final String? imagenUrl; // Imagen o flyer
  final bool seTransmite; // ¿Se transmite en vivo?
  final bool enCurso; // ¿Está ocurriendo ahora?
  final String? botonTexto; // Texto del botón (ej: "Inscríbete")
  final String? botonUrl; // Enlace del botón
  final int diasAntes; // Recordatorio (🔔): CADA DÍA desde N días antes hasta la víspera (0 = no avisar); lo elige el panel
  final List<String> horasAviso; // Horas de los avisos de cada uno de esos días, ej: ["09:00", "18:00"]
  final int minutosAntes; // Recordatorio (🔔): el mismo día, minutos antes de empezar (0 = no avisar)

  const Evento({ // Constructor
    required this.id, // Obligatorio
    required this.titulo, // Obligatorio
    required this.iniciaEn, // Obligatorio
    this.descripcion, // Opcional
    this.terminaEn, // Opcional
    this.lugar, // Opcional
    this.imagenUrl, // Opcional
    this.seTransmite = false, // Por defecto, no
    this.enCurso = false, // Por defecto, no
    this.botonTexto, // Opcional
    this.botonUrl, // Opcional
    this.diasAntes = 1, // Por defecto, 1 día antes
    this.horasAviso = const ['09:00'], // Por defecto, a las 9:00 am
    this.minutosAntes = 60, // Por defecto, 1 hora antes
  }); // Fin del constructor

  factory Evento.desdeJson(Map<String, dynamic> json) { // Convierte el JSON de la API en un Evento
    final boton = json['boton'] as Map<String, dynamic>?; // Bloque del botón (null si no tiene)
    final recordatorio = json['recordatorio'] as Map<String, dynamic>?; // Bloque del recordatorio (null en paneles viejos)
    return Evento( // Crea el objeto
      id: json['id'] as int, // Número
      titulo: json['titulo'] as String? ?? '', // Nombre
      descripcion: json['descripcion'] as String?, // Detalle
      iniciaEn: DateTime.tryParse(json['inicia_en'] as String? ?? '')?.toLocal() ?? DateTime.now(), // Inicio (ISO → hora del teléfono)
      terminaEn: DateTime.tryParse(json['termina_en'] as String? ?? '')?.toLocal(), // Fin
      lugar: json['lugar'] as String?, // Lugar
      imagenUrl: json['imagen_url'] as String?, // Imagen
      seTransmite: json['se_transmite'] == true, // ¿Se transmite?
      enCurso: json['en_curso'] == true, // ¿Ahora?
      botonTexto: boton?['texto'] as String?, // Texto del botón
      botonUrl: boton?['url'] as String?, // Enlace del botón
      diasAntes: (recordatorio?['dias_antes'] as num?)?.toInt() ?? 1, // Días antes (si no viene: 1)
      horasAviso: (recordatorio?['horas'] as List?)?.cast<String>() ?? const ['09:00'], // Horas de cada día (si no viene: 9:00 am)
      minutosAntes: (recordatorio?['minutos_antes'] as num?)?.toInt() ?? 60, // Minutos antes (si no viene: 60)
    ); // Fin del objeto
  } // Fin de desdeJson

  String textoParaCompartir() => [ // Lo que se comparte: un dato por renglón
        '🎉 $titulo', // Nombre
        '📅 ${cuandoTexto()}', // Fecha
        if (lugar != null && lugar!.isNotEmpty) '📍 $lugar', // Lugar
        if (seTransmite) '🔴 Se transmite en vivo en la app Canaán', // En vivo
        if (botonTexto != null && botonUrl != null) '$botonTexto: $botonUrl', // Enlace (ej: inscripción)
      ].join('\n'); // Fin de textoParaCompartir

  String cuandoTexto() { // Fecha para mostrar, ej: "Sábado, 20 de noviembre · 8:00 am" o "20 al 22 de noviembre"
    final fin = terminaEn; // Atajo
    final mismoDia = fin == null || (fin.year == iniciaEn.year && fin.month == iniciaEn.month && fin.day == iniciaEn.day); // ¿Empieza y termina el mismo día?
    if (mismoDia) return '${fechaLarga(iniciaEn)} · ${horaCorta(iniciaEn)}'; // Un solo día: con la hora
    return 'Del ${fechaLarga(iniciaEn)} al ${fechaLarga(fin)}'; // Varios días: rango
  } // Fin de cuandoTexto
} // Fin de Evento
