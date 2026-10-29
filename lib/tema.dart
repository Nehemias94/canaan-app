import 'package:flutter/material.dart'; // Componentes visuales de Flutter (Color, ThemeData…)
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (colores de la barra de arriba del teléfono)

// Barra de arriba del teléfono (hora, batería, señal) con íconos BLANCOS y fondo transparente:
// se usa sobre fondos oscuros (barras de título marino y el degradado de Inicio). Sin esto salían negros y no se leían.
const SystemUiOverlayStyle barraSuperiorClara = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent, // Fondo transparente: se ve el color de la pantalla detrás
  statusBarIconBrightness: Brightness.light, // Android: íconos claros (blancos)
  statusBarBrightness: Brightness.dark, // iPhone: "fondo oscuro" = letras blancas (en iPhone se indica al revés)
); // Fin del estilo

// Colores oficiales de Canaán (los mismos del panel)
const Color azulCanaan = Color(0xFF004B82); // Azul principal
const Color marinoCanaan = Color(0xFF00223E); // Marino (letras del logo)
const Color doradoCanaan = Color(0xFFFFB100); // Dorado (ícono y acentos)
const Color fondoCanaan = Color(0xFFF3F6FA); // Fondo gris azulado muy claro de todas las pantallas (igual que el panel)
const Color bordeCanaan = Color(0xFFE2E8F0); // Borde suave de las tarjetas
const Color doradoOscuro = Color(0xFFB07A00); // Dorado oscuro (se lee bien sobre blanco)

const Color fondoOscuro = Color(0xFF0B1622); // Fondo de las pantallas en modo oscuro (marino casi negro)
const Color tarjetaOscura = Color(0xFF15273A); // Tarjetas en modo oscuro
const Color bordeOscuro = Color(0xFF26394D); // Borde de las tarjetas en modo oscuro

class ColoresCanaan extends ThemeExtension<ColoresCanaan> { // Colores que CAMBIAN con el modo claro/oscuro (se leen con context.cc)
  const ColoresCanaan({required this.titulo, required this.texto, required this.suave, required this.tenue, required this.tarjeta, required this.borde, required this.azul, required this.dorado, required this.morado}); // Constructor

  final Color titulo; // Títulos de tarjetas (marino en claro, casi blanco en oscuro)
  final Color texto; // Texto normal
  final Color suave; // Texto secundario (fechas, lugares)
  final Color tenue; // Flechitas e íconos discretos
  final Color tarjeta; // Fondo de tarjetas y barras blancas
  final Color borde; // Bordes suaves
  final Color azul; // Azul para textos e íconos (más claro en oscuro para que se lea)
  final Color dorado; // Dorado para textos (oscuro en claro, brillante en oscuro)
  final Color morado; // Morado de los eventos especiales

  static const claro = ColoresCanaan(titulo: marinoCanaan, texto: Colors.black87, suave: Colors.black54, tenue: Colors.black38, tarjeta: Colors.white, borde: bordeCanaan, azul: azulCanaan, dorado: doradoOscuro, morado: Color(0xFF6D28D9)); // Modo claro (como siempre)
  static const oscuro = ColoresCanaan(titulo: Color(0xFFE8EEF5), texto: Color(0xFFDDE4EC), suave: Color(0xFF9FB0C2), tenue: Color(0xFF6B7F94), tarjeta: tarjetaOscura, borde: bordeOscuro, azul: Color(0xFF7DB8E8), dorado: doradoCanaan, morado: Color(0xFFB794F6)); // Modo oscuro (contraste suficiente sobre fondo marino)

  @override // Reemplaza copyWith (lo exige Flutter)
  ColoresCanaan copyWith({Color? titulo, Color? texto, Color? suave, Color? tenue, Color? tarjeta, Color? borde, Color? azul, Color? dorado, Color? morado}) => ColoresCanaan(titulo: titulo ?? this.titulo, texto: texto ?? this.texto, suave: suave ?? this.suave, tenue: tenue ?? this.tenue, tarjeta: tarjeta ?? this.tarjeta, borde: borde ?? this.borde, azul: azul ?? this.azul, dorado: dorado ?? this.dorado, morado: morado ?? this.morado); // Copia con cambios

  @override // Reemplaza lerp (transición suave al cambiar de modo)
  ColoresCanaan lerp(ColoresCanaan? otro, double t) => otro == null ? this : ColoresCanaan( // Mezcla los colores según t (0 → este, 1 → el otro)
        titulo: Color.lerp(titulo, otro.titulo, t)!, texto: Color.lerp(texto, otro.texto, t)!, suave: Color.lerp(suave, otro.suave, t)!, // Textos
        tenue: Color.lerp(tenue, otro.tenue, t)!, tarjeta: Color.lerp(tarjeta, otro.tarjeta, t)!, borde: Color.lerp(borde, otro.borde, t)!, // Fondos
        azul: Color.lerp(azul, otro.azul, t)!, dorado: Color.lerp(dorado, otro.dorado, t)!, morado: Color.lerp(morado, otro.morado, t)!, // Acentos
      ); // Fin de lerp
} // Fin de ColoresCanaan

extension ColoresDelTema on BuildContext { // Atajo: context.cc.titulo, context.cc.suave…
  ColoresCanaan get cc => Theme.of(this).extension<ColoresCanaan>() ?? ColoresCanaan.claro; // Colores del modo actual

  bool get modoOscuro => Theme.of(this).brightness == Brightness.dark; // ¿Está en modo oscuro?

  Color vivo(Color color) { // Ícono o texto de color: igual en modo claro; en modo oscuro, una versión más CLARA y viva del mismo color (los colores oscuros se "apagan" sobre el fondo marino)
    if (!modoOscuro) return color; // Modo claro: el mismo
    final hsl = HSLColor.fromColor(color); // Color en tono, saturación y luz
    return hsl.withLightness(hsl.lightness < 0.68 ? 0.68 : hsl.lightness).withSaturation(hsl.saturation < 0.75 ? 0.75 : hsl.saturation).toColor(); // Más luz (mín. 68 %) y más saturación (mín. 75 %)
  } // Fin de vivo

  double get alfaBurbuja => modoOscuro ? 0.24 : 0.12; // Burbuja detrás de los íconos: más visible en modo oscuro
} // Fin de la extensión

ThemeData temaCanaan({bool oscuro = false}) { // Tema (colores y estilos) de toda la app; oscuro = true para el modo oscuro
  final colores = ColorScheme.fromSeed( // Arma una paleta completa a partir de un color
    seedColor: azulCanaan, // Color base: el azul de Canaán
    brightness: oscuro ? Brightness.dark : Brightness.light, // Claro u oscuro
    primary: oscuro ? const Color(0xFF7DB8E8) : azulCanaan, // Azul oficial (en oscuro, uno más claro para que se lea)
    secondary: doradoCanaan, // Dorado como color de acento
    surface: oscuro ? tarjetaOscura : null, // Superficies (ventanas, hojas) en marino oscuro
  ); // Fin de la paleta
  return ThemeData( // Devuelve el tema
    colorScheme: colores, // Usa la paleta de arriba
    useMaterial3: true, // Diseño Material 3 (el más moderno)
    fontFamily: 'Inter', // Fuente Inter en toda la app (la misma del panel; va dentro de la app, ver pubspec.yaml)
    scaffoldBackgroundColor: oscuro ? fondoOscuro : fondoCanaan, // Fondo igual en todas las pantallas (claro u oscuro)
    extensions: [oscuro ? ColoresCanaan.oscuro : ColoresCanaan.claro], // Colores que cambian con el modo (context.cc)
    appBarTheme: const AppBarTheme( // Estilo de las barras de título de cada pantalla
      backgroundColor: marinoCanaan, // Fondo marino
      foregroundColor: Colors.white, // Título e íconos en blanco
      centerTitle: true, // Título centrado
      systemOverlayStyle: barraSuperiorClara, // Hora y batería en blanco sobre el marino
      titleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), // Título en Inter, negrita
    ), // Fin del estilo de la barra
    cardTheme: CardThemeData( // Estilo de TODAS las tarjetas
      color: oscuro ? tarjetaOscura : Colors.white, // Blancas (marino oscuro en modo oscuro)
      elevation: 0, // Sin sombra fuerte (se usa un borde suave)
      surfaceTintColor: Colors.transparent, // Sin el tinte de color de Material 3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: oscuro ? bordeOscuro : bordeCanaan)), // Esquinas redondeadas + borde suave
    ), // Fin de las tarjetas
    navigationBarTheme: NavigationBarThemeData( // Estilo de la barra de abajo (menú): marino con la opción elegida en dorado
      backgroundColor: oscuro ? const Color(0xFF071019) : marinoCanaan, // Fondo marino (más oscuro en modo oscuro, para que se distinga del fondo)
      indicatorColor: doradoCanaan.withValues(alpha: 0.22), // "Pastilla" dorada suave detrás de la opción elegida
      iconTheme: WidgetStateProperty.resolveWith((estado) => IconThemeData( // Íconos según si están elegidos
            color: estado.contains(WidgetState.selected) ? doradoCanaan : Colors.white.withValues(alpha: 0.85), // Elegido: dorado; los demás: blanco claro (se lee mejor)
            size: 26, // Un poco más grandes (adultos mayores)
          )), // Fin de los íconos
      labelTextStyle: WidgetStateProperty.resolveWith((estado) => TextStyle( // Textos según si están elegidos
            color: estado.contains(WidgetState.selected) ? doradoCanaan : Colors.white.withValues(alpha: 0.85), // Elegido: dorado; los demás: blanco claro (se lee mejor)
            fontSize: 14, // Un poco más grande (adultos mayores)
            fontWeight: estado.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500, // Elegido en negrita
          )), // Fin de los textos
    ), // Fin del estilo del menú
  ); // Fin del tema
} // Fin de temaCanaan

const List<String> _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']; // Meses abreviados en español

String fechaCorta(DateTime? fecha) { // Convierte una fecha en texto corto, ej: "5 oct 2026"
  if (fecha == null) return ''; // Sin fecha → texto vacío
  return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}'; // Día, mes abreviado y año (los meses empiezan en 1, la lista en 0)
} // Fin de fechaCorta

const List<String> _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']; // Días (Dart: lunes = 1 … domingo = 7)
const List<String> _mesesLargos = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']; // Meses completos

String fechaSinDiaSemana(DateTime fecha) => '${fecha.day} de ${_mesesLargos[fecha.month - 1]}'; // Ej: "20 de noviembre"

String fechaLarga(DateTime fecha) => '${_dias[fecha.weekday - 1]}, ${fecha.day} de ${_mesesLargos[fecha.month - 1]}'; // Ej: "Jueves, 29 de octubre"

String horaCorta(DateTime hora) { // Hora en formato de 12 horas, ej: "8:00 am" o "7:30 pm"
  final h = hora.hour % 12 == 0 ? 12 : hora.hour % 12; // 0 y 12 → 12; 13 → 1…
  return '$h:${hora.minute.toString().padLeft(2, '0')} ${hora.hour < 12 ? 'am' : 'pm'}'; // Minutos con dos cifras
} // Fin de horaCorta

String saludoSegunHora(DateTime ahora) { // Saludo según la hora (igual que el Escritorio del panel)
  if (ahora.hour < 12) return 'Buenos días'; // Antes del mediodía
  if (ahora.hour < 19) return 'Buenas tardes'; // Antes de las 7 pm
  return 'Buenas noches'; // Desde las 7 pm
} // Fin de saludoSegunHora
