import 'package:flutter/material.dart'; // Componentes visuales (para buscar íconos y textos)
import 'package:flutter_test/flutter_test.dart'; // Herramientas de pruebas automáticas de Flutter

import 'package:canaan_app/main.dart'; // Nuestra app
import 'package:canaan_app/modelos/actividad.dart'; // Molde de una actividad
import 'package:canaan_app/modelos/anuncio.dart'; // Molde de un anuncio
import 'package:canaan_app/modelos/iglesia.dart'; // Molde de los datos de la iglesia
import 'package:canaan_app/modelos/predica.dart'; // Molde de una prédica
import 'package:canaan_app/servicios/api.dart'; // La API real (de ella se hereda la falsa)
import 'package:canaan_app/servicios/registro.dart'; // Registro del teléfono
import 'package:canaan_app/pantallas/video.dart'; // Pantalla del video (para cambiar el reproductor por uno de prueba)
import 'package:canaan_app/servicios/geocerca.dart'; // Geocerca (distancia)
import 'package:canaan_app/servicios/ubicacion.dart'; // Servicio de ubicación (para cambiarlo por uno de prueba)
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
  Future<void> reproducir(String url) async { urlReproducida = url; _estados.add(EstadoRadio.sonando); } // "Suena"

  @override // Cumple la plantilla
  Future<void> detener() async => _estados.add(EstadoRadio.detenida); // "Se detiene"

  @override // Cumple la plantilla
  Future<void> cerrar() async => cerrada = true; // Anota que se cerró
} // Fin de RadioFalsa

class ApiFalsa extends Api { // API de mentira: responde datos fijos sin usar internet
  ApiFalsa({this.falla = false, this.radioAlAire = false}); // Constructor; falla = true simula que no hay conexión

  final bool falla; // ¿Simular error?
  final bool radioAlAire; // ¿La radio está al aire en el panel falso?
  bool enVivoEnPanel = true; // ¿Hay transmisión en vivo en el panel falso? (se puede cambiar a mitad de la prueba)
  bool anuncioAreaAhora = false; // ¿Hay un anuncio "Solo área" en su ventana ahora mismo?

  @override // Reemplaza el método real
  Future<List<Anuncio>> obtenerAnuncios() async { // Anuncios falsos
    if (falla) throw Exception('sin internet'); // Simula el error
    return [ // Tres anuncios:
      Anuncio.desdeJson({'id': 1, 'titulo': 'Ayuno congregacional', 'mensaje': 'Este sábado de 6 am a 12 md.', 'tipo': 'todos', 'programacion': {'fecha_inicio': '2026-10-31', 'fecha_fin': '2026-10-31'}, 'visible_hasta': null}), // Para todos: SE MUESTRA
      Anuncio.desdeJson({'id': 2, 'titulo': 'Bienvenido al templo', 'mensaje': 'Gracias por venir.', 'tipo': 'area'}), // Solo área: NO se muestra (geocerca, Paso 10)
      if (anuncioAreaAhora) Anuncio.desdeJson({'id': 9, 'titulo': 'Santa Cena hoy', 'mensaje': 'Pasa al frente al terminar la prédica.', 'tipo': 'area', 'ventana': {'inicia_en': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(), 'termina_en': DateTime.now().add(const Duration(hours: 2)).toIso8601String()}}), // De área, en su ventana
      Anuncio.desdeJson({'id': 3, 'titulo': 'Anuncio vencido', 'mensaje': 'Ya pasó.', 'tipo': 'todos', 'visible_hasta': '2020-01-01T00:00:00-06:00'}), // Vencido: NO se muestra
    ]; // Fin de la lista
  } // Fin de obtenerAnuncios
  int registros = 0; // Cuántas veces se registró el teléfono
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
    if (falla) throw Exception('sin internet'); // Simula el error
    return Iglesia.desdeJson({ // JSON igual al de la API
      'nombre': 'Ministerio Cristiano Canaán', // Nombre
      'ubicacion': {'latitud': 13.6929, 'longitud': -89.2182, 'radio_metros': 200}, // Templo en San Salvador, radio 200 m
      'en_vivo': {'activo': enVivoEnPanel, 'titulo': 'Culto dominical', 'youtube_id': 'envivo123'}, // Transmisión activa
      if (radioAlAire) 'radio': {'disponible': true, 'titulo': 'Culto dominical', 'stream_url': 'https://radio.ejemplo/canaan', 'modo': 'siempre'}, // Radio 24/7
 // Transmisión activa
    }); // Fin de los datos
  } // Fin de obtenerIglesia

  @override // Reemplaza el método real
  Future<List<Predica>> obtenerPredicas({String buscar = ''}) async { // Prédicas falsas
    if (falla) throw Exception('sin internet'); // Simula el error
    return [Predica.desdeJson({'id': 1, 'titulo': 'La fe que mueve montañas', 'predicador': 'Pastor Juan', 'fecha': '2026-10-05', 'destacada': true, 'youtube_id': 'predica123', 'descripcion': 'Mateo 17:20'})]; // Una prédica destacada
  } // Fin de obtenerPredicas

  @override // Reemplaza el método real
  Future<List<Actividad>> obtenerActividades() async { // Horario falso
    if (falla) throw Exception('sin internet'); // Simula el error
    return [Actividad.desdeJson({'id': 1, 'nombre': 'Culto general', 'dia_semana': 0, 'dia': 'Domingo', 'horario': '10:00 am – 12:00 pm', 'se_transmite': true, 'en_curso': true})]; // Un culto el domingo, en curso
  } // Fin de obtenerActividades
} // Fin de ApiFalsa

void main() { // Punto de arranque de las pruebas
  setUp(() { // Antes de cada prueba:
    FlutterSecureStorage.setMockInitialValues({}); // Caja fuerte vacía y en memoria
    PantallaVideo.reproductorDePrueba = const SizedBox(height: 200, child: Text('[video de prueba]')); // Reproductor de mentira (YouTube no carga en las pruebas)
  }); // Fin de setUp

  testWidgets('Inicio muestra el nombre y EN VIVO', (WidgetTester tester) async { // Prueba 1
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Dibuja la app con la API falsa
    expect(find.text('Conectando…'), findsWidgets); // Primero sale "Conectando…" (en las pestañas que cargan)
    await tester.pumpAndSettle(); // Espera a que lleguen los datos y se redibuje
    expect(find.text('Ministerio Cristiano Canaán'), findsOneWidget); // Sale el nombre
    expect(find.text('● EN VIVO · Culto dominical'), findsOneWidget); // Sale la etiqueta EN VIVO
  }); // Fin de la prueba 1

  testWidgets('El menú cambia a Prédicas y a Horario', (WidgetTester tester) async { // Prueba 2
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Dibuja la app
    await tester.pumpAndSettle(); // Espera los datos
    await tester.tap(find.text('Prédicas')); // Toca "Prédicas" en el menú de abajo
    await tester.pumpAndSettle(); // Espera el cambio
    expect(find.text('La fe que mueve montañas'), findsOneWidget); // Sale la prédica
    expect(find.text('★ DESTACADA'), findsOneWidget); // Con la etiqueta de destacada
    expect(find.text('Pastor Juan · 5 oct 2026'), findsOneWidget); // Predicador y fecha en español
    await tester.tap(find.text('Horario')); // Toca "Horario"
    await tester.pumpAndSettle(); // Espera el cambio
    expect(find.text('DOMINGO'), findsOneWidget); // Encabezado del día
    expect(find.text('Culto general'), findsOneWidget); // La actividad
    expect(find.text('Ahora'), findsOneWidget); // Marcada como en curso
    expect(find.byIcon(Icons.live_tv), findsOneWidget); // Con el ícono de transmisión
  }); // Fin de la prueba 2

  testWidgets('Muestra Reintentar si no hay conexión', (WidgetTester tester) async { // Prueba 3
    await tester.pumpWidget(CanaanApp(api: ApiFalsa(falla: true))); // Dibuja la app con una API que falla
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Reintentar'), findsWidgets); // Sale el botón Reintentar
    await tester.tap(find.text('Más')); // Va a la pestaña Más
    await tester.pumpAndSettle(); // Espera
    expect(find.text('Este teléfono no está conectado'), findsOneWidget); // El registro también falló y lo avisa
  }); // Fin de la prueba 3

  testWidgets('Al abrir, registra el teléfono y Más lo muestra', (WidgetTester tester) async { // Prueba 4
    final api = ApiFalsa(); // API falsa (para revisar cuántas veces se registró)
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Más')); // Va a la pestaña Más
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
    final api = ApiFalsa(); // Panel falso
    await tester.pumpWidget(CanaanApp(api: api)); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.tap(find.text('Más')); // Pestaña Más
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
    await tester.tap(find.text('Más')); // Pestaña Más
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
    await tester.pumpWidget(CanaanApp(api: ApiFalsa())); // Abre la app
    await tester.pumpAndSettle(); // Espera
    await tester.scrollUntilVisible(find.text('Ayuno congregacional'), 200); // Baja hasta el anuncio
    expect(find.text('ANUNCIOS'), findsOneWidget); // Encabezado de la sección
    expect(find.text('Este sábado de 6 am a 12 md.'), findsOneWidget); // Su mensaje
    expect(find.text('31 oct 2026'), findsOneWidget); // Su fecha (un solo día)
    expect(find.text('Bienvenido al templo'), findsNothing); // El de área NO
    expect(find.text('Anuncio vencido'), findsNothing); // El vencido NO
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

  testWidgets('Geocerca: en el templo muestra la bienvenida UNA vez y deja la tarjeta', (WidgetTester tester) async { // Prueba 16
    final gps = UbicacionFalsa(const Coordenadas(13.6930, -89.2183)); // ~15 m del templo
    ServicioUbicacion.crear = () => gps; // Ubicación de mentira
    await tester.pumpWidget(CanaanApp(api: ApiFalsa()..anuncioAreaAhora = true)); // Con anuncio de área en ventana
    await tester.pumpAndSettle(); // Espera
    expect(find.text('¡Qué bueno que estás aquí!'), findsOneWidget); // Ventana de bienvenida
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Pasa al frente al terminar la prédica.')), findsOneWidget); // Con el anuncio dentro de la ventana
    await tester.tap(find.text('Entendido')); // La cierra
    await tester.pumpAndSettle(); // Espera
    await tester.scrollUntilVisible(find.text('📍 En la iglesia'), 200); // Baja hasta la tarjeta
    expect(find.text('Santa Cena hoy'), findsOneWidget); // La tarjeta quedó en Inicio
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
} // Fin de main
