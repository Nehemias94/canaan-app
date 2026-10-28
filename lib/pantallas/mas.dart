import 'package:flutter/material.dart'; // Componentes visuales de Flutter

import '../tema.dart'; // Colores de Canaán

class PantallaMas extends StatelessWidget { // Pestaña "Más": opciones extra (se irán activando en los próximos pasos)
  const PantallaMas({super.key}); // Constructor

  void _proximamente(BuildContext context, String que) { // Muestra un aviso abajo para lo que aún no está hecho
    ScaffoldMessenger.of(context).showSnackBar( // Barra de aviso temporal
      SnackBar(content: Text('$que estará disponible pronto.')), // Texto del aviso
    ); // Fin del aviso
  } // Fin de _proximamente

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
            onTap: () => _proximamente(context, 'La radio'), // Al tocar: "próximamente"
          ), // Fin de la opción
          ListTile( // Opción: Peticiones de oración
            leading: const Icon(Icons.volunteer_activism, color: azulCanaan), // Ícono de manos
            title: const Text('Petición de oración'), // Texto
            subtitle: const Text('Envía tu petición (puede ser anónima)'), // Explicación
            onTap: () => _proximamente(context, 'El envío de peticiones'), // Al tocar: "próximamente"
          ), // Fin de la opción
          const Divider(), // Línea separadora
          ListTile( // Opción: Acerca de la app
            leading: const Icon(Icons.info_outline, color: azulCanaan), // Ícono de información
            title: const Text('Acerca de la app'), // Texto
            onTap: () => showAboutDialog( // Ventana estándar "Acerca de" de Flutter
              context: context, // Dónde mostrarla
              applicationName: 'Canaán', // Nombre de la app
              applicationVersion: 'Versión 0.1 (prueba)', // Versión
              applicationIcon: const Icon(Icons.church, color: doradoCanaan, size: 40), // Ícono
              children: const [Text('App del Ministerio Cristiano Canaán de las Asambleas de Dios.')], // Texto extra
            ), // Fin de la ventana
          ), // Fin de la opción
        ], // Fin de las opciones
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaMas
