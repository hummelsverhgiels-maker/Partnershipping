package com.partnershipping.partnershipping

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// Виджет «Ближайший выходной». Тексты готовит Flutter-часть и кладёт в
/// SharedPreferences на 14 дней вперёд; здесь выбираем строки за сегодня.
/// Раз в ~30 минут виджет сам спрашивает у сервера свежие тексты (сообщения,
/// настроение, график), поэтому он живой, даже когда приложение закрыто.
class DaysOffWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        render(context, appWidgetManager, appWidgetIds)

        val prefs = prefs(context)
        val urls = (prefs.getString("cfg_urls", "") ?: "").split(",").filter { it.isNotBlank() }
        val key = prefs.getString("cfg_key", null)
        val code = prefs.getString("cfg_code", null)
        val member = prefs.getString("cfg_member", null)
        if (urls.isEmpty() || key == null || code == null || member == null) return

        val pending = goAsync()
        Thread {
            try {
                for (base in urls) {
                    val json = fetch(base, key, code, member)
                    if (json != null) {
                        store(prefs, json)
                        render(context, appWidgetManager, appWidgetIds)
                        break
                    }
                }
            } catch (_: Exception) {
            } finally {
                pending.finish()
            }
        }.start()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    private fun today(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun fetch(base: String, key: String, code: String, member: String): JSONObject? {
        return try {
            val conn = URL("$base/rest/v1/rpc/get_widget").openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 7000
            conn.readTimeout = 9000
            conn.doOutput = true
            conn.setRequestProperty("apikey", key)
            conn.setRequestProperty("Content-Type", "application/json")
            OutputStreamWriter(conn.outputStream).use {
                it.write("""{"p_code":"$code","p_member":"$member"}""")
            }
            if (conn.responseCode != 200) return null
            val text = conn.inputStream.bufferedReader().readText()
            if (text.isBlank() || text == "null") null else JSONObject(text)
        } catch (_: Exception) {
            null
        }
    }

    /// Кладём свежие строки в хранилище виджета.
    private fun store(prefs: android.content.SharedPreferences, json: JSONObject) {
        val ed = prefs.edit()
        val keys = json.keys()
        val todayKey = today()
        while (keys.hasNext()) {
            val date = keys.next()
            val arr: JSONArray = json.optJSONArray(date) ?: continue
            ed.putString("wm_$date", arr.optString(0, ""))
            ed.putString("wp_$date", arr.optString(1, ""))
            ed.putString("wb_$date", arr.optString(2, ""))
            if (date == todayKey) {
                ed.putString("wchat", arr.optString(3, ""))
                ed.putString("wmood", arr.optString(4, ""))
            }
        }
        ed.apply()
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = prefs(context)
        val today = today()
        val me = prefs.getString("wm_$today", null)
        val partner = prefs.getString("wp_$today", null)
        val both = prefs.getString("wb_$today", null)
        val chat = prefs.getString("wchat", "") ?: ""
        val mood = prefs.getString("wmood", "") ?: ""

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
            if (mood.isNotBlank()) {
                views.setTextViewText(R.id.widget_mood, mood)
                views.setViewVisibility(R.id.widget_mood, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_mood, View.GONE)
            }
            if (chat.isNotBlank()) {
                views.setTextViewText(R.id.widget_chat, chat)
                views.setViewVisibility(R.id.widget_chat, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_chat, View.GONE)
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
