package com.mcccanaan.canaan_app // Paquete de la app

import com.ryanheise.audioservice.AudioServiceActivity // Actividad de audio_service (necesaria para la radio en segundo plano)

class MainActivity : AudioServiceActivity() // Pantalla principal de Android: igual que la de Flutter, pero conectada al servicio de audio
