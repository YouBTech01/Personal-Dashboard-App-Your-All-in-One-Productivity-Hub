package com.example.my_app_984;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.content.ComponentName;
import android.app.PendingIntent;
import android.content.Intent;

public class StepWidgetProvider extends AppWidgetProvider {
	@Override
	public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
		for (int appWidgetId : appWidgetIds) {
			updateWidget(context, appWidgetManager, appWidgetId);
		}
	}

	private void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
		RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.step_widget_layout);
		
		// Get stored step data
		SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
		int steps = prefs.getInt("flutter.steps", 0);
		double calories = steps * 0.04;
		double distance = steps * 0.0008;

		// Update widget views
		views.setTextViewText(R.id.steps_text, steps + " Steps");
		views.setTextViewText(R.id.calories_text, String.format("%.1f kcal", calories));
		views.setTextViewText(R.id.distance_text, String.format("%.2f km", distance));

		// Add click intent to open app
		Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
		if (intent != null) {
			PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, 
				PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
			views.setOnClickPendingIntent(R.id.steps_text, pendingIntent);
		}

		// Update the widget
		appWidgetManager.updateAppWidget(appWidgetId, views);
	}
}