import 'package:firebase_core/firebase_core.dart'; // FirebaseOptions (datos del proyecto de Firebase)
import 'package:flutter/foundation.dart'; // kIsWeb y defaultTargetPlatform (saber en qué plataforma corre)

// Datos del proyecto de Firebase (Paso 8: notificaciones).
// NO son secretos: identifican el proyecto (van dentro de la app y de la página web). Los secretos (cuenta de servicio) van SOLO en el panel.
// Se copian de: Firebase → ⚙ Configuración del proyecto → General → "Tus apps" (una app Web y una Android).
// Mientras estén vacíos, la app funciona normal pero SIN notificaciones.

const String _proyectoId = ''; // "projectId", ej: "canaan-app-1234"
const String _remitenteId = ''; // "messagingSenderId", ej: "123456789012"
const String _apiKey = ''; // "apiKey", ej: "AIzaSy…"

const String _appIdWeb = ''; // "appId" de la app WEB, ej: "1:123456789012:web:abc123"
const String _appIdAndroid = ''; // "appId" de la app ANDROID, ej: "1:123456789012:android:def456"
const String _appIdIos = ''; // "appId" de la app iPHONE (más adelante)

const String vapidKey = ''; // Solo web: Firebase → Cloud Messaging → "Certificados push web" → par de claves (empieza con "B…")

bool get firebaseConfigurado { // ¿Están los datos para esta plataforma?
  if (_proyectoId.isEmpty || _remitenteId.isEmpty || _apiKey.isEmpty) return false; // Faltan los datos comunes
  if (kIsWeb) return _appIdWeb.isNotEmpty && vapidKey.isNotEmpty; // Navegador: necesita su appId y la clave VAPID
  if (defaultTargetPlatform == TargetPlatform.iOS) return _appIdIos.isNotEmpty; // iPhone
  return _appIdAndroid.isNotEmpty; // Android
} // Fin de firebaseConfigurado

FirebaseOptions opcionesFirebase() { // Datos para arrancar Firebase en esta plataforma
  return FirebaseOptions( // Datos
    apiKey: _apiKey, // Llave pública del proyecto
    projectId: _proyectoId, // Id del proyecto
    messagingSenderId: _remitenteId, // Id del remitente de notificaciones
    appId: kIsWeb ? _appIdWeb : (defaultTargetPlatform == TargetPlatform.iOS ? _appIdIos : _appIdAndroid), // appId según la plataforma
  ); // Fin de los datos
} // Fin de opcionesFirebase
