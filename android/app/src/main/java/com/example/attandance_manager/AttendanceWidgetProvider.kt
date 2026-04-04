package com.example.attandance_manager // Update with your actual package name if different

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AttendanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val percentage = widgetData.getString("percentage", "--%")
                val attendedConducted = widgetData.getString("attended_conducted", "- / -")
                val nextClass = widgetData.getString("next_class", "Loading...")

                setTextViewText(R.id.tv_percentage, percentage)
                setTextViewText(R.id.tv_attended_conducted, attendedConducted)
                setTextViewText(R.id.tv_next_class, nextClass)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}