# Reglas para R8 (el "reductor" que achica el APK final y borra lo que cree que no se usa).
# Flutter incluye este archivo solo en la versión final (release).

# WorkManager (lo usa native_geofence, Paso 11): Room crea su base de datos por reflexión
# y R8 borraba el constructor → la app se cerraba al abrir ("NoSuchMethodException: WorkDatabase_Impl.<init>").
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
