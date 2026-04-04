package com.example.attandance_manager

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CalendarWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.calendar_widget_layout).apply {
                val allClasses = widgetData.getString("all_classes", "No classes today")
                setTextViewText(R.id.tv_all_classes, allClasses)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
