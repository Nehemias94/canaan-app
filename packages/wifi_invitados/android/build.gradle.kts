group = "com.mcccanaan.wifi_invitados" // Grupo del complemento
version = "1.0" // Versión

buildscript { // Herramientas para compilar
    repositories { // De dónde se descargan
        google() // Repositorio de Google
        mavenCentral() // Repositorio general
    } // Fin de los repositorios
    dependencies { // Herramientas
        classpath("com.android.tools.build:gradle:9.0.1") // Compilador de Android (el mismo que usan otros complementos de la app)
    } // Fin de las herramientas
} // Fin de buildscript

allprojects { // Para todo el proyecto
    repositories { // De dónde se descargan las librerías
        google() // Google
        mavenCentral() // General
    } // Fin de los repositorios
} // Fin de allprojects

plugins { // Tipo de proyecto
    id("com.android.library") // Librería de Android (no una app)
} // Fin de plugins

android { // Ajustes de Android
    namespace = "com.mcccanaan.wifi_invitados" // Paquete Java
    compileSdk = 36 // Se compila con Android 16
    compileOptions { // Versión de Java
        sourceCompatibility = JavaVersion.VERSION_17 // Java 17
        targetCompatibility = JavaVersion.VERSION_17 // Java 17
    } // Fin de compileOptions
    defaultConfig { // Ajustes generales
        minSdk = 21 // Funciona desde Android 5 (las sugerencias solo desde Android 10: se revisa en el código)
    } // Fin de defaultConfig
} // Fin de android
