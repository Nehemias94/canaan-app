// Configuración general de la app (un solo lugar para cambiar la dirección del servidor)

const String apiBase = 'https://iglpanel-app.onrender.com/api'; // Dirección de la API del panel en Render

const Duration tiempoMaximoEspera = Duration(seconds: 75); // Tiempo máximo esperando respuesta (Render gratis tarda ~50 s en "despertar")
