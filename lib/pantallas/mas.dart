import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../servicios/api.dart'; // Llamadas a la API (se pasa al formulario de peticiones)
import '../servicios/registro.dart'; // Registro del teléfono en el panel
import '../tema.dart'; // Colores de Canaán
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

  @override // Reemplaza initState
  void initState() { // Al crear la pestaña
    super.initState(); // Lo de Flutter por defecto
    _registro = widget.registro.iniciar(); // Usa el mismo registro que arrancó la app (no lo repite)
  } // Fin de initState

  void _reintentar() { // Vuelve a intentar el registro
    setState(() => _registro = widget.registro.reintentar()); // Nuevo intento y redibuja
  } // Fin de _reintentar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Más')), // Barra de título
      body: ListView( // Lista de opciones
        children: [ // Opciones
          ListTile( // Opción: Radio
            leading: const Icon(Icons.headphones, color: azulCanaan), // Ícono de audífonos
            title: const Text('Escuchar radio'), // Texto
            subtitle: const Text('Radio en línea de la iglesia'), // Explicación
            trailing: const Icon(Icons.chevron_right), // Flechita: abre otra pantalla
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaRadio(api: widget.api))), // Al tocar, abre la radio
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
          const Divider(), // Línea separadora
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
        ], // Fin de las opciones
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de _PantallaMasState
