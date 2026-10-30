import 'dart:io' show Platform; // Saber si es Android o iPhone (en el navegador y en las pruebas no hay "WebView")

import 'package:flutter/foundation.dart'; // kIsWeb (¿la app corre en un navegador?)
import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Caja fuerte: recordar el último capítulo y el tamaño de letra
import 'package:url_launcher/url_launcher.dart'; // Abrir enlaces fuera de la app (YouVersion, navegador)
import 'package:webview_flutter/webview_flutter.dart'; // Mostrar una página web DENTRO de la app
import 'package:webview_flutter_android/webview_flutter_android.dart'; // Ajuste de Android: tamaño del texto (setTextZoom)

import '../tema.dart'; // Colores de Canaán

// Pestaña "Biblia": muestra Bible.com (YouVersion) DENTRO de la app con la Reina-Valera 1960 (versión 149).
// La 1960 tiene derechos de autor: no la copiamos en la app; la mostramos desde la página oficial de YouVersion (necesita internet).
// Pensada para adultos mayores: botones grandes, letra ajustable que se recuerda, y abre el último capítulo leído.
class PantallaBiblia extends StatefulWidget { // Pestaña Biblia
  const PantallaBiblia({super.key}); // Constructor

  static const String versionId = '149'; // Número de la Reina-Valera 1960 en YouVersion
  static const String inicio = 'https://www.bible.com/es/bible/149/JHN.3.RVR1960'; // Primera vez: Juan 3
  static const List<int> tamanos = [100, 125, 150, 175, 200]; // Tamaños de letra posibles (en %)
  static const int tamanoInicial = 125; // Empieza un poco más grande que lo normal (más cómodo para leer)

  static bool get navegadorDisponible => !kIsWeb && (Platform.isAndroid || Platform.isIOS); // ¿Se puede mostrar la página dentro de la app? (no en el navegador ni en las pruebas)

  @override // Reemplaza createState
  State<PantallaBiblia> createState() => _PantallaBibliaState(); // Crea el estado
} // Fin de PantallaBiblia

class _PantallaBibliaState extends State<PantallaBiblia> { // Estado de la pestaña Biblia
  static const _almacen = FlutterSecureStorage(); // Caja fuerte
  static const _claveUltima = 'biblia_ultima'; // Dirección del último capítulo leído
  static const _claveTamano = 'biblia_tamano'; // Tamaño de letra elegido
  static const _navegadorNormal = 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36'; // "Identificación" de un Chrome de celular común

  WebViewController? _pagina; // Control de la página web (null en el navegador/pruebas)
  int _tamano = PantallaBiblia.tamanoInicial; // Tamaño de letra actual (%)
  bool _cargando = true; // ¿Está cargando la página?
  bool _sinInternet = false; // ¿Falló la carga?

  @override // Reemplaza initState
  void initState() { // Al crear la pestaña
    super.initState(); // Lo de Flutter por defecto
    if (PantallaBiblia.navegadorDisponible) _preparar(); // En el teléfono: prepara la página
  } // Fin de initState

  Future<void> _preparar() async { // Lee lo guardado y abre la página
    String direccion = PantallaBiblia.inicio; // Por defecto: Juan 3
    try { // La caja fuerte puede fallar: entonces usa lo de por defecto
      direccion = await _almacen.read(key: _claveUltima) ?? direccion; // Último capítulo leído
      _tamano = int.tryParse(await _almacen.read(key: _claveTamano) ?? '') ?? _tamano; // Tamaño de letra guardado
    } catch (_) {} // Sin datos guardados
    final pagina = WebViewController() // Crea el control de la página
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Bible.com necesita JavaScript
      ..setBackgroundColor(Colors.white) // Fondo blanco mientras carga
      ..setNavigationDelegate(NavigationDelegate( // Qué hacer al navegar
        onPageStarted: (_) { if (mounted) setState(() { _cargando = true; _sinInternet = false; }); }, // Empezó a cargar: muestra la barrita
        onPageFinished: (url) => _alTerminar(url), // Terminó: guarda el capítulo, oculta el menú de Bible.com y aplica la letra
        onUrlChange: (cambio) { // Cambió la dirección SIN recargar (ej: flechas ‹ › de capítulo: Bible.com cambia de capítulo sin recargar la página)
          _recordar(cambio.url); // Recuerda el capítulo nuevo
          _ocultarMenusDeBibleCom(); // Por si la página volvió a dibujar su menú
        }, // Fin del cambio de dirección
        onWebResourceError: (error) { // Falló algo...
          if (error.isForMainFrame == true && mounted) setState(() { _sinInternet = true; _cargando = false; }); // ...si fue la página principal: mensaje "sin internet"
        }, // Fin del error
        onNavigationRequest: (pedido) { // Antes de abrir un enlace...
          if (!pedido.isMainFrame) return NavigationDecision.navigate; // Piezas internas de la página (marcos de Google, estadísticas…): se dejan cargar (bloquearlas dejaba la página "trabada" en una imagen gigante)
          final host = Uri.tryParse(pedido.url)?.host ?? ''; // Dominio del enlace que tocó la persona
          if (host.endsWith('bible.com') || host.endsWith('youversion.com')) return NavigationDecision.navigate; // YouVersion: dentro de la app
          launchUrl(Uri.parse(pedido.url), mode: LaunchMode.externalApplication); // Cualquier otro sitio (redes sociales, tiendas): fuera de la app
          return NavigationDecision.prevent; // No lo abre aquí
        }, // Fin de la revisión
      )) // Fin de la navegación
      ..setUserAgent(_navegadorNormal) // Se presenta como Chrome normal (sin la marca "wv" de las apps), por si Bible.com trata distinto a las apps
      ..loadRequest(Uri.parse(direccion)); // Abre el capítulo
    if (mounted) setState(() => _pagina = pagina); // Muestra la página
    await _aplicarTamano(); // Aplica el tamaño de letra
  } // Fin de _preparar

  Future<void> _alTerminar(String url) async { // La página terminó de cargar
    if (mounted) setState(() => _cargando = false); // Quita la barrita
    await _ocultarMenusDeBibleCom(); // Quita el menú duplicado de Bible.com (más sencillo para adultos mayores)
    await _aplicarTamano(); // En iPhone el tamaño se aplica por página
    await _recordar(url); // Guarda el capítulo
  } // Fin de _alTerminar

  Future<void> _recordar(String? url) async { // Guarda la dirección si es un capítulo (no una búsqueda)
    if (url == null || !url.contains('/bible/')) return; // No es un capítulo: nada
    try { await _almacen.write(key: _claveUltima, value: url); } catch (_) {} // Lo recuerda para la próxima vez
  } // Fin de _recordar

  // Estilo que se agrega a la página de Bible.com para ocultar lo que ya tenemos en la app (evita dos menús y dos botones de letra):
  // encabezado "Bible App" (logo, buscar, idioma, cuenta), menú de abajo "Navegación rápida" (Inicio · Biblia · Hoy · Planes), pie de página,
  // la barra de publicidad de abajo "La Biblia App · Descargar" (la pone el servicio Branch dentro de un iframe "branch-banner…")
  // y el botón "AA" (se busca por su TEXTO: su nombre interno cambió el 30 oct 2026 y la regla vieja dejó de funcionar).
  // Como la barra y el "AA" aparecen unos segundos DESPUÉS de cargar, un vigilante (MutationObserver) los oculta en cuanto aparecen.
  // Se QUEDAN: selector de libro/capítulo, versión, audio y flechas ‹ ›.
  // Si Bible.com cambia su página y algo deja de ocultarse, la Biblia sigue funcionando igual (solo se vería eso de ellos).
  // Además fuerza el MODO CLARO: Bible.com guarda el tema en localStorage "theme" (por defecto "system" = sigue al teléfono);
  // se pone "light" y se cambia la clase del documento, para que no salga negra cuando el teléfono está en modo oscuro.
  static const _estiloOcultar = '''
(function () {
  try {
    if (localStorage.getItem('theme') !== 'light') localStorage.setItem('theme', 'light');
    var h = document.documentElement;
    h.classList.remove('dark'); h.classList.add('light'); h.style.colorScheme = 'light';
  } catch (e) {}
  if (!document.getElementById('canaan-estilo')) {
    var s = document.createElement('style');
    s.id = 'canaan-estilo';
    s.textContent = 'header, footer, nav[aria-label="Navegación rápida"], iframe[id^="branch-banner"], #branch-banner, .branch-journeys-top { display: none !important; }'
      + ' html.branch-banner-is-active, html.branch-banner-is-active body { margin-top: 0 !important; margin-bottom: 0 !important; }';
    document.head.appendChild(s);
  }
  function ocultarAA() {
    var botones = document.querySelectorAll('button, a, [role="button"]');
    for (var i = 0; i < botones.length; i++) {
      var t = (botones[i].innerText || '').split(' ').join('').trim();
      if (t === 'AA' || t === 'Aa') botones[i].style.setProperty('display', 'none', 'important');
    }
  }
  ocultarAA();
  if (!window.canaanVigilante) {
    var pendiente = false;
    window.canaanVigilante = new MutationObserver(function () {
      if (pendiente) return;
      pendiente = true;
      setTimeout(function () { pendiente = false; ocultarAA(); }, 300);
    });
    window.canaanVigilante.observe(document.body, { childList: true, subtree: true });
  }
})();
'''; // Fin del estilo (código JavaScript: crea la etiqueta <style> una sola vez, oculta el "AA" y deja un vigilante)

  Future<void> _ocultarMenusDeBibleCom() async { // Agrega el estilo de arriba a la página
    await _pagina?.runJavaScript(_estiloOcultar).catchError((_) {}); // Si falla, no pasa nada (se vería el menú de Bible.com)
  } // Fin de _ocultarMenusDeBibleCom

  Future<void> _aplicarTamano() async { // Cambia el tamaño del texto de la página
    final pagina = _pagina; // Control actual
    if (pagina == null) return; // Sin página: nada
    final android = pagina.platform; // Parte propia de cada sistema
    if (android is AndroidWebViewController) { // Android: tiene un ajuste directo
      await android.setTextZoom(_tamano); // Ej: 150 = 150 %
    } else { // iPhone: se le indica a la página con un poco de código
      await pagina.runJavaScript("document.documentElement.style.webkitTextSizeAdjust='$_tamano%';").catchError((_) {}); // Tamaño del texto en %
    } // Fin del if
  } // Fin de _aplicarTamano

  Future<void> _cambiarTamano(int paso) async { // A− (paso -1) o A+ (paso +1)
    final lista = PantallaBiblia.tamanos; // Tamaños posibles
    final actual = lista.indexOf(_tamano); // Posición actual
    final nueva = ((actual < 0 ? 1 : actual) + paso).clamp(0, lista.length - 1); // Siguiente posición (sin salirse)
    setState(() => _tamano = lista[nueva]); // Guarda el nuevo tamaño y redibuja
    await _aplicarTamano(); // Lo aplica a la página
    try { await _almacen.write(key: _claveTamano, value: '$_tamano'); } catch (_) {} // Lo recuerda
  } // Fin de _cambiarTamano

  Future<void> _buscar() async { // Botón "Buscar": pide una palabra y busca en toda la Biblia
    final campo = TextEditingController(); // Lo que escribe la persona
    final texto = await showDialog<String>( // Ventana con el campo de búsqueda
      context: context, // Dónde mostrarla
      builder: (context) => AlertDialog( // Ventana
        title: const Text('Buscar en la Biblia', style: TextStyle(fontSize: 22)), // Título grande
        content: TextField( // Campo de texto
          controller: campo, // Lo que se escribe
          autofocus: true, // Abre el teclado solo
          style: const TextStyle(fontSize: 22), // Letra grande
          textInputAction: TextInputAction.search, // Tecla "buscar" en el teclado
          decoration: const InputDecoration(hintText: 'Ej: amor, Juan 3:16'), // Ejemplo
          onSubmitted: (valor) => Navigator.pop(context, valor), // Enter = buscar
        ), // Fin del campo
        actions: [ // Botones
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(fontSize: 18))), // Cancelar
          FilledButton(onPressed: () => Navigator.pop(context, campo.text), child: const Text('Buscar', style: TextStyle(fontSize: 18))), // Buscar
        ], // Fin de los botones
      ), // Fin de la ventana
    ); // Fin de showDialog
    final palabra = texto?.trim() ?? ''; // Texto sin espacios de más
    if (palabra.isEmpty) return; // No escribió nada
    final direccion = Uri.https('www.bible.com', '/es/search/bible', {'q': palabra, 'version_id': PantallaBiblia.versionId}); // Búsqueda en la Reina-Valera 1960
    if (_pagina != null) { // En el teléfono...
      await _pagina!.loadRequest(direccion); // ...la muestra dentro de la app
    } else { // En el navegador...
      await launchUrl(direccion, mode: LaunchMode.externalApplication); // ...la abre aparte
    } // Fin del if
  } // Fin de _buscar

  Future<void> _atras() async { // Botón "Atrás": vuelve a la página anterior dentro de la Biblia
    if (await _pagina?.canGoBack() ?? false) await _pagina!.goBack(); // Solo si hay a dónde volver
  } // Fin de _atras

  Future<void> _abrirEnYouVersion() async { // Abre lo que se está leyendo en la app YouVersion (si está instalada) o en el navegador
    final actual = await _pagina?.currentUrl() ?? PantallaBiblia.inicio; // Página actual (o Juan 3)
    await launchUrl(Uri.parse(actual), mode: LaunchMode.externalApplication); // Android/iPhone eligen la app de YouVersion si existe
  } // Fin de _abrirEnYouVersion

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar( // Barra de título
        title: const Text('Biblia · Reina-Valera 1960'), // Título
        actions: [ // Botón a la derecha
          IconButton( // Abrir en YouVersion
            tooltip: 'Abrir en YouVersion', // Texto al mantener presionado (y para lectores de pantalla)
            iconSize: 28, // Ícono grande
            icon: const Icon(Icons.open_in_new), // Ícono "abrir afuera"
            onPressed: _abrirEnYouVersion, // Al tocar
          ), // Fin del botón
        ], // Fin de los botones
      ), // Fin de la barra
      body: Column( // Botones arriba y la página abajo
        children: [ // Elementos
          _Botonera( // Barra de botones grandes (adultos mayores)
            tamano: _tamano, // Tamaño actual (para mostrarlo)
            alAtras: _pagina == null ? null : _atras, // Atrás (solo con la página dentro de la app)
            alAchicar: _tamano <= PantallaBiblia.tamanos.first || _pagina == null ? null : () => _cambiarTamano(-1), // A− (apagado si ya es el mínimo)
            alAgrandar: _tamano >= PantallaBiblia.tamanos.last || _pagina == null ? null : () => _cambiarTamano(1), // A+ (apagado si ya es el máximo)
            alBuscar: _buscar, // Buscar
          ), // Fin de la botonera
          if (_cargando && _pagina != null) const LinearProgressIndicator(color: doradoCanaan, minHeight: 4), // Barrita dorada mientras carga
          Expanded( // El resto de la pantalla
            child: _pagina == null // ¿Hay página dentro de la app?
                ? _SinNavegador(alAbrir: _abrirEnYouVersion) // No (navegador/pruebas): botón para abrir afuera
                : _sinInternet // ¿Falló la carga?
                    ? _SinInternet(alReintentar: () => _pagina!.reload()) // Sí: mensaje y Reintentar
                    : WebViewWidget(controller: _pagina!), // Sí hay: la página de YouVersion
          ), // Fin del resto
        ], // Fin de los elementos
      ), // Fin de la columna
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaBibliaState

class _Botonera extends StatelessWidget { // Fila de botones grandes: Atrás · A− · A+ · Buscar
  const _Botonera({required this.tamano, required this.alAtras, required this.alAchicar, required this.alAgrandar, required this.alBuscar}); // Constructor

  final int tamano; // Tamaño de letra actual (%)
  final VoidCallback? alAtras; // Atrás (null = apagado)
  final VoidCallback? alAchicar; // A− (null = apagado)
  final VoidCallback? alAgrandar; // A+ (null = apagado)
  final VoidCallback alBuscar; // Buscar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    Widget boton(String texto, IconData? icono, VoidCallback? alTocar, String ayuda) => Expanded( // Un botón que ocupa su parte del ancho
          child: Tooltip( // Texto de ayuda (y para lectores de pantalla)
            message: ayuda, // Ej: "Letra más grande"
            child: TextButton( // Botón
              onPressed: alTocar, // Qué hace (null = gris/apagado)
              style: TextButton.styleFrom(minimumSize: const Size(0, 60), foregroundColor: context.cc.titulo), // Alto 60 (fácil de tocar), color marino
              child: Column( // Ícono arriba, texto abajo
                mainAxisSize: MainAxisSize.min, // Solo lo necesario
                children: [ // Elementos
                  if (icono != null) Icon(icono, size: 26), // Ícono grande
                  Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Texto grande
                ], // Fin de los elementos
              ), // Fin de la columna
            ), // Fin del botón
          ), // Fin de la ayuda
        ); // Fin de boton
    return Material( // Fondo de la botonera
      color: context.cc.tarjeta, // Blanca, como las tarjetas de la app (la página de la Biblia también es blanca)
      shape: Border(bottom: BorderSide(color: context.cc.borde)), // Línea suave abajo que la separa del texto
      child: Row( // Botones en fila
        children: [ // Botones
          boton('Atrás', Icons.arrow_back, alAtras, 'Volver a la página anterior'), // Atrás
          boton('A−', null, alAchicar, 'Letra más pequeña'), // Achicar
          Text('$tamano %', style: TextStyle(fontSize: 14, color: context.cc.suave)), // Tamaño actual
          boton('A+', null, alAgrandar, 'Letra más grande'), // Agrandar
          boton('Buscar', Icons.search, alBuscar, 'Buscar palabras en la Biblia'), // Buscar
        ], // Fin de los botones
      ), // Fin de la fila
    ); // Fin del fondo
  } // Fin de build
} // Fin de _Botonera

class _SinNavegador extends StatelessWidget { // En el navegador (o en las pruebas) no se puede mostrar la página dentro: botón para abrirla
  const _SinNavegador({required this.alAbrir}); // Constructor

  final VoidCallback alAbrir; // Qué hacer al tocar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Center( // Centrado
      child: Padding( // Margen
        padding: const EdgeInsets.all(24), // 24 por lado
        child: Column( // Uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Solo lo necesario
          children: [ // Elementos
            Icon(Icons.menu_book, size: 72, color: context.cc.azul), // Libro grande
            const SizedBox(height: 16), // Espacio
            const Text('La Biblia se abre en YouVersion (Reina-Valera 1960).', textAlign: TextAlign.center, style: TextStyle(fontSize: 20)), // Explicación
            const SizedBox(height: 20), // Espacio
            FilledButton.icon( // Botón grande
              onPressed: alAbrir, // Al tocar
              style: FilledButton.styleFrom(minimumSize: const Size(220, 56)), // Grande
              icon: const Icon(Icons.open_in_new), // Ícono
              label: const Text('Abrir la Biblia', style: TextStyle(fontSize: 20)), // Texto
            ), // Fin del botón
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin del centrado
  } // Fin de build
} // Fin de _SinNavegador

class _SinInternet extends StatelessWidget { // Mensaje cuando no se pudo cargar la página
  const _SinInternet({required this.alReintentar}); // Constructor

  final VoidCallback alReintentar; // Qué hacer al tocar "Reintentar"

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Center( // Centrado
      child: Padding( // Margen
        padding: const EdgeInsets.all(24), // 24 por lado
        child: Column( // Uno debajo del otro
          mainAxisSize: MainAxisSize.min, // Solo lo necesario
          children: [ // Elementos
            Icon(Icons.wifi_off, size: 64, color: context.cc.suave), // Ícono sin internet
            const SizedBox(height: 16), // Espacio
            const Text('No pudimos abrir la Biblia. Revisa tu conexión a internet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20)), // Mensaje
            const SizedBox(height: 20), // Espacio
            FilledButton(onPressed: alReintentar, style: FilledButton.styleFrom(minimumSize: const Size(200, 56)), child: const Text('Reintentar', style: TextStyle(fontSize: 20))), // Botón grande
          ], // Fin de los elementos
        ), // Fin de la columna
      ), // Fin del margen
    ); // Fin del centrado
  } // Fin de build
} // Fin de _SinInternet
