package com.example.my_app_984;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.app.PendingIntent;
import android.content.Intent;
import org.json.JSONArray;
import org.json.JSONObject;

public class TodoWidgetProvider extends AppWidgetProvider {
	@Override
	public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
		for (int appWidgetId : appWidgetIds) {
			updateWidget(context, appWidgetManager, appWidgetId);
		}
	}

	private void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
		RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.todo_widget_layout);
		
		try {
			SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
			String todosJson = prefs.getString("flutter.todos", "[]");
			JSONArray todos = new JSONArray(todosJson);
			
			// Count incomplete todos
			int incompleteTodos = 0;
			for (int i = 0; i < todos.length(); i++) {
				JSONObject todo = todos.getJSONObject(i);
				if (!todo.getBoolean("isCompleted")) {
					incompleteTodos++;
				}
			}
			
			// Update widget title
			views.setTextViewText(R.id.widget_title, "Todo List (" + incompleteTodos + ")");
			
			// Add click intent to open app
			Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
			if (intent != null) {
				PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, 
					PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
				views.setOnClickPendingIntent(R.id.widget_title, pendingIntent);
				views.setOnClickPendingIntent(R.id.add_todo_button, pendingIntent);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}

		appWidgetManager.updateAppWidget(appWidgetId, views);
	}
}