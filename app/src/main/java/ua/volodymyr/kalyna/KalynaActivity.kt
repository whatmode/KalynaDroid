package ua.volodymyr.kalyna

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.droiddeck.launcher.SessionActivity
import com.droiddeck.launcher.session.SessionService

/**
 * The app's entry point: opens Kalyna OS straight away. The session screen installs the Linux
 * runtime and the Kalyna desktop package the first time, then starts Kalyna in the Linux layer.
 */
class KalynaActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(
            Intent(this, SessionActivity::class.java)
                .putExtra(SessionService.EXTRA_MODE, SessionService.MODE_DESKTOP)
                .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
        )
        finish()
        overridePendingTransition(0, 0)
    }
}
