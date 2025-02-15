package com.example.my_app_984;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.widget.RemoteViews;
import android.app.PendingIntent;
import android.content.Intent;

public class CalculatorWidgetProvider extends AppWidgetProvider {
	@Override
	public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
		for (int appWidgetId : appWidgetIds) {
			updateWidget(context, appWidgetManager, appWidgetId);
		}
	}

	private void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
		RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.calculator_widget_layout);
		
		// Add click intent to open calculator
		Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
		if (intent != null) {
			intent.putExtra("open_calculator", true);
			PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, 
				PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
				
			// Set click listeners for all buttons
			int[] buttonIds = {
				R.id.btn_0, R.id.btn_1, R.id.btn_2, R.id.btn_3, R.id.btn_4,
				R.id.btn_5, R.id.btn_6, R.id.btn_7, R.id.btn_8, R.id.btn_9,
				R.id.btn_plus, R.id.btn_minus, R.id.btn_multiply, R.id.btn_divide,
				R.id.btn_equals, R.id.btn_clear
			};
			
			for (int buttonId : buttonIds) {
				views.setOnClickPendingIntent(buttonId, pendingIntent);
			}
		}

		appWidgetManager.updateAppWidget(appWidgetId, views);
	}
}