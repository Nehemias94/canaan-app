import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:url_launcher/url_launcher.dart'; // Abrir WhatsApp

import '../firebase_config.dart'; // ¿Hay notificaciones? (para mostrar sus interruptores)
import '../modelos/iglesia.dart'; // Datos de la iglesia (WhatsApp, ofrendas)
import '../servicios/notificaciones.dart'; // Aplicar los temas al cambiar los interruptores
import '../servicios/preferencias.dart'; // Letra grande y qué notificaciones recibir

import '../servicios/geocerca_fondo.dart'; // Aviso al llegar a la iglesia con la app cerrada (Paso 11)
import '../servicios/api.dart'; // Llamadas a la API (se pasa al formulario de peticiones)
import '../servicios/registro.dart'; // Registro del teléfono en el panel
import '../tema.dart'; // Colores de Canaán
import 'ofrendas.dart'; // Pantalla "Ofrendas y diezmos"
import 'peticion.dart'; // Formulario "Petición de oración"
import 'radio.dart'; // Pantalla de la radio

class PantallaMas extends StatefulWidget { // Pestaña "Más": opciones extra (se irán activando en los próximos pasos)
  const PantallaMas({super.key, required this.api, required this.registro}); // Constructor: recibe la API y el registro del teléfono

  final Api api; // Para enviar peticiones de oración
  final RegistroDispositivo registro; // Para mostrar si el teléfono quedó registrado

  @override // Reemplaza createState
  State<PantallaMas> createState() => _PantallaMasState(); // Crea el estado
} // Fin de PantallaMas

class _PantallaMasState extends State<PantallaMas> { // Estado de la pestaña Más
  late Future<void> _registro; // Proceso de registro que se vigila
  Iglesia? _iglesia; // Datos de la iglesia (WhatsApp y ofrendas; null mientras carga o si no hay internet)
  bool _avisoIglesia = false; // ¿Está activado "Avisarme al llegar a la iglesia"?
  bool _cambiandoAviso = false; // true mientras se piden permisos (para mostrar una rueda)

  @override // Reemplaza initState
  void initState() { // Al crear la pestaña
    super.initState(); // Lo de Flutter por defecto
    _registro = widget.registro.iniciar(); // Usa el mismo registro que arrancó la app (no lo repite)
    widget.api.obtenerIglesia().then((datos) { if (mounted) setState(() => _iglesia = datos); }).catchError((_) {}); // Pide WhatsApp y ofrendas (si falla, no se muestran)
    if (GeocercaFondo.soportada) { // Solo en teléfonos...
      GeocercaFondo.estaActiva().then((activa) { if (mounted) setState(() => _avisoIglesia = activa); }); // ...lee si la persona ya lo activó
    } // Fin del if
  } // Fin de initState

  Future<void> _abrirWhatsApp(String numero) async { // Abre un chat de WhatsApp con la iglesia
    final enlace = Uri.https('wa.me', '/$numero', {'text': 'Hola, les escribo desde la app de Canaán. '}); // wa.me con un saludo ya escrito
    final abrio = await launchUrl(enlace, mode: LaunchMode.externalApplication).catchError((_) => false); // Abre WhatsApp (o el navegador)
    if (!abrio && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.'))); // Aviso si falla
  } // Fin de _abrirWhatsApp

  Future<void> _cambiarAvisarEnVivo(bool valor) async { // Interruptor "Avisarme cuando estemos en vivo"
    await Preferencias.cambiarAvisosEnVivo(valor); // Lo guarda
    await ServicioNotificaciones.aplicarTemas(); // Se suscribe o se da de baja del tema en_vivo
  } // Fin de _cambiarAvisarEnVivo

  Future<void> _cambiarAvisarAnuncios(bool valor) async { // Interruptor "Avisarme de anuncios"
    await Preferencias.cambiarAvisosAnuncios(valor); // Lo guarda
    await ServicioNotificaciones.aplicarTemas(); // Se suscribe o se da de baja del tema anuncios
  } // Fin de _cambiarAvisarAnuncios

  Future<void> _cambiarAvisoIglesia(bool activar) async { // Interruptor "Avisarme al llegar a la iglesia"
    if (!activar) { // Apagarlo...
      await GeocercaFondo.desactivar(); // ...quita el círculo del teléfono
      if (mounted) setState(() => _avisoIglesia = false); // ...y redibuja
      return; // Listo
    } // Fin del if
    final acepta = await showDialog<bool>( // Antes de pedir permisos, explica para qué son (Google lo exige para la ubicación en segundo plano)
      context: context, // Dónde mostrarla
      builder: (context) => AlertDialog( // Ventana
        title: const Text('Avisos al llegar a la iglesia'), // Título
        content: const Text( // Explicación
          'Cuando llegues al templo te mostraremos los anuncios del día, aunque la app esté cerrada.\n\n' // "\n\n" = línea en blanco
          'Para eso el teléfono necesita tu ubicación "todo el tiempo". Tu ubicación NO sale del teléfono: '
          'solo él sabe si estás cerca de la iglesia. Puedes apagarlo cuando quieras aquí mismo.',
        ), // Fin de la explicación
        actions: [ // Botones
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')), // No
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')), // Sí
        ], // Fin de los botones
      ), // Fin de la ventana
    ); // Fin de showDialog
    if (acepta != true || !mounted) return; // Dijo que no (o cerró la ventana)
    setState(() => _cambiandoAviso = true); // Muestra la rueda
    String? error; // Motivo si no se pudo
    try { // Pide los datos de la iglesia y activa
      error = await GeocercaFondo.activar(await widget.api.obtenerIglesia()); // Permisos + registrar el círculo
    } catch (_) { // Sin internet
      error = 'No pudimos conectar con la iglesia. Revisa tu internet e intenta de nuevo.'; // Mensaje
    } // Fin del try
    if (!mounted) return; // La pantalla ya no existe
    setState(() { _cambiandoAviso = false; _avisoIglesia = error == null; }); // Quita la rueda y deja el interruptor según el resultado
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Listo: te avisaremos cuando llegues a la iglesia.'))); // Resultado abajo
  } // Fin de _cambiarAvisoIglesia

  void _reintentar() { // Vuelve a intentar el registro
    setState(() => _registro = widget.registro.reintentar()); // Nuevo intento y redibuja
  } // Fin de _reintentar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Servicios')), // Barra de título (antes "Más")
      body: ListView( // Lista de opciones
        padding: const EdgeInsets.all(14), // Margen alrededor de las tarjetas
        children: [ // Opciones
          if (_iglesia?.whatsapp != null) // Si el panel tiene la casilla de WhatsApp marcada...
            Padding( // ...botón verde grande
              padding: const EdgeInsets.only(bottom: 14), // Separación
              child: FilledButton.icon( // Botón
                onPressed: () => _abrirWhatsApp(_iglesia!.whatsapp!), // Abre el chat
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(58), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), // Verde WhatsApp, alto, redondeado
                icon: const Icon(Icons.chat, size: 26), // Ícono de chat
                label: const Text('Escríbenos por WhatsApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Texto
              ), // Fin del botón
            ), // Fin del margen
          Card( // Tarjeta 1: lo que la persona usa (radio, peticiones, aviso al llegar)
            clipBehavior: Clip.antiAlias, // El efecto al tocar respeta las esquinas redondeadas
            margin: EdgeInsets.zero, // Sin margen extra (lo da la lista)
            child: Column(children: [ // Opciones una debajo de otra
          ListTile( // Opción: Radio
            leading: const Icon(Icons.headphones, color: azulCanaan), // Ícono de audífonos
            title: const Text('Escuchar radio'), // Texto
            subtitle: const Text('Radio en línea de la iglesia'), // Explicación
            trailing: const Icon(Icons.chevron_right), // Flechita: abre otra pantalla
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: widget.api))), // Al tocar, abre la radio
          ), // Fin de la opción
          if (_iglesia?.ofrendas.mostrar ?? false) // Si el panel tiene marcada "Ofrendas y diezmos"...
            ListTile( // ...opción para verlas
              leading: const Icon(Icons.savings, color: azulCanaan), // Alcancía
              title: const Text('Ofrendas y diezmos'), // Texto
              subtitle: const Text('Cuentas para dar y código QR'), // Explicación
              trailing: const Icon(Icons.chevron_right), // Flechita
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaOfrendas(ofrendas: _iglesia!.ofrendas))), // Abre la pantalla
            ), // Fin de la opción
          ListTile( // Opción: Peticiones de oración
            leading: const Icon(Icons.volunteer_activism, color: azulCanaan), // Ícono de manos
            title: const Text('Petición de oración'), // Texto
            subtitle: const Text('Envía tu petición (puede ser anónima)'), // Explicación
            trailing: const Icon(Icons.chevron_right), // Flechita: indica que abre otra pantalla
            onTap: () => Navigator.push( // Al tocar, abre el formulario encima (con flecha para volver)
              context, // Desde aquí
              MaterialPageRoute(builder: (context) => PantallaPeticion(api: widget.api, registro: widget.registro)), // Pantalla a abrir
            ), // Fin de Navigator.push
          ), // Fin de la opción
          if (GeocercaFondo.soportada) // Solo en teléfonos (no en el navegador)
            SwitchListTile( // Interruptor: aviso al llegar a la iglesia
              secondary: _cambiandoAviso // Ícono de la izquierda...
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) // ...rueda mientras pide permisos
                  : const Icon(Icons.location_on, color: azulCanaan), // ...o un pin
              title: const Text('Avisarme al llegar a la iglesia'), // Texto
              subtitle: const Text('Aunque la app esté cerrada. Tu ubicación no sale del teléfono.'), // Explicación
              value: _avisoIglesia, // Encendido o apagado
              onChanged: _cambiandoAviso ? null : _cambiarAvisoIglesia, // Al tocar (bloqueado mientras pide permisos)
            ), // Fin del interruptor
            ])), // Fin de la tarjeta 1
          const SizedBox(height: 14), // Espacio entre tarjetas
          Card( // Tarjeta de PREFERENCIAS: letra grande y qué notificaciones recibir
            clipBehavior: Clip.antiAlias, // Esquinas redondeadas
            margin: EdgeInsets.zero, // Sin margen extra
            child: Column(children: [ // Interruptores
              ValueListenableBuilder<bool>( // Escucha "letra grande"
                valueListenable: Preferencias.letraGrande, // Preferencia
                builder: (context, grande, _) => SwitchListTile( // Interruptor
                  secondary: const Icon(Icons.text_increase, color: azulCanaan), // Ícono de agrandar texto
                  title: const Text('Letra grande'), // Texto
                  subtitle: const Text('Agranda los textos de toda la app'), // Explicación
                  value: grande, // Encendido o apagado
                  onChanged: Preferencias.cambiarLetraGrande, // Al tocar: guarda y la app se redibuja
                ), // Fin del interruptor
              ), // Fin de la escucha
              if (firebaseConfigurado && ServicioNotificaciones.temasSoportados) ...[ // Solo con notificaciones en el teléfono
                ValueListenableBuilder<bool>( // Escucha "avisos en vivo"
                  valueListenable: Preferencias.avisosEnVivo, // Preferencia
                  builder: (context, activo, _) => SwitchListTile( // Interruptor
                    secondary: const Icon(Icons.live_tv, color: azulCanaan), // Ícono de transmisión
                    title: const Text('Avisarme cuando estemos en vivo'), // Texto
                    value: activo, // Encendido o apagado
                    onChanged: _cambiarAvisarEnVivo, // Al tocar
                  ), // Fin del interruptor
                ), // Fin de la escucha
                ValueListenableBuilder<bool>( // Escucha "avisos de anuncios"
                  valueListenable: Preferencias.avisosAnuncios, // Preferencia
                  builder: (context, activo, _) => SwitchListTile( // Interruptor
                    secondary: const Icon(Icons.campaign, color: azulCanaan), // Ícono de megáfono
                    title: const Text('Avisarme de anuncios'), // Texto
                    subtitle: const Text('Los avisos urgentes siempre se muestran'), // Aclaración
                    value: activo, // Encendido o apagado
                    onChanged: _cambiarAvisarAnuncios, // Al tocar
                  ), // Fin del interruptor
                ), // Fin de la escucha
              ], // Fin de las notificaciones
            ])), // Fin de la tarjeta de preferencias
          const SizedBox(height: 14), // Espacio entre tarjetas
          Card( // Tarjeta 2: información (estado del teléfono, acerca de)
            clipBehavior: Clip.antiAlias, // El efecto al tocar respeta las esquinas redondeadas
            margin: EdgeInsets.zero, // Sin margen extra
            child: Column(children: [ // Filas una debajo de otra
          FutureBuilder<void>( // Fila del estado del registro: cambia según cómo va
            future: _registro, // Proceso que vigila
            builder: (context, estado) { // Se llama cada vez que cambia
              if (estado.connectionState != ConnectionState.done) { // Todavía registrando...
                return const ListTile( // ...fila con rueda pequeña
                  leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)), // Rueda girando
                  title: Text('Conectando este teléfono…'), // Texto
                ); // Fin de la fila
              } // Fin del if
              if (estado.hasError) { // Falló (ej: sin internet)...
                return ListTile( // ...fila roja con opción de reintentar
                  leading: const Icon(Icons.error_outline, color: Colors.red), // Ícono de error
                  title: const Text('Este teléfono no está conectado'), // Texto
                  subtitle: const Text('Toca para intentar de nuevo'), // Instrucción
                  onTap: _reintentar, // Al tocar, reintenta
                ); // Fin de la fila
              } // Fin del if
              return ListTile( // Registrado bien
                leading: const Icon(Icons.verified, color: Colors.green), // Ícono verde
                title: const Text('Teléfono conectado con la iglesia'), // Texto
                subtitle: Text('Número ${widget.registro.numero ?? '-'} · ${RegistroDispositivo.plataformaActual()}'), // Número en el panel y plataforma (útil en pruebas)
              ); // Fin de la fila
            }, // Fin de builder
          ), // Fin de FutureBuilder
          ListTile( // Opción: Acerca de la app
            leading: const Icon(Icons.info_outline, color: azulCanaan), // Ícono de información
            title: const Text('Acerca de la app'), // Texto
            onTap: () => showAboutDialog( // Ventana estándar "Acerca de" de Flutter
              context: context, // Dónde mostrarla
              applicationName: 'Canaán', // Nombre de la app
              applicationVersion: 'Versión 0.1 (prueba)', // Versión
              applicationIcon: Image.asset('assets/imagenes/canaan-icono.png', height: 48), // Ícono oficial dorado de Canaán
              children: const [Text('App del Ministerio Cristiano Canaán de las Asambleas de Dios.')], // Texto extra
            ), // Fin de la ventana
          ), // Fin de la opción
            ])), // Fin de la tarjeta 2
        ], // Fin de las opciones
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaMasState
