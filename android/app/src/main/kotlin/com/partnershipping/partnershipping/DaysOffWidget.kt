package com.partnershipping.partnershipping

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// Виджет «Ближайший выходной». Тексты готовит Flutter-часть и кладёт
/// в SharedPreferences на 14 дней вперёд; здесь выбираем строки за сегодня.
class DaysOffWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        val me = prefs.getString("wm_$today", null)
        val partner = prefs.getString("wp_$today", null)
        val both = prefs.getString("wb_$today", null)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            if (me == null) {
                views.setTextViewText(R.id.widget_me, "Откройте приложение, чтобы обновить")
                views.setTextViewText(R.id.widget_partner, "")
                views.setTextViewText(R.id.widget_both, "")
            } else {
                views.setTextViewText(R.id.widget_me, me)
                views.setTextViewText(R.id.widget_partner, partner ?: "")
                views.setTextViewText(R.id.widget_both, both ?: "")
            }

            val intent = Intent(context, MainActivity::class.java)
            val pi = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
