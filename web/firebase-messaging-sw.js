// "Service worker" de notificaciones para la versión WEB de la app (Paso 8).
// El navegador lo ejecuta aparte, aunque la pestaña esté cerrada o en segundo plano, para mostrar las notificaciones.
// Los datos de abajo deben ser IGUALES a los de lib/firebase_config.dart (no son secretos). Vacíos = sin notificaciones en la web.

importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js'); // Firebase (misma versión que usa Flutter web)
importScripts('https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js'); // Mensajería de Firebase

const configuracion = { // Datos del proyecto (copiar de Firebase → Configuración del proyecto → app Web)
  apiKey: 'AIzaSyDH7rc6-MYMOrMXZh_dzfezpBX1-UUJKZQ', // "apiKey"
  projectId: 'canaan-app-7d182', // "projectId"
  messagingSenderId: '43213134071', // "messagingSenderId"
  appId: '1:43213134071:web:370e52fbc7bd349c2f1bf2', // "appId" de la app Web
}; // Fin de los datos

if (configuracion.apiKey) { // Solo si ya se llenaron los datos
  firebase.initializeApp(configuracion); // Arranca Firebase
  firebase.messaging(); // Activa la mensajería: Firebase muestra solo las notificaciones que traen título y texto
} // Fin del if
