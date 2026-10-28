// Configuración general de la app (un solo lugar para cambiar la dirección del servidor)

const String apiBase = 'https://iglpanel-app.onrender.com/api'; // Dirección de la API del panel en Render

const String versionApp = '0.1.0'; // Versión de la app (se envía al panel al registrar el teléfono)

const Duration tiempoMaximoEspera = Duration(seconds: 75); // Tiempo máximo esperando respuesta (Render gratis tarda ~50 s en "despertar")
