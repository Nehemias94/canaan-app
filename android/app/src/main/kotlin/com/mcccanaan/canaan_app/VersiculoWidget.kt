package com.mcccanaan.canaan_app // Paquete de la app

import android.appwidget.AppWidgetManager // Administrador de widgets de Android
import android.content.Context // Contexto de Android
import android.content.SharedPreferences // Datos que guarda la app (home_widget)
import android.widget.RemoteViews // Vista del widget (se dibuja fuera de la app, en la pantalla de inicio)
import es.antonborri.home_widget.HomeWidgetLaunchIntent // Abrir la app al tocar el widget
import es.antonborri.home_widget.HomeWidgetProvider // Clase base de home_widget

// Widget "Versículo del día" en la pantalla de inicio del teléfono.
// La app guarda el versículo con home_widget (claves versiculo_texto y versiculo_referencia) cada vez que carga Inicio, y pide redibujarlo.
class VersiculoWidget : HomeWidgetProvider() { // Proveedor del widget
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) { // Se llama al agregarlo y cuando la app lo actualiza
        appWidgetIds.forEach { id -> // Cada copia del widget que la persona puso en su pantalla
            val vista = RemoteViews(context.packageName, R.layout.widget_versiculo).apply { // Diseño del widget (res/layout/widget_versiculo.xml)
                setTextViewText(R.id.widget_texto, widgetData.getString("versiculo_texto", null) ?: "Abre la app Canaán para ver el versículo de hoy.") // Texto del versículo (o una invitación si aún no hay)
                setTextViewText(R.id.widget_referencia, widgetData.getString("versiculo_referencia", null) ?: "") // Cita, ej: "Juan 3:16"
                setOnClickPendingIntent(R.id.widget_raiz, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)) // Al tocarlo, abre la app
            } // Fin del diseño
            appWidgetManager.updateAppWidget(id, vista) // Lo dibuja
        } // Fin del recorrido
    } // Fin de onUpdate
} // Fin de VersiculoWidget
