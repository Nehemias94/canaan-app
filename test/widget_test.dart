import 'dart:convert'; // jsonEncode (respuestas de mentira)
import 'package:flutter/material.dart'; // Componentes visuales (para buscar íconos y textos)
import 'package:http/http.dart' as http; // Para simular el internet en la prueba de "sin conexión"
import 'package:http/testing.dart'; // MockClient: internet de mentira
import 'package:canaan_app/servicios/conexion.dart'; // Copia local y "sinConexion"
import 'package:flutter_test/flutter_test.dart'; // Herramientas de pruebas automáticas de Flutter

import 'package:canaan_app/main.dart'; // Nuestra app
import 'package:canaan_app/tema.dart'; // Colores (fondo oscuro)
import 'package:canaan_app/modelos/actividad.dart'; // Molde de una actividad
import 'package:canaan_app/modelos/anuncio.dart'; // Molde de un anuncio
import 'package:canaan_app/modelos/evento.dart'; // Molde de un evento especial
import 'package:canaan_app/modelos/iglesia.dart'; // Molde de los datos de la iglesia
import 'package:canaan_app/modelos/predica.dart'; // Molde de una prédica
import 'package:canaan_app/servicios/api.dart'; // La API real (de ella se hereda la falsa)
import 'package:canaan_app/servicios/registro.dart'; // Registro del teléfono
import 'package:canaan_app/pantallas/ministerios.dart'; // Molde de un ministerio
import 'package:canaan_app/pantallas/video.dart'; // Pantalla del video (para cambiar el reproductor por uno de prueba)
import 'package:canaan_app/servicios/geocerca.dart'; // Geocerca (distancia)
import 'package:canaan_app/servicios/geocerca_fondo.dart'; // Elección del aviso con la app cerrada
import 'package:native_geofence/native_geofence.dart'; // GeofenceEvent (entrar / quedarse / salir)
import 'package:canaan_app/servicios/ubicacion.dart'; // Servicio de ubicación (para cambiarlo por uno de prueba)
import 'package:canaan_app/servicios/recordatorios.dart'; // Cálculo de los avisos de eventos
import 'package:canaan_app/servicios/compartir.dart'; // Compartir (se cambia por uno de mentira)
import 'package:canaan_app/servicios/preferencias.dart'; // Letra grande
import 'package:canaan_app/servicios/recarga.dart'; // "Timbre" para recargar Inicio al instante
import 'package:canaan_app/componentes/carruseles.dart'; // Ajustes de los carruseles (paso automático)
import 'package:canaan_app/servicios/radio.dart'; // Control de la radio (para cambiarlo por uno de prueba)
import 'dart:async'; // StreamController (estados de la radio de mentira)
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte (en pruebas, una de mentira en memoria)

class UbicacionFalsa implements ServicioUbicacion { // Ubicación de mentira: siempre responde el mismo punto
  UbicacionFalsa(this.punto); // Constructor
  Coordenadas? punto; // Dónde "está" el teléfono (null = sin permiso)
  int consultas = 0; // Cuántas veces se pidió la ubicación

  @override // Cumple la plantilla
  Future<Coordenadas?> posicionActual() async { consultas++; return punto; } // Devuelve el punto
} // Fin de UbicacionFalsa

class RadioFalsa implements ControlRadio { // Radio de mentira: no suena, solo anota lo que le piden
  final _estados = StreamController<EstadoRadio>.broadcast(); // Canal por donde avisa sus cambios
  String? urlReproducida; // Último enlace que se pidió reproducir
  bool cerrada = false; // ¿Se liberó al salir?

  @override // Cumple la plantilla
  Stream<EstadoRadio> get estados => _estados.stream; // Avisos de cambios

  @override // Cumple la plantilla
  Future<void> reproducir(String url, {String titulo = 'Radio Canaán'}) async { urlReproducida = url; _estados.add(EstadoRadio.sonando); } // "Suena"

  @override // Cumple la plantilla
  Future<void> detener() async => _estados.add(EstadoRadio.detenida); // "Se detiene"

  @override // Cumple la plantilla
  Future<void> cerrar() async => cerrada = true; // Anota que se cerró
} // Fin de RadioFalsa

class ApiFalsa extends Api { // API de mentira: responde datos fijos sin usar internet
  ApiFalsa({this.falla = false, this.radioAlAire = false, this.avisoNivel, this.conExtras = false, this.avisoArea}); // Constructor; falla = true simula que no hay conexión; avisoNivel = hay aviso urgente de ese nivel; conExtras = WhatsApp, ofrendas y versículo

  final bool falla; // ¿Simular error?
  final bool radioAlAire; // ¿La radio está al aire en el panel falso?
  final String? avisoNivel; // Nivel del aviso urgente del panel falso (null = sin aviso)
  final Map<String, dynamic>? avisoArea; // Área del aviso urgente (null = para todos)
  final bool conExtras; // ¿El panel falso tiene WhatsApp, ofrendas y versículo del día?
  bool enVivoEnPanel = true; // ¿Hay transmisión en vivo en el panel falso? (se puede cambiar a mitad de la prueba)
  bool anuncioAreaAhora = false; // ¿Hay un anuncio "Solo área" en su ventana ahora mismo?
  bool conRepeticion = false; // ¿Hubo transmisión hace poco? (tarjeta "¿Te lo perdiste?")
  String tituloPredica = 'La fe que mueve montañas'; // Título de la prédica falsa (se puede cambiar a mitad de la prueba)
  List<Map<String, dynamic>>? horario; // Horario de reemplazo (null = el culto del domingo en curso)
  List<Map<String, dynamic>> eventos = []; // Eventos especiales del panel falso
  Map<String, dynamic>? cuentaRegresiva; // Configuración de la cuenta regresiva (null = la del panel por defecto)
  bool anuncioConBoton = false; // ¿El anuncio "Ayuno" trae botón con enlace?

  @override // Reemplaza el método real
  Future<List<Anuncio>> obtenerAnuncios() async { // Anuncios falsos
    if (falla) throw Exception('sin internet'); // Simula el error
    return [ // Tres anuncios:
      Anuncio.desdeJson({'id': 1, 'titulo': 'Ayuno congregacional', 'mensaje': 'Este sábado de 6 am a 12 md.', 'tipo': 'todos', 'programacion': {'fecha_inicio': '2026-10-31', 'fecha_fin': '2026-10-31'}, 'visible_hasta': null, if (anuncioConBoton) 'boton': {'texto': 'Inscríbete', 'url': 'https://forms.gle/ayuno'}}), // Para todos: SE MUESTRA
      Anuncio.desdeJson({'id': 2, 'titulo': 'Bienvenido al templo', 'mensaje': 'Gracias por venir.', 'tipo': 'area'}), // Solo área: NO se muestra (geocerca, Paso 10)
      if (anuncioAreaAhora) Anuncio.desdeJson({'id': 9, 'titulo': 'Santa Cena hoy', 'mensaje': 'Pasa al frente al terminar la prédica.', 'tipo': 'area', 'ventana': {'inicia_en': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'termina_en': DateTime.now().add(const Duration(hours: 2)).toIso8601String()}}), // De área, en su ventana
      Anuncio.desdeJson({'id': 3, 'titulo': 'Anuncio vencido', 'mensaje': 'Ya pasó.', 'tipo': 'todos', 'visible_hasta': '2020-01-01T00:00:00-06:00'}), // Vencido: NO se muestra
    ]; // Fin de la lista
  } // Fin de obtenerAnuncios
  int registros = 0; // Cuántas veces se registró el teléfono
  int consultasIglesia = 0; // Cuántas veces se pidieron los datos de la iglesia
  final tokensValidos = <String>{}; // Llaves que el panel falso acepta

  @override // Reemplaza el método real
  Future<String> registrarDispositivo({required String uuid, required String plataforma}) async { // Registro falso
    if (falla) throw Exception('sin internet'); // Simula el error
    registros++; // Cuenta el registro
    final token = 'token-$registros'; // Llave nueva
    tokensValidos..clear()..add(token); // Como el panel real: la llave anterior deja de servir
    return token; // La devuelve
  } // Fin de registrarDispositivo

  int senales = 0; // Señales del en vivo recibidas
  bool transmisionActiva = true; // false = el panel finalizó la transmisión
  int salidas = 0; // Avisos de "dejé de ver"

  @override // Reemplaza el método real
  Future<SenalEnVivo> senalEnVivo(String token) async { // Señal falsa
    senales++; // La cuenta
    return SenalEnVivo(enVivo: transmisionActiva, viendoAhora: 3, siguienteSegundos: 30); // 3 personas viendo (o terminó)
  } // Fin de senalEnVivo

  @override // Reemplaza el método real
  Future<void> salirEnVivo(String token) async => salidas++; // Cuenta la salida

  int peticiones = 0; // Peticiones de oración recibidas
  String? ultimoNombre; // Nombre de la última petición (para revisar qué se envió)

  @override // Reemplaza el método real
  Future<RespuestaPeticion> enviarPeticion({required String token, required String nombre, required String peticion}) async { // Petición falsa
    if (!tokensValidos.contains(token)) throw const ErrorApi(401); // Llave desconocida → 401
    if (peticiones >= 3) throw const ErrorApi(429, 'Ya enviaste 3 peticiones hoy. Podrás enviar otra en 5 horas.'); // Límite de 3 por día, con el mensaje del panel
    peticiones++; // Cuenta la petición
    ultimoNombre = nombre; // Guarda el nombre enviado
    return RespuestaPeticion(mensaje: 'Recibimos tu petición. Estaremos orando por ti.', restantesHoy: 3 - peticiones); // Respuesta como la del panel
  } // Fin de enviarPeticion

  @override // Reemplaza el método real
  Future<int> verificarToken(String token) async { // Verificación falsa
    if (falla) throw Exception('sin internet'); // Simula el error
    if (!tokensValidos.contains(token)) throw const ErrorApi(401); // Llave desconocida → 401, como el panel real
    return 7; // Número del teléfono en el panel falso
  } // Fin de verificarToken

  @override // Reemplaza el método real
  Future<Iglesia> obtenerIglesia() async { // Datos falsos de la iglesia
    consultasIglesia++; // Cuenta la consulta
    if (falla) throw Exception('sin internet'); // Simula el error
    return Iglesia.desdeJson({ // JSON igual al de la API
      'nombre': 'Ministerio Cristiano Canaán', // Nombre
      'ubicacion': {'latitud': 13.6929, 'longitud': -89.2182, 'radio_metros': 200}, // Templo en San Salvador, radio 200 m
      'en_vivo': {'activo': enVivoEnPanel, 'titulo': 'Culto dominical', 'youtube_id': 'envivo123'}, // Transmisión activa
      if (conExtras) 'contacto': {'whatsapp': '50370000000'}, // WhatsApp
      if (conExtras) 'ofrendas': {'mostrar': true, 'mensaje': 'Dios ama al dador alegre.', 'cuentas': [{'banco': 'Banco Agrícola', 'tipo': 'Ahorro', 'numero': '3000-123456', 'titular': 'MCC'}], 'qr_url': null}, // Ofrendas
      if (conExtras) 'versiculo_dia': {'texto': 'Jehová es mi pastor; nada me faltará.', 'referencia': 'Salmos 23:1'}, // Versículo
      if (avisoNivel != null) 'aviso_urgente': {'activo': true, 'titulo': 'Culto cancelado', 'mensaje': 'Hoy no habrá culto por la lluvia.', 'nivel': avisoNivel, 'area': avisoArea}, // Aviso urgente
      if (cuentaRegresiva != null) 'cuenta_regresiva': cuentaRegresiva, // Configuración de la cuenta regresiva
      if (conRepeticion) 'repeticion': {'titulo': 'Culto dominical', 'youtube_id': 'repeti123', 'termino': DateTime.now().toIso8601String()}, // Repetición del culto
      if (radioAlAire) 'radio': {'disponible': true, 'titulo': 'Culto dominical', 'stream_url': 'https://radio.ejemplo/canaan', 'modo': 'siempre'}, // Radio 24/7
 // Transmisión activa
    }); // Fin de los datos
  } // Fin de obtenerIglesia

  @override // Reemplaza el método real
  @override // Reemplaza el método real
  Future<List<SerieResumen>> obtenerSeries() async => conSerie ? [const SerieResumen(id: 2, nombre: 'La familia', partes: 2)] : []; // Series falsas

  bool conSerie = false; // ¿El panel falso tiene una serie de 2 partes?

  @override // Reemplaza el método real
  Future<List<Ministerio>> obtenerMinisterios() async => [const Ministerio(id: 1, nombre: 'Ministerio de jóvenes', horario: 'Sábados 4:00 pm', lider: 'Carlos', whatsapp: '50370001234')]; // Un ministerio falso

  @override // Reemplaza el método real
  Future<List<Predica>> obtenerPredicas({String buscar = '', int? serieId}) async { // Prédicas falsas
    if (falla) throw Exception('sin internet'); // Simula el error
    if (conSerie) { // Panel con serie
      final parte1 = Predica.desdeJson({'id': 21, 'titulo': 'Diseño de Dios', 'youtube_id': 'serie1xxxxx', 'bosquejo': '1. Dios diseñó la familia — Génesis 2:24', 'serie': {'id': 2, 'nombre': 'La familia', 'parte': 1, 'total': 2, 'siguiente': {'id': 22, 'titulo': 'Padres que bendicen', 'parte': 2}}}); // Parte 1
      final parte2 = Predica.desdeJson({'id': 22, 'titulo': 'Padres que bendicen', 'youtube_id': 'serie2xxxxx', 'serie': {'id': 2, 'nombre': 'La familia', 'parte': 2, 'total': 2}}); // Parte 2
      return serieId == 2 ? [parte1, parte2] : [parte1, parte2, Predica.desdeJson({'id': 1, 'titulo': tituloPredica})]; // Con filtro: solo la serie
    } // Fin del if
    return [Predica.desdeJson({'id': 1, 'titulo': tituloPredica, 'predicador': 'Pastor Juan', 'fecha': '2026-10-05', 'destacada': true, 'youtube_id': 'predica123', 'descripcion': 'Mateo 17:20'})]; // Una prédica destacada
  } // Fin de obtenerPredicas

  @override // Reemplaza el método real
  Future<List<Evento>> obtenerEventos() async => eventos.map(Evento.desdeJson).toList(); // Eventos falsos

  List<Map<String, dynamic>> pasados = []; // Eventos pasados con fotos del panel falso

  @override // Reemplaza el método real
  Future<List<Evento>> obtenerEventosPasados() async => pasados.map(Evento.desdeJson).toList(); // Pasados falsos

  final interesesMarcados = <int, bool>{}; // 🔔 avisadas al panel falso (evento → activo)
  InscripcionEvento? inscripcionFalsa; // Inscripción de este teléfono en el panel falso

  @override // Reemplaza el método real
  Future<void> marcarInteres({required String token, required int eventoId, required bool activo}) async => interesesMarcados[eventoId] = activo; // Lo anota

  @override // Reemplaza el método real
  Future<EstadoInscripcion> miInscripcion({required String token, required int eventoId}) async => EstadoInscripcion(mia: inscripcionFalsa, abiertas: true, restantes: 10); // Siempre abiertas, 10 lugares

  @override // Reemplaza el método real
  Future<String> inscribirEvento({required String token, required int eventoId, required String nombre, required String telefono, required int personas, String nota = ''}) async { // Inscripción falsa
    inscripcionFalsa = InscripcionEvento(nombre: nombre, telefono: telefono, personas: personas, nota: nota); // La guarda
    return '¡Listo! Quedaste inscrito.'; // Mensaje
  } // Fin de inscribirEvento

  @override // Reemplaza el método real
  Future<String> cancelarInscripcion({required String token, required int eventoId}) async { inscripcionFalsa = null; return 'Cancelamos tu inscripción.'; } // Cancela

  @override // Reemplaza el método real
  Future<List<Actividad>> obtenerActividades() async { // Horario falso
    if (falla) throw Exception('sin internet'); // Simula el error
    if (horario != null) return horario!.map(Actividad.desdeJson).toList(); // Horario de reemplazo
    return [Actividad.desdeJson({'id': 1, 'nombre': 'Culto general', 'dia_semana': 0, 'dia': 'Domingo', 'horario': '10:00 am – 12:00 pm', 'se_transmite': true, 'en_curso': true})]; // Un culto el domingo, en curso
  } // Fin de obtenerActividades
} // Fin de ApiFalsa

void pantallaAlta(WidgetTester tester) { // Agranda la pantalla de prueba (para ver listas largas sin desplazarse)
  tester.view.physicalSize = const Size(800, 2000); // 800 x 2000 puntos
  tester.view.devicePixelRatio = 1; // 1 píxel = 1 punto
  addTearDown(tester.view.reset); // Al terminar la prueba, vuelve al tamaño normal
} // Fin de pantallaAlta

void main() { // Punto de arranque de las pruebas
  setUp(() { // Antes de cada prueba:
    FlutterSecureStorage.setMockInitialValues({}); // Caja fuerte vacía y en memoria
    Carruseles.pasoAutomatico = null; // Los carruseles NO pasan solos (así las tarjetas están donde la prueba las espera); la prueba 54 lo enciende
    PantallaVideo.reproductorDePrueba = const SizedBox(height: 200, child: Text('[video de prueba]')); // Reproductor de mentira (YouTube no carga en las pruebas)
  }); // Fin de setUp

  testWidgets('Inicio muestra el nombre y EN VIVO', (WidgetTester tester) async { // Prueba 1
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Dibuja la app con la API falsa
    expect(find.text('Conectando…'), findsWidgets); // Primero sale "Conectando…" (en las pestañas que cargan)
    await tester.pumpAndSettle(); // Espera a que lleguen los datos y se redibuje
    expect(find.text('Ministerio Cristiano Canaán'), findsOneWidget); // Sale el nombre
    expect(find.text('● EN VIVO'), findsOneWidget); // Sale la etiqueta EN VIVO (tarjeta con franja roja)
    expect(find.text('Culto dominical'), findsOneWidget); // Con el título de la transmisión
  }); // Fin de la prueba 1

  testWidgets('El menú cambia a Prédicas, y Horario se abre desde Inicio', (WidgetTester tester) async { // Prueba 2
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Dibuja la app
    await tester.pumpAndSettle(); // Espera los datos
    await tester.tap(find.text('Prédicas')); // Toca "Prédicas" en el menú de abajo
    await tester.pumpAndSettle(); // Espera el cambio
    expect(find.text('La fe que mueve montañas'), findsOneWidget); // Sale la prédica
    expect(find.text('★ DESTACADA'), findsOneWidget); // Con la etiqueta de destacada
    expect(find.text('Pastor Juan · 5 oct 2026'), findsOneWidget); // Predicador y fecha en español
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Inicio'))); // Vuelve a Inicio
    await tester.pumpAndSettle(); // Espera
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Horario')), findsNothing); // Horario ya NO está en el menú
    await tester.tap(find.text('Horario')); // Toca el acceso rápido "Horario" de Inicio
    await tester.pumpAndSettle(); // Espera el cambio
    expect(find.text('DOMINGO'), findsOneWidget); // Encabezado del día
    expect(find.text('Culto general'), findsOneWidget); // La actividad
    expect(find.text('Ahora'), findsOneWidget); // Marcada como en curso
    expect(find.byIcon(Icons.live_tv), findsOneWidget); // Con el ícono de transmisión
  }); // Fin de la prueba 2

  testWidgets('Muestra Reintentar si no hay conexión', (WidgetTester tester) async { // Prueba 3
    pantallaAlta(tester); // Pantalla alta: la lista de Servicios cabe completa
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(falla: true))); // Dibuja la app con una API que falla
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Reintentar'), findsWidgets); // Sale el botón Reintentar
    await tester.tap(find.text('Servicios')); // Va a la pestaña Más
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este teléfono no está conectado'), findsOneWidget); // El registro también falló y lo avisa
  }); // Fin de la prueba 3

  testWidgets('Al abrir, registra el teléfono y Más lo muestra', (WidgetTester tester) async { // Prueba 4
    pantallaAlta(tester); // Pantalla alta: la lista de Servicios cabe completa
    final api = ApiFalsa(); // API falsa (para revisar cuántas veces se registró)
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Servicios')); // Va a la pestaña Más
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Teléfono conectado con la iglesia'), findsOneWidget); // Registrado
    expect(find.textContaining('Número 7'), findsOneWidget); // Con el número del panel falso
    expect(api.registros, 1); // Se registró una sola vez (Inicio y Más comparten el mismo proceso)
  }); // Fin de la prueba 4

  test('Reutiliza la llave guardada y se registra de nuevo si el panel la rechaza (401)', () async { // Prueba 5 (sin pantalla)
    final api = ApiFalsa(); // Panel falso
    await RegistroDispositivo(api: api).asegurar(); // 1ª apertura: se registra
    expect(api.registros, 1); // Una vez
    await RegistroDispositivo(api: api).asegurar(); // 2ª apertura: la llave guardada sirve
    expect(api.registros, 1); // No se registra otra vez
    api.tokensValidos.clear(); // El panel "olvida" la llave (ej: se borró el teléfono)
    await RegistroDispositivo(api: api).asegurar(); // 3ª apertura: recibe 401...
    expect(api.registros, 2); // ...y se registra de nuevo solo
    const almacen = FlutterSecureStorage(); // Caja fuerte (de mentira)
    expect(await almacen.read(key: 'dispositivo_token'), 'token-2'); // Guardó la llave nueva
  }); // Fin de la prueba 5

  testWidgets('Petición de oración: valida, envía y respeta el límite de 3', (WidgetTester tester) async { // Prueba 6
    pantallaAlta(tester); // Pantalla alta: la lista de Servicios cabe completa
    final api = ApiFalsa(); // Panel falso
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Servicios')); // Pestaña Más
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Petición de oración')); // Abre el formulario
    await tester.pumpAndSettle(); // Espera
    expect(find.textContaining('confidencial'), findsOneWidget); // Sale la aclaración de privacidad

    await tester.ensureVisible(find.text('Enviar petición')); // Desplaza hasta el botón (la pantalla de prueba es pequeña)
    await tester.tap(find.text('Enviar petición')); // Intenta enviar vacía
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Escribe tu petición.'), findsOneWidget); // Error bajo el campo
    expect(api.peticiones, 0); // No se envió nada

    await tester.enterText(find.widgetWithText(TextFormField, 'Tu petición'), 'Por la salud de mi madre'); // Escribe la petición
    await tester.ensureVisible(find.text('Enviar petición')); // Desplaza hasta el botón (la pantalla de prueba es pequeña)
    await tester.tap(find.text('Enviar petición')); // Envía (sin nombre = anónima)
    await tester.pumpAndSettle(); // Espera
    expect(find.text('¡Petición enviada!'), findsOneWidget); // Ventana de confirmación
    expect(find.textContaining('Puedes enviar 2 más hoy.'), findsOneWidget); // Le quedan 2
    expect(api.peticiones, 1); // Llegó una
    expect(api.ultimoNombre, ''); // Sin nombre (anónima)
    await tester.tap(find.text('Amén')); // Cierra la ventana
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Teléfono conectado con la iglesia'), findsOneWidget); // Volvió a la pestaña Más

    api.peticiones = 3; // Simula que ya envió 3 hoy
    await tester.tap(find.text('Petición de oración')); // Abre el formulario otra vez
    await tester.pumpAndSettle(); // Espera
    await tester.enterText(find.widgetWithText(TextFormField, 'Tu petición'), 'Otra petición'); // Escribe
    await tester.ensureVisible(find.text('Enviar petición')); // Desplaza hasta el botón (la pantalla de prueba es pequeña)
    await tester.tap(find.text('Enviar petición')); // Envía
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Ya enviaste 3 peticiones hoy. Podrás enviar otra en 5 horas.'), findsOneWidget); // Muestra el mensaje del panel
  }); // Fin de la prueba 6
  testWidgets('En vivo: abre el video, manda señales y avisa al salir', (WidgetTester tester) async { // Prueba 7
    final api = ApiFalsa(); // Panel falso
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Ver transmisión')); // Botón dorado de Inicio
    await tester.pumpAndSettle(); // Espera
    expect(find.text('[video de prueba]'), findsOneWidget); // Se abrió el reproductor
    expect(find.text('3 personas viendo'), findsOneWidget); // Muestra cuántos ven (respuesta de la primera señal)
    expect(api.senales, 1); // Mandó la primera señal al abrir
    await tester.pump(const Duration(seconds: 31)); // Pasan 31 segundos...
    expect(api.senales, 2); // ...y mandó la segunda señal
    await tester.pageBack(); // Vuelve atrás (flecha de la barra)
    await tester.pumpAndSettle(); // Espera
    expect(api.salidas, 1); // Avisó "dejé de ver"
    await tester.pump(const Duration(seconds: 60)); // Pasa un minuto más...
    expect(api.senales, 2); // ...y ya no manda señales
  }); // Fin de la prueba 7

  testWidgets('Prédica con video: al tocarla abre el reproductor', (WidgetTester tester) async { // Prueba 8
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Prédicas')); // Pestaña Prédicas
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('La fe que mueve montañas')); // Toca la prédica
    await tester.pumpAndSettle(); // Espera
    expect(find.text('[video de prueba]'), findsOneWidget); // Se abrió el reproductor
    expect(find.text('Mateo 17:20'), findsOneWidget); // Con la descripción debajo
    expect(find.text('personas viendo', findRichText: false), findsNothing); // Sin franja de en vivo
  }); // Fin de la prueba 8
  testWidgets('Radio fuera del aire: lo avisa', (WidgetTester tester) async { // Prueba 9
    final radio = RadioFalsa(); // Radio de mentira
    ControlRadio.crear = () => radio; // La app usará la de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Panel SIN radio al aire
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Servicios')); // Pestaña Más
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Escuchar radio')); // Abre la radio
    await tester.pumpAndSettle(); // Espera
    expect(find.textContaining('no está al aire'), findsOneWidget); // Avisa que no está al aire
  }); // Fin de la prueba 9

  testWidgets('Radio al aire: reproduce, detiene y se libera al salir', (WidgetTester tester) async { // Prueba 10
    final radio = RadioFalsa(); // Radio de mentira
    ControlRadio.crear = () => radio; // La app usará la de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(radioAlAire: true))); // Panel con la radio al aire
    await tester.pumpAndSettle(); // Espera
    expect(find.text('🎧 Radio al aire · Escuchar'), findsOneWidget); // Inicio muestra la etiqueta dorada
    await tester.tap(find.text('🎧 Radio al aire · Escuchar')); // La toca
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Al aire las 24 horas'), findsOneWidget); // Modo 24/7
    await tester.tap(find.bySemanticsLabel('Escuchar')); // Botón grande de reproducir
    await tester.pumpAndSettle(); // Espera
    expect(radio.urlReproducida, 'https://radio.ejemplo/canaan'); // Reproduce el enlace del panel
    expect(find.text('Escuchando en vivo'), findsOneWidget); // Muestra que suena
    await tester.tap(find.bySemanticsLabel('Detener')); // Botón detener
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Toca para escuchar'), findsOneWidget); // Se detuvo
    await tester.pageBack(); // Sale de la pantalla
    await tester.pumpAndSettle(); // Espera
    expect(radio.cerrada, isTrue); // Liberó el reproductor
  }); // Fin de la prueba 10
  testWidgets('En vivo: si el panel la finaliza, quita el video y deja de enviar señales', (WidgetTester tester) async { // Prueba 11
    final api = ApiFalsa(); // Panel falso
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Ver transmisión')); // Abre el en vivo
    await tester.pumpAndSettle(); // Espera
    expect(find.text('[video de prueba]'), findsOneWidget); // Se ve el video
    api.transmisionActiva = false; // En el panel: "Finalizar transmisión"
    await tester.pump(const Duration(seconds: 31)); // En la siguiente señal (30 s)...
    await tester.pumpAndSettle(); // ...se redibuja
    expect(find.text('[video de prueba]'), findsNothing); // ...el video desapareció (ya no suena)
    expect(find.text('La transmisión terminó'), findsOneWidget); // ...y sale el aviso
    final senales = api.senales; // Señales hasta ahora
    await tester.pump(const Duration(seconds: 90)); // Pasa minuto y medio...
    expect(api.senales, senales); // ...y no manda más señales
    await tester.tap(find.text('Volver al inicio')); // Botón del aviso
    await tester.pumpAndSettle(); // Espera
    expect(api.salidas, 0); // No hace falta avisar "salir" (la transmisión ya terminó)
  }); // Fin de la prueba 11
  testWidgets('Inicio muestra solo los anuncios para todos y vigentes', (WidgetTester tester) async { // Prueba 12
    pantallaAlta(tester); // Pantalla alta: el carrusel se ve sin desplazar
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    expect(find.text('ANUNCIOS'), findsOneWidget); // Encabezado de la sección
    expect(find.text('TOCA PARA VER MÁS'), findsOneWidget); // Línea corta en la tarjeta pequeña (sin la fecha de envío)
    expect(find.text('Este sábado de 6 am a 12 md.'), findsNothing); // El mensaje NO va en Inicio (Inicio queda corto)
    expect(find.text('Bienvenido al templo'), findsNothing); // El de área NO
    expect(find.text('Anuncio vencido'), findsNothing); // El vencido NO
    await tester.tap(find.text('Ayuno congregacional')); // Toca la tarjeta
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este sábado de 6 am a 12 md.'), findsOneWidget); // El detalle muestra el mensaje completo
    expect(find.text('31 oct 2026'), findsOneWidget); // Y su fecha
  }); // Fin de la prueba 12

  testWidgets('Inicio se actualiza solo: aparece el en vivo sin tocar nada', (WidgetTester tester) async { // Prueba 13
    final api = ApiFalsa()..enVivoEnPanel = false; // Panel SIN transmisión al abrir
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Ver transmisión'), findsNothing); // No hay botón
    api.enVivoEnPanel = true; // En el panel: "Iniciar en vivo"
    await tester.pump(const Duration(seconds: 91)); // Pasan 91 segundos (la app revisa cada 90)...
    await tester.pumpAndSettle(); // ...y se redibuja
    expect(find.text('Ver transmisión'), findsOneWidget); // Apareció el botón solo
    api.enVivoEnPanel = false; // En el panel: "Finalizar"
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); // La persona sale de la app...
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); // ...y vuelve
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Ver transmisión'), findsNothing); // Al volver se actualizó enseguida: ya no hay botón
  }); // Fin de la prueba 13
  test('Distancia: 100 m al norte del templo están a ~100 m', () { // Prueba 14 (fórmula)
    final metros = Geocerca.distanciaMetros(13.6929, -89.2182, 13.6929 + 0.000899, -89.2182); // 0.000899° de latitud ≈ 100 m
    expect(metros, closeTo(100, 2)); // 100 m ± 2
  }); // Fin de la prueba 14

  testWidgets('Geocerca: sin anuncios de área NO pide la ubicación', (WidgetTester tester) async { // Prueba 15
    final gps = UbicacionFalsa(const Coordenadas(13.6929, -89.2182)); // "En el templo"
    ServicioUbicacion.crear = () => gps; // La app usará la de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Sin anuncio de área en ventana
    await tester.pumpAndSettle(); // Espera
    expect(gps.consultas, 0); // Nunca pidió la ubicación
  }); // Fin de la prueba 15

  testWidgets('Geocerca: en el templo muestra la bienvenida UNA sola vez (sin tarjeta fija)', (WidgetTester tester) async { // Prueba 16
    final gps = UbicacionFalsa(const Coordenadas(13.6930, -89.2183)); // ~15 m del templo
    ServicioUbicacion.crear = () => gps; // Ubicación de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa()..anuncioAreaAhora = true)); // Con anuncio de área en ventana
    await tester.pumpAndSettle(); // Espera
    expect(find.text('¡Qué bueno que estás aquí!'), findsOneWidget); // Ventana de bienvenida
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Pasa al frente al terminar la prédica.')), findsOneWidget); // Con el anuncio dentro de la ventana
    await tester.tap(find.text('Entendido')); // La cierra
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Santa Cena hoy'), findsNothing); // Ya no queda una tarjeta fija en Inicio (se muestra una sola vez)
    await tester.pump(const Duration(seconds: 91)); // Siguiente actualización automática...
    await tester.pumpAndSettle(); // ...
    expect(find.text('¡Qué bueno que estás aquí!'), findsNothing); // ...NO repite la bienvenida
    expect(gps.consultas, 1); // ...ni vuelve a pedir la ubicación (ya se mostró)
  }); // Fin de la prueba 16

  testWidgets('Geocerca: lejos del templo no muestra nada', (WidgetTester tester) async { // Prueba 17
    final gps = UbicacionFalsa(const Coordenadas(13.7100, -89.2182)); // ~1.9 km al norte
    ServicioUbicacion.crear = () => gps; // Ubicación de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa()..anuncioAreaAhora = true)); // Con anuncio de área en ventana
    await tester.pumpAndSettle(); // Espera
    expect(gps.consultas, 1); // Sí pidió la ubicación (había anuncio de área)
    expect(find.text('¡Qué bueno que estás aquí!'), findsNothing); // Pero está lejos: nada
    expect(find.text('Santa Cena hoy'), findsNothing); // Ni tarjeta
  }); // Fin de la prueba 17

  testWidgets('Geocerca: si ya salió como notificación, al abrir la app NO se repite', (WidgetTester tester) async { // Prueba 18
    final gps = UbicacionFalsa(const Coordenadas(13.6930, -89.2183)); // En el templo
    ServicioUbicacion.crear = () => gps; // Ubicación de mentira
    await const FlutterSecureStorage().write(key: 'anuncios_area_mostrados', value: '[9]'); // El aviso de fondo ya mostró el anuncio 9 como notificación
    await tester.pumpWidget(CanaanApp(api: ApiFalsa()..anuncioAreaAhora = true)); // Abre la app con ese anuncio en su ventana
    await tester.pumpAndSettle(); // Espera
    expect(find.text('¡Qué bueno que estás aquí!'), findsNothing); // No repite la bienvenida
    expect(gps.consultas, 0); // Ni siquiera pide la ubicación (no hay nada pendiente)
  }); // Fin de la prueba 18

  test('Geocerca: guarda una copia de los anuncios de área y la lee igual', () async { // Prueba 19
    final geocerca = Geocerca(); // Geocerca con la caja fuerte de mentira
    final anuncios = await (ApiFalsa()..anuncioAreaAhora = true).obtenerAnuncios(); // Anuncios de mentira (2 de área, 2 para todos)
    await geocerca.guardarCopia(anuncios); // Guarda la copia
    final copia = await geocerca.leerCopia(); // La lee
    expect(copia, isNotNull); // Existe
    expect(copia!.anuncios.map((a) => a.id), [2, 9]); // Solo los de área
    expect(copia.anuncios.last.enVentana(DateTime.now()), isTrue); // La ventana se conservó bien (sigue "en ventana")
    expect(DateTime.now().difference(copia.guardada).inSeconds, lessThan(5)); // Guardada hace un momento
  }); // Fin de la prueba 19

  testWidgets('Aviso urgente: el timbre recarga Inicio al instante (sin esperar 90 s)', (WidgetTester tester) async { // Prueba 20
    final api = ApiFalsa(); // Panel falso
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Primera carga
    final antes = api.consultasIglesia; // Consultas hasta ahora
    tocarTimbreInicio(); // Llega el aviso silencioso del panel
    await tester.pumpAndSettle(); // Espera (mucho menos de 90 s)
    expect(api.consultasIglesia, antes + 1); // Volvió a pedir los datos al instante
  }); // Fin de la prueba 20

  testWidgets('Biblia: pestaña en el menú con botones grandes', (WidgetTester tester) async { // Prueba 21
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Biblia'))); // Toca "Biblia" en el menú de abajo (también hay un acceso rápido con ese nombre en Inicio)
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Biblia · Reina-Valera 1960'), findsOneWidget); // Título de la pestaña
    expect(find.text('A+'), findsOneWidget); // Botón para agrandar la letra
    expect(find.text('Buscar'), findsOneWidget); // Botón buscar
    expect(find.text('Abrir la Biblia'), findsOneWidget); // En la PC (sin WebView) ofrece abrirla afuera
  }); // Fin de la prueba 21

  testWidgets('Inicio: accesos rápidos sin repetir el menú y tarjeta Próximo culto', (WidgetTester tester) async { // Prueba 22
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera (presentación incluida)
    expect(find.text('Radio'), findsOneWidget); // Botón Radio
    expect(find.text('Oración'), findsOneWidget); // Botón Oración
    expect(find.text('Cómo llegar'), findsOneWidget); // Botón Cómo llegar (el panel falso tiene ubicación)
    expect(find.text('YouTube'), findsNothing); // Sin canal en el panel falso: no se muestra
    expect(find.text('Biblia'), findsOneWidget); // "Biblia" solo en el menú de abajo (ya no repetido)
    expect(find.text('AHORA EN LA IGLESIA'), findsOneWidget); // Tarjeta del culto en curso
    expect(find.text('Ahora · Culto general'), findsOneWidget); // Con su nombre
    await tester.tap(find.text('Ahora · Culto general')); // La toca
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Horario de cultos'), findsOneWidget); // Abre la pestaña Horario
  }); // Fin de la prueba 22

  testWidgets('Presentación: el menú de abajo se oculta mientras se ve el logo', (WidgetTester tester) async { // Prueba 23
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pump(const Duration(seconds: 1)); // A mitad de la presentación
    expect(find.byType(NavigationBar), findsNothing); // Sin menú (pantalla completa)
    await tester.pumpAndSettle(); // Termina la presentación
    expect(find.byType(NavigationBar), findsOneWidget); // Aparece el menú
    expect(find.text('Servicios'), findsOneWidget); // Con "Servicios" (antes "Más")
  }); // Fin de la prueba 23

  testWidgets('Aviso urgente: se ve como ALERTA y arriba de todo', (WidgetTester tester) async { // Prueba 24
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(avisoNivel: 'urgente'))); // Panel con aviso urgente
    await tester.pumpAndSettle(); // Espera
    expect(find.text('AVISO URGENTE'), findsOneWidget); // Etiqueta de alerta
    expect(find.text('Culto cancelado'), findsOneWidget); // Título
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget); // Ícono de advertencia
    final alerta = tester.getTopLeft(find.text('AVISO URGENTE')).dy; // Altura de la alerta en la pantalla
    final botones = tester.getTopLeft(find.text('Oración')).dy; // Altura de los accesos rápidos
    expect(alerta, lessThan(botones)); // La alerta va ANTES (más arriba) que los botones
  }); // Fin de la prueba 24

  testWidgets('Versículo del día: se muestra y se comparte', (WidgetTester tester) async { // Prueba 25
    pantallaAlta(tester); // Pantalla alta: EN VIVO va arriba y empuja el versículo hacia abajo
    String? compartido; // Lo que se intentó compartir
    Compartir.compartir = (texto) async => compartido = texto; // Compartir de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(conExtras: true))); // Panel con versículo
    await tester.pumpAndSettle(); // Espera
    expect(find.text('VERSÍCULO DEL DÍA'), findsOneWidget); // Tarjeta
    expect(find.text('Salmos 23:1'), findsOneWidget); // Cita
    await tester.tap(find.text('Compartir')); // Toca Compartir
    await tester.pump(); // Espera
    expect(compartido, contains('Jehová es mi pastor')); // Texto del versículo
    expect(compartido, contains('Ministerio Cristiano Canaán')); // Con la firma
  }); // Fin de la prueba 25

  testWidgets('Servicios: WhatsApp y Ofrendas (con copiar número)', (WidgetTester tester) async { // Prueba 26
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(conExtras: true))); // Panel con WhatsApp y ofrendas
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Servicios'))); // Pestaña Servicios
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Escríbenos por WhatsApp'), findsOneWidget); // Botón de WhatsApp
    expect(find.text('Letra grande'), findsOneWidget); // Preferencia de letra
    await tester.tap(find.text('Ofrendas y diezmos')); // Abre ofrendas
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Banco Agrícola'), findsOneWidget); // Cuenta
    expect(find.text('3000-123456'), findsOneWidget); // Número
    expect(find.text('Copiar número de cuenta'), findsOneWidget); // Botón copiar
  }); // Fin de la prueba 26

  testWidgets('Letra grande: agranda los textos de la app', (WidgetTester tester) async { // Prueba 27
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    final antes = tester.getSize(find.text('ANUNCIOS')).height; // Alto del texto normal
    Preferencias.letraGrande.value = true; // Activa letra grande
    await tester.pumpAndSettle(); // Redibuja
    final despues = tester.getSize(find.text('ANUNCIOS')).height; // Alto con letra grande
    Preferencias.letraGrande.value = false; // La deja como estaba (para las demás pruebas)
    expect(despues, greaterThan(antes)); // Más grande
  }); // Fin de la prueba 27

  testWidgets('Repetición: "¿Te lo perdiste?" abre el video con los botones', (WidgetTester tester) async { // Prueba 28
    String? compartido; // Lo que se intentó compartir
    Compartir.compartir = (texto) async => compartido = texto; // Compartir de mentira
    final api = ApiFalsa(conExtras: true)..enVivoEnPanel = false..conRepeticion = true; // Sin en vivo, con repetición y ofrendas
    tester.view.physicalSize = const Size(800, 1800); // Pantalla alta: caben todas las tarjetas sin desplazarse
    tester.view.devicePixelRatio = 1; // 1 píxel = 1 punto
    addTearDown(tester.view.reset); // Al terminar, vuelve al tamaño normal
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    expect(find.text('¿TE LO PERDISTE?'), findsOneWidget); // Tarjeta de repetición
    await tester.tap(find.text('Ver repetición')); // Abre el video
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Repetición · Ministerio Cristiano Canaán'), findsOneWidget); // Subtítulo
    expect(find.text('Pedir oración'), findsOneWidget); // Botón oración
    expect(find.text('Ofrendar'), findsOneWidget); // Botón ofrendas (el panel las muestra)
    await tester.tap(find.text('Compartir')); // Comparte
    await tester.pump(); // Espera
    expect(compartido, contains('https://youtu.be/repeti123')); // Con el enlace del video
    await tester.tap(find.text('Pedir oración')); // Abre la petición
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Enviar petición'), findsOneWidget); // Formulario de petición
  }); // Fin de la prueba 28

  testWidgets('Cuenta regresiva del próximo culto transmitido', (WidgetTester tester) async { // Prueba 29
    final api = ApiFalsa()..enVivoEnPanel = false; // Sin en vivo
    final proxima = DateTime.now().add(const Duration(hours: 1, minutes: 15, seconds: 20)); // Dentro de 1 h 15 min (dentro de las 2 horas de Configuración)
    api.horario = [{'id': 5, 'nombre': 'Culto de oración', 'dia_semana': proxima.weekday % 7, 'dia': 'Hoy', 'horario': '7:00 pm', 'se_transmite': true, 'en_curso': false, 'proxima': proxima.toIso8601String()}]; // Un culto transmitido
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    expect(find.text('En vivo en la app · faltan 1\u00A0h\u00A015\u00A0min'), findsOneWidget); // Cuenta regresiva (con espacios que no se cortan)
    expect(find.text('¿TE LO PERDISTE?'), findsNothing); // Sin repetición
  }); // Fin de la prueba 29

  testWidgets('En vivo: botones bajo el video (sin Ofrendar si el panel no lo muestra)', (WidgetTester tester) async { // Prueba 30
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // En vivo, sin ofrendas
    await tester.pumpAndSettle(); // Espera
    await tester.ensureVisible(find.text('Ver transmisión')); // Se desplaza hasta el botón
    await tester.tap(find.text('Ver transmisión')); // Abre el en vivo
    await tester.pump(const Duration(seconds: 1)); // Espera (sin pumpAndSettle: hay señales periódicas)
    await tester.pump(const Duration(seconds: 1)); // Termina la animación de entrada
    expect(find.text('Pedir oración'), findsOneWidget); // Botón oración
    expect(find.text('Compartir'), findsOneWidget); // Botón compartir
    expect(find.text('Ofrendar'), findsNothing); // Sin ofrendas en el panel
  }); // Fin de la prueba 30

  testWidgets('Eventos especiales: en Inicio, en la pestaña Eventos y su detalle', (WidgetTester tester) async { // Prueba 31
    tester.view.physicalSize = const Size(800, 2400); // Pantalla alta: caben todas las tarjetas
    tester.view.devicePixelRatio = 1; // 1 píxel = 1 punto
    addTearDown(tester.view.reset); // Al terminar, tamaño normal
    String? compartido; // Lo que se intentó compartir
    Compartir.compartir = (texto) async => compartido = texto; // Compartir de mentira
    final inicio = DateTime.now().add(const Duration(days: 20)); // Dentro de 20 días
    final api = ApiFalsa()..eventos = [ // Un evento con botón
      {'id': 7, 'titulo': 'Campamento de jóvenes', 'inicia_en': inicio.toIso8601String(), 'termina_en': inicio.add(const Duration(days: 2)).toIso8601String(), 'lugar': 'Finca El Paraíso', 'descripcion': 'Tres días de alabanza.', 'se_transmite': true, 'en_curso': false, 'boton': {'texto': 'Inscríbete', 'url': 'https://forms.gle/x'}},
    ]; // Fin de los eventos
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    expect(find.text('PRÓXIMOS EVENTOS'), findsOneWidget); // Carrusel propio de eventos (separado de los anuncios)
    expect(tester.getTopLeft(find.text('ANUNCIOS')).dy, lessThan(tester.getTopLeft(find.text('PRÓXIMOS EVENTOS')).dy)); // Los anuncios van ARRIBA de los eventos
    await tester.tap(find.text('Campamento de jóvenes')); // Abre el detalle
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Tres días de alabanza.'), findsOneWidget); // Descripción
    expect(find.text('Inscríbete'), findsOneWidget); // Botón del panel
    expect(find.text('Recordarme'), findsOneWidget); // Recordatorio
    await tester.tap(find.text('Compartir')); // Comparte
    await tester.pump(); // Espera
    expect(compartido, contains('https://forms.gle/x')); // Con el enlace de inscripción
    await tester.pageBack(); // Vuelve
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Pestaña Eventos del menú
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Eventos especiales'), findsOneWidget); // Título de la pestaña
    expect(find.text('Campamento de jóvenes'), findsOneWidget); // El evento
    expect(find.text('📍 Finca El Paraíso'), findsOneWidget); // Lugar (en la tarjeta completa)
  }); // Fin de la prueba 31

  testWidgets('Anuncio con botón de enlace', (WidgetTester tester) async { // Prueba 32
    pantallaAlta(tester); // Pantalla alta: el carrusel se ve sin desplazar
    await tester.pumpWidget(CanaanApp(api: ApiFalsa()..anuncioConBoton = true)); // Anuncio con botón
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Ayuno congregacional')); // Abre el anuncio
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Inscríbete'), findsOneWidget); // Botón en el detalle
  }); // Fin de la prueba 32

  testWidgets('Modo oscuro: se elige en Servicios y cambia los colores', (WidgetTester tester) async { // Prueba 33
    tester.view.physicalSize = const Size(800, 2000); // Pantalla alta: cabe toda la lista de Servicios
    tester.view.devicePixelRatio = 1; // 1 píxel = 1 punto
    addTearDown(tester.view.reset); // Al terminar, tamaño normal
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Servicios'))); // Pestaña Servicios
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Apariencia'), findsOneWidget); // Selector
    await tester.tap(find.text('Oscuro')); // Elige oscuro
    await tester.pumpAndSettle(); // Redibuja con el tema oscuro
    final tema = Theme.of(tester.element(find.text('Apariencia'))); // Tema en uso
    Preferencias.apariencia.value = 'sistema'; // Lo deja como estaba (para las demás pruebas)
    expect(tema.brightness, Brightness.dark); // Tema oscuro
    expect(tema.scaffoldBackgroundColor, fondoOscuro); // Fondo oscuro
  }); // Fin de la prueba 33

  testWidgets('Eventos: al volver a tocar la pestaña, muestra los cambios del panel', (WidgetTester tester) async { // Prueba 34
    final inicio = DateTime.now().add(const Duration(days: 30)); // Dentro de 30 días
    final api = ApiFalsa()..eventos = [{'id': 2, 'titulo': 'Aniversario de la Iglesia', 'inicia_en': inicio.toIso8601String(), 'en_curso': false}]; // Un evento
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Pestaña Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Aniversario de la Iglesia'), findsOneWidget); // Nombre de antes
    api.eventos = [{'id': 2, 'titulo': 'Aniversario de la Iglesia 2026', 'inicia_en': inicio.toIso8601String(), 'en_curso': false}]; // El panel lo cambia
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Inicio'))); // Va a Inicio
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Vuelve a Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Aniversario de la Iglesia 2026'), findsOneWidget); // Ya sale el cambio (sin jalar hacia abajo)
  }); // Fin de la prueba 34

  testWidgets('Prédicas: al volver a tocar la pestaña, muestra los cambios del panel', (WidgetTester tester) async { // Prueba 35
    final api = ApiFalsa(); // Panel falso
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Prédicas'))); // Pestaña Prédicas
    await tester.pumpAndSettle(); // Espera
    expect(find.text('La fe que mueve montañas'), findsOneWidget); // Título de antes
    api.tituloPredica = 'La fe que mueve montañas (2.ª parte)'; // El panel lo cambia
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Inicio'))); // Va a Inicio
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Prédicas'))); // Vuelve a Prédicas
    await tester.pumpAndSettle(); // Espera
    expect(find.text('La fe que mueve montañas (2.ª parte)'), findsOneWidget); // Ya sale el cambio
  }); // Fin de la prueba 35

  testWidgets('Eventos: compartir desde la tarjeta (con imagen si tiene)', (WidgetTester tester) async { // Prueba 36
    String? texto; String? imagen; // Lo que se intentó compartir
    Compartir.compartir = (t) async => texto = t; // Compartir texto de mentira
    Compartir.compartirImagen = (t, url) async { texto = t; imagen = url; }; // Compartir con imagen de mentira
    final inicio = DateTime.now().add(const Duration(days: 30)); // Dentro de 30 días
    final api = ApiFalsa()..eventos = [{'id': 2, 'titulo': 'Aniversario de la Iglesia', 'inicia_en': inicio.toIso8601String(), 'lugar': 'Templo principal', 'imagen_url': 'https://ejemplo.com/flyer.jpg', 'se_transmite': true, 'en_curso': false}]; // Evento con flyer
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Pestaña Eventos
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.byTooltip('Compartir evento')); // Toca Compartir en la tarjeta
    await tester.pump(); // Espera
    expect(imagen, 'https://ejemplo.com/flyer.jpg'); // Comparte el flyer
    expect(texto, contains('🎉 Aniversario de la Iglesia')); // Con el nombre
    expect(texto, contains('📍 Templo principal')); // El lugar
    expect(texto, contains('Ministerio Cristiano Canaán')); // Y la firma
    expect(find.text('Evento especial'), findsNothing); // No abrió el detalle (solo compartió)
  }); // Fin de la prueba 36

  testWidgets('Horario: compartir un culto y el horario completo', (WidgetTester tester) async { // Prueba 37
    String? compartido; // Lo que se intentó compartir
    Compartir.compartir = (texto) async => compartido = texto; // Compartir de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Horario')); // Acceso rápido Horario
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.byTooltip('Compartir culto')); // Comparte el culto
    await tester.pump(); // Espera
    expect(compartido, contains('⛪ Culto general')); // Nombre
    expect(compartido, contains('📅 Cada domingo · 10:00 am – 12:00 pm')); // Día y hora
    expect(compartido, contains('¡Te esperamos!')); // Invitación
    await tester.tap(find.byTooltip('Compartir horario completo')); // Comparte toda la semana
    await tester.pump(); // Espera
    expect(compartido, contains('📅 Horario de cultos')); // Título
    expect(compartido, contains('DOMINGO')); // Día
    expect(compartido, contains('• Culto general · 10:00 am – 12:00 pm 🔴')); // Culto con su marca de en vivo
    expect(compartido, contains('Ministerio Cristiano Canaán')); // Firma
  }); // Fin de la prueba 37

  test('Eventos: avisos según lo elegido en el panel', () { // Prueba 38 (sin pantalla: solo el cálculo)
    final ahora = DateTime(2026, 11, 1, 12, 0); // "Ahora" fijo: 1 de noviembre, mediodía
    final evento = Evento(id: 7, titulo: 'Cantata', iniciaEn: DateTime(2026, 11, 10, 18, 0), diasAntes: 3, horasAviso: const ['09:00', '18:00'], minutosAntes: 30); // 10 nov 6:00 pm; cada día desde 3 días antes, 2 por día; 30 min antes
    final avisos = Recordatorios.avisosDeEvento(evento, ahora); // Cálculo
    expect(avisos.map((a) => a.cuando).toList(), [ // 3 días × 2 + 1 = 7 avisos, en orden
      DateTime(2026, 11, 7, 9, 0), DateTime(2026, 11, 7, 18, 0), // En 3 días
      DateTime(2026, 11, 8, 9, 0), DateTime(2026, 11, 8, 18, 0), // En 2 días
      DateTime(2026, 11, 9, 9, 0), DateTime(2026, 11, 9, 18, 0), // Mañana
      DateTime(2026, 11, 10, 17, 30), // El mismo día, 30 min antes
    ]); // Fin de la lista
    expect(avisos.first.titulo, '📅 En 3 días: Cantata'); // Título del primero
    expect(avisos[4].titulo, '📅 Mañana: Cantata'); // La víspera
    expect(avisos.last.titulo, '⏰ En 30 minutos: Cantata'); // El mismo día
    expect(Recordatorios.explicacionDeEvento(evento, ahora), 'cada día desde 3 días antes (9:00 am y 6:00 pm) y 30 minutos antes de empezar'); // Mensaje al activar
    final manana = Evento(id: 8, titulo: 'Ayuno', iniciaEn: DateTime(2026, 11, 2, 6, 0), diasAntes: 1, minutosAntes: 60); // Mañana a las 6:00 am
    expect(Recordatorios.avisosDeEvento(manana, ahora).map((a) => a.titulo), ['⏰ En 1 hora: Ayuno']); // El de la víspera (hoy 9:00 am) ya pasó: solo queda el de 1 hora
    final nada = Evento(id: 9, titulo: 'Sin aviso', iniciaEn: DateTime(2026, 11, 20, 8, 0), diasAntes: 0, minutosAntes: 0); // El panel no quiere avisos
    expect(Recordatorios.avisosDeEvento(nada, ahora), isEmpty); // Ninguno
  }); // Fin de la prueba 38

  testWidgets('Eventos: la tarjeta tiene la campanita 🔔', (WidgetTester tester) async { // Prueba 39
    final inicio = DateTime.now().add(const Duration(days: 30)); // Dentro de 30 días
    final api = ApiFalsa()..eventos = [{'id': 4, 'titulo': 'Cantata de Navidad', 'inicia_en': inicio.toIso8601String(), 'en_curso': false, 'recordatorio': {'dias_antes': 2, 'minutos_antes': 30}}]; // Evento
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Pestaña Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.byTooltip('Recordarme este evento'), findsOneWidget); // Campanita en la tarjeta
    await tester.tap(find.byTooltip('Recordarme este evento')); // La toca (en las pruebas no hay teléfono)
    await tester.pump(); // Espera el aviso
    expect(find.text('Los recordatorios funcionan en la app del teléfono.'), findsOneWidget); // Explica por qué no se activó
  }); // Fin de la prueba 39

  testWidgets('Cuenta regresiva: respeta las horas y la casilla de Configuración', (WidgetTester tester) async { // Prueba 40
    final proxima = DateTime.now().add(const Duration(hours: 5)); // Dentro de 5 horas
    final culto = {'id': 5, 'nombre': 'Culto de oración', 'dia_semana': proxima.weekday % 7, 'dia': 'Hoy', 'horario': '7:00 pm', 'se_transmite': true, 'en_curso': false, 'proxima': proxima.toIso8601String()}; // Culto transmitido
    final api = ApiFalsa()..enVivoEnPanel = false..horario = [culto]; // Sin en vivo; cuenta desde 2 h (por defecto)
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Se transmite en vivo en la app'), findsOneWidget); // Faltan 5 h y la cuenta sale desde 2 h: solo el aviso
    expect(find.textContaining('faltan'), findsNothing); // Sin cuenta regresiva
    api.cuentaRegresiva = {'mostrar': true, 'horas': 6}; // El panel la pone desde 6 horas antes
    tocarTimbreInicio(); // Inicio recarga
    await tester.pumpAndSettle(); // Espera
    expect(find.textContaining('faltan'), findsOneWidget); // Ahora sí hay cuenta regresiva
    api.cuentaRegresiva = {'mostrar': false, 'horas': 6}; // El panel la apaga
    tocarTimbreInicio(); // Inicio recarga
    await tester.pumpAndSettle(); // Espera
    expect(find.textContaining('faltan'), findsNothing); // Sin cuenta regresiva
    expect(find.text('Se transmite en vivo en la app'), findsNothing); // Ni la línea
  }); // Fin de la prueba 40

  test('Eventos: fecha corta para varios días', () { // Prueba 41
    expect(Evento(id: 1, titulo: 'A', iniciaEn: DateTime(2026, 11, 20, 8), terminaEn: DateTime(2026, 11, 22, 16)).cuandoTexto(), '20 al 22 de noviembre'); // Mismo mes
    expect(Evento(id: 2, titulo: 'B', iniciaEn: DateTime(2026, 11, 30, 8), terminaEn: DateTime(2026, 12, 2, 16)).cuandoTexto(), '30 de noviembre al 2 de diciembre'); // Distinto mes
  }); // Fin de la prueba 41

  testWidgets('Modo oscuro: los colores de íconos se aclaran (y en claro no cambian)', (WidgetTester tester) async { // Prueba 42
    const verde = Color(0xFF15803D); // Verde del Horario
    Color? enClaro; Color? enOscuro; double? burbuja; // Resultados
    await tester.pumpWidget(MaterialApp(theme: temaCanaan(), home: Builder(builder: (c) { enClaro = c.vivo(verde); return const SizedBox(); }))); // Tema claro
    await tester.pumpWidget(MaterialApp(theme: temaCanaan(oscuro: true), home: Builder(builder: (c) { enOscuro = c.vivo(verde); burbuja = c.alfaBurbuja; return const SizedBox(); }))); // Tema oscuro
    await tester.pumpAndSettle(); // Espera a que termine el cambio suave de tema (de claro a oscuro)
    expect(enClaro, verde); // En claro: el mismo
    expect(HSLColor.fromColor(enOscuro!).lightness, greaterThanOrEqualTo(0.68)); // En oscuro: mucho más claro
    expect(burbuja, 0.24); // Burbuja más visible
  }); // Fin de la prueba 42

  test('Sin internet: usa la última copia guardada y lo avisa', () async { // Prueba 43 (la API real con un internet de mentira)
    var hayInternet = true; // Se apaga a mitad de la prueba
    final internet = MockClient((peticion) async { // Internet de mentira
      if (!hayInternet) throw http.ClientException('sin internet'); // Apagado: falla como en el teléfono
      return http.Response(jsonEncode({'data': [{'id': 1, 'titulo': 'Campamento', 'inicia_en': '2026-12-01T08:00:00-06:00'}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'}); // El panel responde un evento
    }); // Fin del internet
    await http.runWithClient(() async { // Todas las peticiones usan el internet de mentira
      final eventos = await const Api().obtenerEventos(); // Con internet
      expect(eventos.single.titulo, 'Campamento'); // Llegó
      expect(sinConexion.value, isFalse); // Con conexión
      hayInternet = false; // Se va el internet
      CopiaLocal.olvidarMemoria(); // Que lea la copia del almacén del teléfono (como al abrir la app otro día)
      final otraVez = await const Api().obtenerEventos(); // Sin internet
      expect(otraVez.single.titulo, 'Campamento'); // Muestra la copia guardada
      expect(sinConexion.value, isTrue); // Y avisa "Sin conexión"
      await expectLater(const Api().obtenerActividades(), throwsA(isA<http.ClientException>())); // Lo que nunca se guardó: error (la pantalla muestra "Reintentar")
    }, () => internet); // Fin de runWithClient
    sinConexion.value = false; // Lo deja como estaba (para las demás pruebas)
  }); // Fin de la prueba 43

  testWidgets('Eventos: inscribirse, ver "Estás inscrito" y cancelar', (WidgetTester tester) async { // Prueba 44
    pantallaAlta(tester); // Pantalla alta
    final inicio = DateTime.now().add(const Duration(days: 20)); // Dentro de 20 días
    final api = ApiFalsa()..eventos = [{'id': 3, 'titulo': 'Retiro de damas', 'inicia_en': inicio.toIso8601String(), 'en_curso': false, 'inscripciones': {'activas': true, 'abiertas': true, 'cupo': 30, 'restantes': 10}}]; // Evento con inscripción
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Pestaña Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.text('📝 Inscripciones abiertas · quedan 10'), findsOneWidget); // Etiqueta en la tarjeta
    await tester.tap(find.text('Retiro de damas')); // Abre el detalle
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.widgetWithText(FilledButton, 'Inscribirme')); // Botón Inscribirme
    await tester.pumpAndSettle(); // Abre el formulario
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Ana López'); // Nombre
    await tester.enterText(find.widgetWithText(TextFormField, 'Teléfono (WhatsApp)'), '7000-1234'); // Teléfono
    await tester.tap(find.byTooltip('Más')); // 2 personas
    await tester.pump(); // Redibuja
    await tester.tap(find.widgetWithText(FilledButton, 'Inscribirme')); // Envía
    await tester.pumpAndSettle(); // Vuelve al detalle
    expect(api.inscripcionFalsa?.personas, 2); // Llegó al panel con 2 personas
    expect(find.text('✅ Estás inscrito'), findsOneWidget); // Confirmación en el detalle
    expect(find.text('Ana López · 2 persona(s)'), findsOneWidget); // Sus datos
    await tester.tap(find.text('Cancelar inscripción')); // Cancela
    await tester.pumpAndSettle(); // Pregunta
    await tester.tap(find.text('Sí, cancelar')); // Confirma
    await tester.pumpAndSettle(); // Espera
    expect(api.inscripcionFalsa, isNull); // Cancelada en el panel
    expect(find.widgetWithText(FilledButton, 'Inscribirme'), findsOneWidget); // Otra vez el botón
  }); // Fin de la prueba 44

  testWidgets('Series y bosquejo: filtro, etiqueta, bosquejo y siguiente parte', (WidgetTester tester) async { // Prueba 45
    pantallaAlta(tester); // Pantalla alta
    final api = ApiFalsa()..conSerie = true; // Panel con una serie
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Prédicas'))); // Pestaña Prédicas
    await tester.pumpAndSettle(); // Espera
    expect(find.text('📚 La familia'), findsOneWidget); // Botón de filtro de la serie
    expect(find.text('📚 La familia · Parte 1 de 2'), findsOneWidget); // Etiqueta en la tarjeta
    await tester.tap(find.text('📚 La familia')); // Filtra por la serie
    await tester.pumpAndSettle(); // Espera
    expect(find.text(api.tituloPredica), findsNothing); // La prédica suelta ya no sale
    await tester.tap(find.text('Diseño de Dios')); // Abre la parte 1
    await tester.pumpAndSettle(); // Espera
    expect(find.text('📝 Ver bosquejo'), findsOneWidget); // Botón del bosquejo
    expect(find.text('Padres que bendicen'), findsOneWidget); // Tarjeta de la siguiente parte
    await tester.tap(find.text('📝 Ver bosquejo')); // Abre el bosquejo
    await tester.pumpAndSettle(); // Espera
    expect(find.text('1. Dios diseñó la familia — Génesis 2:24'), findsOneWidget); // Los puntos
    await tester.pageBack(); // Vuelve al video
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Padres que bendicen')); // Siguiente parte
    await tester.pumpAndSettle(); // Espera
    expect(find.text('📝 Ver bosquejo'), findsNothing); // La parte 2 no tiene bosquejo
    expect(find.textContaining('SIGUIENTE EN LA SERIE'), findsNothing); // Y es la última
  }); // Fin de la prueba 45

  testWidgets('Galería: eventos pasados con fotos y visor en pantalla completa', (WidgetTester tester) async { // Prueba 46
    pantallaAlta(tester); // Pantalla alta
    final api = ApiFalsa()..pasados = [{'id': 8, 'titulo': 'Campamento 2026', 'inicia_en': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(), 'terminado': true, 'fotos': ['https://ejemplo.com/1.jpg', 'https://ejemplo.com/2.jpg', 'https://ejemplo.com/3.jpg']}]; // Un evento pasado con 3 fotos
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Pestaña Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.text('EVENTOS PASADOS · FOTOS'), findsOneWidget); // Sección de pasados
    expect(find.text('📷 3 foto(s) · toca para verlas'), findsOneWidget); // Cuántas fotos
    expect(find.byTooltip('Recordarme este evento'), findsNothing); // Sin 🔔 (ya pasó)
    await tester.tap(find.text('Campamento 2026')); // Abre el detalle
    await tester.pumpAndSettle(); // Espera
    expect(find.text('📷 FOTOS (3)'), findsOneWidget); // Cuadrícula
    expect(find.text('Recordarme'), findsNothing); // Sin recordatorio (ya pasó)
    await tester.tap(find.byType(GestureDetector).at(1)); // Toca la segunda foto
    await tester.pumpAndSettle(); // Espera
    expect(find.text('2 / 3'), findsOneWidget); // Visor en la foto 2 de 3
  }); // Fin de la prueba 46

  testWidgets('Servicios → Ministerios: directorio con WhatsApp', (WidgetTester tester) async { // Prueba 47
    pantallaAlta(tester); // Pantalla alta
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Servicios'))); // Pestaña Servicios
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Ministerios')); // Abre el directorio
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Ministerio de jóvenes'), findsOneWidget); // Nombre
    expect(find.text('🕒 Sábados 4:00 pm'), findsOneWidget); // Horario
    expect(find.text('👤 Líder: Carlos'), findsOneWidget); // Líder
    expect(find.text('Escribir por WhatsApp'), findsOneWidget); // Botón
  }); // Fin de la prueba 47

  Anuncio area(int id, {ZonaAnuncio? zona, String disparo = 'llegar', int minutos = 0}) => Anuncio( // Anuncio "Solo área" en su ventana (ayuda de las pruebas 48–50)
        id: id, titulo: 'A$id', mensaje: 'm', tipo: 'area', // Datos básicos
        iniciaEn: DateTime.now().subtract(const Duration(hours: 1)), terminaEn: DateTime.now().add(const Duration(hours: 2)), // Ventana actual
        zona: zona, disparo: disparo, minutos: minutos, // Área y momento
      ); // Fin

  test('Geocerca: cada anuncio usa SU área (propia o la de la iglesia)', () async { // Prueba 48
    final iglesia = await ApiFalsa().obtenerIglesia(); // Iglesia en 13.6929, -89.2182 (200 m)
    final gps = UbicacionFalsa(const Coordenadas(13.6930, -89.2183)); // En el templo
    final salon = const ZonaAnuncio(latitud: 13.7000, longitud: -89.2182, radioMetros: 100, propia: true); // Otro lugar a ~800 m
    final geocerca = Geocerca(ubicacion: gps); // Con la ubicación de mentira
    final avisos = await geocerca.revisar(iglesia, [area(1), area(2, zona: salon)], DateTime.now()); // Revisa
    expect(avisos.map((a) => a.id), [1]); // Solo el de la iglesia (el del salón queda pendiente)
    gps.punto = const Coordenadas(13.7001, -89.2182); // Se va al salón
    expect((await geocerca.revisar(iglesia, [area(1), area(2, zona: salon)], DateTime.now())).map((a) => a.id), [2]); // Ahora sí el del salón (el 1 ya se mostró)
  }); // Fin de la prueba 48

  test('Geocerca: "si se queda N minutos" espera y "al salir" avisa al irse', () async { // Prueba 49
    final iglesia = await ApiFalsa().obtenerIglesia(); // Iglesia
    final gps = UbicacionFalsa(const Coordenadas(13.6930, -89.2183)); // En el templo
    final geocerca = Geocerca(ubicacion: gps); // Geocerca
    final lista = [area(5, minutos: 10), area(6, disparo: 'salir')]; // Uno con espera y uno de despedida
    final t0 = DateTime.now(); // Llega
    expect(await geocerca.revisar(iglesia, lista, t0), isEmpty); // Recién llegó: nada (empieza a contar; el de salir anota que estuvo)
    expect(await geocerca.revisar(iglesia, lista, t0.add(const Duration(minutes: 5))), isEmpty); // A los 5 min: aún no
    expect((await geocerca.revisar(iglesia, lista, t0.add(const Duration(minutes: 11)))).map((a) => a.id), [5]); // A los 11 min: avisa el de espera
    gps.punto = const Coordenadas(13.7100, -89.2182); // Se va (~1.9 km)
    expect((await geocerca.revisar(iglesia, lista, t0.add(const Duration(minutes: 70)))).map((a) => a.id), [6]); // Avisa la despedida
    final otro = Geocerca(ubicacion: UbicacionFalsa(const Coordenadas(13.7100, -89.2182))); // Teléfono que NUNCA estuvo en la iglesia
    await const FlutterSecureStorage().deleteAll(); // Caja fuerte limpia
    expect(await otro.revisar(iglesia, [area(7, disparo: 'salir')], DateTime.now()), isEmpty); // No recibe la despedida
  }); // Fin de la prueba 49

  test('Geocerca de fondo: elige el anuncio según el círculo y el evento', () { // Prueba 50
    final salon = const ZonaAnuncio(latitud: 13.7000, longitud: -89.2182, radioMetros: 100, propia: true); // Área propia
    final pendientes = [area(1), area(2, minutos: 5), area(3, disparo: 'salir'), area(4, zona: salon)]; // Varios tipos
    List<int> elegir(List<String> c, GeofenceEvent e, {bool iphone = false, double? lat, double? lng}) => // Atajo
        anunciosParaAvisar(circulos: c, evento: e, pendientes: pendientes, esIphone: iphone, latitud: lat, longitud: lng).map((a) => a.id).toList(); // Ids elegidos
    expect(elegir(['iglesia'], GeofenceEvent.enter, lat: 13.6929, lng: -89.2182), [1]); // Iglesia: solo "al llegar, enseguida" (no el del salón)
    expect(elegir(['iglesia'], GeofenceEvent.enter, iphone: true), [1, 2]); // iPhone: el de espera avisa al entrar; el del salón sin ubicación se deja a su círculo
    expect(elegir(['anuncio-2'], GeofenceEvent.dwell), [2]); // Se quedó 5 min
    expect(elegir(['anuncio-2'], GeofenceEvent.enter), isEmpty); // Al entrar aún no (Android espera)
    expect(elegir(['anuncio-3'], GeofenceEvent.exit), [3]); // Al salir
    expect(elegir(['anuncio-3'], GeofenceEvent.enter), isEmpty); // Al entrar no
    expect(elegir(['anuncio-4'], GeofenceEvent.enter), [4]); // Su propia área
    expect(elegir(['anuncio-99'], GeofenceEvent.enter), isEmpty); // Anuncio que ya no existe
  }); // Fin de la prueba 50

  testWidgets('Aviso urgente "solo en un área": se ve dentro y no fuera', (WidgetTester tester) async { // Prueba 51
    final area = {'latitud': 13.6929, 'longitud': -89.2182, 'radio_metros': 200, 'propia': true}; // Área del aviso
    final gps = UbicacionFalsa(const Coordenadas(13.7100, -89.2182)); // Lejos (~1.9 km)
    ServicioUbicacion.crear = () => gps; // Ubicación de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(avisoNivel: 'importante', avisoArea: area))); // Panel con aviso de área
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Culto cancelado'), findsNothing); // Lejos: no se ve
    expect(gps.consultas, greaterThan(0)); // Sí revisó la ubicación
  }); // Fin de la prueba 51

  testWidgets('Aviso urgente "solo en un área": dentro del área sí se ve', (WidgetTester tester) async { // Prueba 52
    final gps = UbicacionFalsa(const Coordenadas(13.6930, -89.2183)); // Dentro
    ServicioUbicacion.crear = () => gps; // Ubicación de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(avisoNivel: 'importante', avisoArea: {'latitud': 13.6929, 'longitud': -89.2182, 'radio_metros': 200, 'propia': true}))); // Aviso de área
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Culto cancelado'), findsOneWidget); // Dentro: se ve
  }); // Fin de la prueba 52
  testWidgets('Inicio: anuncios y eventos en carruseles separados, "Ver todo" y EN VIVO arriba', (WidgetTester tester) async { // Prueba 53
    pantallaAlta(tester); // Pantalla alta
    final inicio = DateTime.now().add(const Duration(days: 10)); // Dentro de 10 días
    final api = ApiFalsa()..eventos = [ // Un evento
      {'id': 8, 'titulo': 'Aniversario', 'inicia_en': inicio.toIso8601String(), 'lugar': 'Templo central', 'se_transmite': false, 'en_curso': false},
    ]; // Fin de los eventos
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app (la ApiFalsa trae en vivo activo)
    await tester.pumpAndSettle(); // Espera
    expect(tester.getTopLeft(find.text('● EN VIVO')).dy, lessThan(tester.getTopLeft(find.text('Horario')).dy)); // EN VIVO va arriba de los accesos rápidos
    expect(find.text('Este sábado de 6 am a 12 md.'), findsNothing); // En Inicio el anuncio va resumido
    expect(find.text('Ver todos'), findsOneWidget); // Enlace de eventos (a la pestaña Eventos)
    await tester.tap(find.text('Ver todo')); // Abre la lista de anuncios
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este sábado de 6 am a 12 md.'), findsOneWidget); // Anuncio completo
    expect(find.text('Aniversario'), findsNothing); // Sin eventos mezclados
    await tester.pageBack(); // Vuelve
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Ver todos')); // Eventos → pestaña Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Eventos especiales'), findsOneWidget); // Título de la pestaña
    expect(find.text('📍 Templo central'), findsOneWidget); // Evento completo
  }); // Fin de la prueba 53
  testWidgets('Carrusel: pasa solo, se detiene al tocarlo y con ⏸', (WidgetTester tester) async { // Prueba 54
    pantallaAlta(tester); // Pantalla alta
    Carruseles.pasoAutomatico = const Duration(seconds: 6); // Enciende el paso automático (solo en esta prueba)
    addTearDown(() => Carruseles.pasoAutomatico = null); // Al terminar, lo apaga otra vez
    final inicio = DateTime.now().add(const Duration(days: 10)); // Dentro de 10 días
    final api = ApiFalsa()..eventos = [ // Tres eventos (un solo carrusel con varias tarjetas)
      for (var n = 1; n <= 3; n++) {'id': n, 'titulo': 'Evento $n', 'inicia_en': inicio.add(Duration(days: n)).toIso8601String(), 'se_transmite': false, 'en_curso': false},
    ]; // Fin de los eventos
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    final carrusel = find.byKey(const ValueKey('carrusel-PRÓXIMOS EVENTOS')); // Carrusel de eventos
    final control = tester.widget<ListView>(carrusel).controller!; // Su control (posición)
    final ancho = tester.getSize(find.byKey(const ValueKey('carrusel-PRÓXIMOS EVENTOS'))).width * 0.86; // Ancho de cada tarjeta
    int tarjeta() => (control.offset / ancho).round(); // Qué tarjeta se ve
    expect(tarjeta(), 0); // Empieza en la primera
    await tester.pump(const Duration(seconds: 6)); // Pasan 6 s (el de eventos espera 3 s más: aún no se mueve)
    await tester.pumpAndSettle(); // Espera
    expect(tarjeta(), 0); // Desfasado del de anuncios: sigue en la primera
    await tester.pump(const Duration(seconds: 3)); // Pasan los 3 s del desfase
    await tester.pumpAndSettle(); // Termina el movimiento
    expect(tarjeta(), 1); // Pasó sola a la segunda
    await tester.tap(find.byTooltip('Detener el paso de las tarjetas').last); // Toca ⏸ del carrusel de eventos
    await tester.pump(); // Redibuja
    await tester.pump(const Duration(seconds: 13)); // Pasan 13 s (dos pasos)
    await tester.pumpAndSettle(); // Espera
    expect(tarjeta(), 1); // Detenido: sigue en la segunda
    expect(find.byTooltip('Pasar las tarjetas solas'), findsOneWidget); // Ahora el botón es ▶
    await tester.tap(find.byTooltip('Pasar las tarjetas solas')); // Reanuda
    await tester.pump(); // Redibuja
    await tester.pump(const Duration(seconds: 6)); // Siguiente paso
    await tester.pumpAndSettle(); // Espera
    expect(tarjeta(), 2); // Volvió a pasar sola
    expect(control.offset, closeTo(2 * ancho, 1)); // La ÚLTIMA tarjeta queda exactamente alineada a la izquierda (no se corre)
    final centro = tester.getCenter(carrusel); // Centro del carrusel
    final gesto = await tester.startGesture(centro); // La persona pone el dedo
    await gesto.cancel(); // Y lo retira sin completar un toque (así no abre el evento)
    await tester.pump(const Duration(seconds: 7)); // Pasan 7 s (menos de 15 desde el toque)
    await tester.pumpAndSettle(); // Espera
    expect(tarjeta(), 2); // Pausa corta por el toque: no se movió
  }); // Fin de la prueba 54
  testWidgets('Menú de abajo: se ve en las pantallas abiertas; atrás y tocar la pestaña regresan', (WidgetTester tester) async { // Prueba 55
    pantallaAlta(tester); // Pantalla alta
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Ver todo')); // Abre la lista de anuncios
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este sábado de 6 am a 12 md.'), findsOneWidget); // Está en la lista
    expect(find.byType(NavigationBar), findsOneWidget); // El menú de abajo SIGUE visible
    await tester.binding.handlePopRoute(); // Botón "atrás" de Android
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este sábado de 6 am a 12 md.'), findsNothing); // Cerró la lista (volvió a Inicio, no salió de la app)
    await tester.tap(find.text('Ver todo')); // La abre otra vez
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Cambia a Eventos
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Inicio'))); // Vuelve a Inicio
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este sábado de 6 am a 12 md.'), findsOneWidget); // La lista seguía abierta (donde la dejó)
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Inicio'))); // Toca Inicio OTRA vez
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este sábado de 6 am a 12 md.'), findsNothing); // Volvió al principio de Inicio
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Eventos'))); // Va a Eventos
    await tester.pumpAndSettle(); // Espera
    await tester.binding.handlePopRoute(); // "Atrás" sin nada abierto en Eventos
    await tester.pumpAndSettle(); // Espera
    expect(find.text('ANUNCIOS'), findsOneWidget); // Regresó a Inicio
  }); // Fin de la prueba 55
} // Fin de main
