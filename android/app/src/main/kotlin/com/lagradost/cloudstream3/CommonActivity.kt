package com.lagradost.cloudstream3

import android.app.Activity

/**
 * Activity bridge used by providers that need an in-app WebView challenge
 * while running inside AniTV's embedded CloudStream engine.
 */
object CommonActivity {
    @JvmField
    var activity: Activity? = null
}
