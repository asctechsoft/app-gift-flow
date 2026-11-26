package com.asc.gift_flow.widget

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.asc.gift_flow.MainActivity
import com.asc.gift_flow.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Gắn dữ liệu (Flutter lưu qua home_widget) và hành động chạm vào RemoteViews. */
object WidgetBinder {
    private fun launch(ctx: Context, route: String) =
        HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse("giftflow://$route"))

    private fun text(v: RemoteViews, id: Int, s: String?, hideIfEmpty: Boolean = false) {
        v.setTextViewText(id, s ?: "")
        v.setViewVisibility(id, if (hideIfEmpty && s.isNullOrEmpty()) View.GONE else View.VISIBLE)
    }

    fun small(ctx: Context, d: SharedPreferences): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_small)
        text(v, R.id.w_event, d.getString("w_event", "GiftFlow AI"))
        text(v, R.id.w_total, d.getString("w_total", "-"))
        text(v, R.id.w_today, d.getString("w_today", ""), true)
        text(v, R.id.w_btn_voice, d.getString("w_btn_voice", "Voice"))
        v.setOnClickPendingIntent(R.id.widget_root, launch(ctx, "home"))
        v.setOnClickPendingIntent(R.id.w_btn_voice, launch(ctx, "voice"))
        return v
    }

    fun medium(ctx: Context, d: SharedPreferences): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_medium)
        text(v, R.id.w_event, d.getString("w_event", "GiftFlow AI"))
        text(v, R.id.w_total, d.getString("w_total", "-"))
        val counts = "${d.getString("w_env", "0")} ${d.getString("w_env_label", "")} · " +
            "${d.getString("w_guests", "0")} ${d.getString("w_guests_label", "")}"
        text(v, R.id.w_counts, counts)
        text(v, R.id.w_btn_voice, d.getString("w_btn_voice", "Voice"))
        text(v, R.id.w_btn_quick, d.getString("w_btn_quick", "Quick"))
        text(v, R.id.w_next_title, d.getString("w_next_title", ""))
        text(v, R.id.w_next_when, d.getString("w_next_when", ""), true)
        text(v, R.id.w_next_amount, d.getString("w_next_amount", ""), true)
        v.setOnClickPendingIntent(R.id.widget_root, launch(ctx, "home"))
        v.setOnClickPendingIntent(R.id.w_btn_voice, launch(ctx, "voice"))
        v.setOnClickPendingIntent(R.id.w_btn_quick, launch(ctx, "quick"))
        v.setOnClickPendingIntent(R.id.w_next_panel, launch(ctx, "invitations"))
        return v
    }
}
