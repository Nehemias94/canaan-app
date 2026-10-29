import 'package:flutter/material.dart'; // Componentes visuales de Flutter
import 'package:flutter/services.dart'; // Clipboard (copiar el número de cuenta)

import '../modelos/iglesia.dart'; // Molde de las ofrendas
import '../tema.dart'; // Colores de Canaán

// Pantalla "Ofrendas y diezmos": mensaje, cuentas bancarias (con botón "Copiar número") y código QR. Todo se configura en el panel.
class PantallaOfrendas extends StatelessWidget { // Pantalla de ofrendas
  const PantallaOfrendas({super.key, required this.ofrendas}); // Constructor

  final Ofrendas ofrendas; // Datos que vienen del panel

  Future<void> _copiar(BuildContext context, CuentaOfrenda cuenta) async { // Copia el número de cuenta
    await Clipboard.setData(ClipboardData(text: cuenta.numero)); // Lo pone en el portapapeles
    if (!context.mounted) return; // La pantalla ya no existe
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Número de cuenta de ${cuenta.banco} copiado. Pégalo en la app de tu banco.'))); // Aviso
  } // Fin de _copiar

  @override // Reemplaza build
  Widget build(BuildContext context) { // Describe cómo se ve
    return Scaffold( // Estructura de la pantalla
      appBar: AppBar(title: const Text('Ofrendas y diezmos')), // Barra de título
      body: ListView( // Lista desplazable
        padding: const EdgeInsets.all(16), // Margen
        children: [ // Elementos
          if ((ofrendas.mensaje ?? '').isNotEmpty) // Si hay mensaje...
            Card( // ...tarjeta con el mensaje
              child: Padding( // Margen interno
                padding: const EdgeInsets.all(16), // 16 por lado
                child: Row( // Ícono y texto
                  crossAxisAlignment: CrossAxisAlignment.start, // Arriba
                  children: [ // Elementos
                    const Icon(Icons.volunteer_activism, color: doradoOscuro, size: 30), // Manos con corazón
                    const SizedBox(width: 12), // Espacio
                    Expanded(child: Text(ofrendas.mensaje!, style: const TextStyle(fontSize: 17, height: 1.4, fontStyle: FontStyle.italic, color: marinoCanaan))), // Mensaje
                  ], // Fin de los elementos
                ), // Fin de la fila
              ), // Fin del margen
            ), // Fin de la tarjeta
          for (final cuenta in ofrendas.cuentas) // Una tarjeta por cuenta
            Card( // Tarjeta
              margin: const EdgeInsets.only(top: 12), // Separación
              child: Padding( // Margen interno
                padding: const EdgeInsets.all(16), // 16 por lado
                child: Column( // Uno debajo del otro
                  crossAxisAlignment: CrossAxisAlignment.start, // A la izquierda
                  children: [ // Elementos
                    Row( // Banco y tipo
                      children: [ // Elementos
                        const Icon(Icons.account_balance, color: azulCanaan), // Ícono de banco
                        const SizedBox(width: 10), // Espacio
                        Expanded(child: Text(cuenta.banco, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: marinoCanaan))), // Banco
                        if ((cuenta.tipo ?? '').isNotEmpty) Text(cuenta.tipo!, style: const TextStyle(color: Colors.black54, fontSize: 15)), // Tipo
                      ], // Fin de los elementos
                    ), // Fin de la fila
                    const SizedBox(height: 10), // Espacio
                    SelectableText(cuenta.numero, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF1F2937))), // Número grande (se puede seleccionar)
                    if ((cuenta.titular ?? '').isNotEmpty) // Si hay titular...
                      Padding( // ...lo muestra
                        padding: const EdgeInsets.only(top: 4), // Separación
                        child: Text('A nombre de: ${cuenta.titular}', style: const TextStyle(fontSize: 15, color: Colors.black54)), // Titular
                      ), // Fin del titular
                    const SizedBox(height: 12), // Espacio
                    SizedBox( // Botón a todo el ancho
                      width: double.infinity, // Ancho completo
                      child: FilledButton.icon( // Botón
                        onPressed: () => _copiar(context, cuenta), // Copia
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), // Alto cómodo
                        icon: const Icon(Icons.copy), // Ícono copiar
                        label: const Text('Copiar número de cuenta', style: TextStyle(fontSize: 16)), // Texto
                      ), // Fin del botón
                    ), // Fin del ancho
                  ], // Fin de los elementos
                ), // Fin de la columna
              ), // Fin del margen
            ), // Fin de la tarjeta
          if (ofrendas.qrUrl != null) // Si hay QR...
            Card( // ...tarjeta con el QR grande
              margin: const EdgeInsets.only(top: 12), // Separación
              child: Padding( // Margen interno
                padding: const EdgeInsets.all(16), // 16 por lado
                child: Column( // Uno debajo del otro
                  children: [ // Elementos
                    const Text('Escanea para dar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: marinoCanaan)), // Título
                    const SizedBox(height: 12), // Espacio
                    Image.network(ofrendas.qrUrl!, height: 260, errorBuilder: (context, error, pila) => const Text('No se pudo cargar el código QR.')), // QR
                  ], // Fin de los elementos
                ), // Fin de la columna
              ), // Fin del margen
            ), // Fin de la tarjeta
          if (ofrendas.cuentas.isEmpty && ofrendas.qrUrl == null) // Si no hay nada...
            const Padding( // ...lo explica
              padding: EdgeInsets.only(top: 24), // Separación
              child: Text('Pronto publicaremos aquí cómo dar tu ofrenda.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: Colors.black54)), // Texto
            ), // Fin del texto
        ], // Fin de los elementos
      ), // Fin de la lista
    ); // Fin del Scaffold
  } // Fin de build
} // Fin de PantallaOfrendas
