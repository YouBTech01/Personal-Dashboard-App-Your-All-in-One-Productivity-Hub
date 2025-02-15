package com.example.my_app_984;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.widget.RemoteViews;
import android.app.PendingIntent;
import android.content.Intent;

public class PasswordWidgetProvider extends AppWidgetProvider {
	@Override
	public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
		for (int appWidgetId : appWidgetIds) {
			updateWidget(context, appWidgetManager, appWidgetId);
		}
	}

	private void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
		RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.password_widget_layout);
		
		// Set title
		views.setTextViewText(R.id.widget_title, "Password Saver");
		
		// Add click intent to open app
		Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
		if (intent != null) {
			intent.putExtra("open_passwords", true);
			PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, 
				PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
			views.setOnClickPendingIntent(R.id.widget_title, pendingIntent);
			views.setOnClickPendingIntent(R.id.add_password_button, pendingIntent);
		}

		appWidgetManager.updateAppWidget(appWidgetId, views);
	}
}