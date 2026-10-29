import 'package:flutter/foundation.dart'; // ValueNotifier (un valor que avisa cuando cambia)

// "Timbre" para recargar Inicio al momento (sin esperar la revisión de cada 90 s).
// Lo toca el aviso silencioso del panel cuando cambia el AVISO URGENTE; Inicio lo escucha y vuelve a pedir los datos.
const String avisoRecargarInicio = 'actualizar_inicio'; // Tipo del aviso silencioso (igual que AvisoUrgente::AVISO_RECARGAR en el panel)

final ValueNotifier<int> recargarInicio = ValueNotifier<int>(0); // Cada vez que su número sube, Inicio recarga

void tocarTimbreInicio() => recargarInicio.value++; // Sube el número: Inicio se entera y recarga
