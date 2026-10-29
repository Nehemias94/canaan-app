// Configuración general de la app (un solo lugar para cambiar la dirección del servidor)

const String apiBase = 'https://iglpanel-app.onrender.com/api'; // Dirección de la API del panel en Render

const String versionApp = '0.1.0'; // Versión de la app (se envía al panel al registrar el teléfono)

const Duration intervaloActualizacion = Duration(seconds: 90); // Cada cuánto Inicio vuelve a preguntar al panel (en vivo, radio, aviso, anuncios)

const Duration tiempoMaximoEspera = Duration(seconds: 75); // Tiempo máximo esperando respuesta (Render gratis tarda ~50 s en "despertar")

const Duration esperaConCopia = Duration(seconds: 12); // Si ya hay una copia guardada, se espera menos: pasado este tiempo, se muestra la copia (sin internet o señal muy débil)
