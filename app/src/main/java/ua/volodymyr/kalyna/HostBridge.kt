package ua.volodymyr.kalyna

import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.FileObserver
import android.os.Handler
import android.os.HandlerThread
import android.provider.Settings
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.lang.ref.WeakReference

/**
 * What Kalyna (inside the Linux layer) knows about the phone, and what it can ask Android to do.
 *
 * Every few seconds the phone's state goes to `kalyna-host.json` in the session directory (the guest
 * sees it at the same path, `$BL_LAUNCH_DIR`): battery, Wi-Fi, volume, brightness, Bluetooth and the
 * phone's launchable apps (icons as PNGs in `kalyna-icons/`). Kalyna's system service drops
 * `kalyna-request-*.json` files there to launch an Android app, change volume or brightness, open
 * Android's Wi-Fi/Bluetooth panels, go to the Android home screen or end the session.
 */
object HostBridge {
    private const val TAG = "KalynaHost"
    private const val STATUS = "kalyna-host.json"
    private const val ICONS = "kalyna-icons"
    private const val PERIOD_MS = 3000L

    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var observer: FileObserver? = null
    private var dir: File? = null
    private var appsJson: JSONArray? = null
    private var appsStamp = 0L
    private var activity = WeakReference<Activity>(null)

    /** The session screen, for brightness (an app may always dim or brighten its own window). */
    fun attach(a: Activity) { activity = WeakReference(a) }

    @Synchronized
    fun start(context: Context, sessionDir: File) {
        stop()
        val app = context.applicationContext
        dir = sessionDir
        appsJson = null
        val t = HandlerThread("kalyna-host").apply { start() }
        thread = t
        val h = Handler(t.looper)
        handler = h
        File(sessionDir, ICONS).mkdirs()
        sessionDir.listFiles { f -> f.name.startsWith("kalyna-request-") }?.forEach { it.delete() }
        @Suppress("DEPRECATION")
        val obs = object : FileObserver(sessionDir.path, CLOSE_WRITE or MOVED_TO) {
            override fun onEvent(event: Int, path: String?) {
                if (path == null || !path.startsWith("kalyna-request-") || !path.endsWith(".json")) return
                h.post { handleRequest(app, File(sessionDir, path)) }
            }
        }
        obs.startWatching()
        observer = obs
        val tick = object : Runnable {
            override fun run() {
                runCatching { writeStatus(app, sessionDir) }.onFailure { Log.w(TAG, "status: $it") }
                h.postDelayed(this, PERIOD_MS)
            }
        }
        h.post(tick)
        Log.i(TAG, "bridge on ${sessionDir.path}")
    }

    @Synchronized
    fun stop() {
        observer?.stopWatching()
        observer = null
        handler?.removeCallbacksAndMessages(null)
        thread?.quitSafely()
        thread = null
        handler = null
    }

    // ---- status -----------------------------------------------------------------------------

    private fun writeStatus(context: Context, sessionDir: File) {
        val o = JSONObject()
        o.put("time", System.currentTimeMillis())
        o.put("battery", battery(context))
        o.put("wifi", wifi(context))
        o.put("volume", volume(context))
        o.put("brightness", JSONObject().put("percent", brightnessPercent(context)))
        o.put("bluetooth", bluetooth(context))
        o.put("apps", apps(context, sessionDir))
        val tmp = File(sessionDir, ".$STATUS.tmp")
        tmp.writeText(o.toString())
        tmp.renameTo(File(sessionDir, STATUS))
    }

    private fun battery(context: Context): JSONObject {
        val i = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val status = i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = (i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
        return JSONObject()
            .put("percent", if (level >= 0 && scale > 0) level * 100 / scale else 0)
            .put("charging", status == BatteryManager.BATTERY_STATUS_CHARGING)
            .put("plugged", plugged)
    }

    @Suppress("DEPRECATION")
    private fun wifi(context: Context): JSONObject {
        val wm = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
        val onWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val o = JSONObject().put("enabled", wm.isWifiEnabled)
        if (onWifi) {
            val info = wm.connectionInfo
            // Without location permission Android hides the name; show "Wi-Fi" then.
            val ssid = info?.ssid?.trim('"')?.takeIf { it.isNotBlank() && it != "<unknown ssid>" } ?: "Wi-Fi"
            o.put("ssid", ssid)
            o.put("signal", WifiManager.calculateSignalLevel(info?.rssi ?: -100, 101))
            val ip = info?.ipAddress ?: 0
            if (ip != 0) o.put("ip", "${ip and 255}.${ip shr 8 and 255}.${ip shr 16 and 255}.${ip shr 24 and 255}")
        } else {
            o.put("ssid", "")
        }
        return o
    }

    private fun volume(context: Context): JSONObject {
        val am = context.getSystemService(AudioManager::class.java)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        return JSONObject().put("percent", cur * 100 / max).put("muted", am.isStreamMute(AudioManager.STREAM_MUSIC))
    }

    @Volatile private var windowBrightness = -1

    private fun brightnessPercent(context: Context): Int {
        if (windowBrightness >= 0) return windowBrightness
        val v = runCatching { Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS) }.getOrDefault(128)
        return (v * 100 / 255).coerceIn(0, 100)
    }

    private fun bluetooth(context: Context): JSONObject {
        val on = runCatching { context.getSystemService(BluetoothManager::class.java)?.adapter?.isEnabled == true }.getOrDefault(false)
        return JSONObject().put("enabled", on)
    }

    /** Launchable apps, refreshed every minute; icons are written once. */
    private fun apps(context: Context, sessionDir: File): JSONArray {
        val now = System.currentTimeMillis()
        appsJson?.let { if (now - appsStamp < 60_000) return it }
        val pm = context.packageManager
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val list = JSONArray()
        val icons = File(sessionDir, ICONS)
        val own = context.packageName
        for (ri in pm.queryIntentActivities(main, 0).sortedBy { it.loadLabel(pm).toString().lowercase() }) {
            val pkg = ri.activityInfo.packageName
            if (pkg == own) continue
            val icon = File(icons, "$pkg.png")
            if (!icon.isFile) runCatching { savePng(ri.loadIcon(pm), icon) }
            list.put(JSONObject().put("package", pkg).put("name", ri.loadLabel(pm).toString())
                .put("icon", if (icon.isFile) icon.path else ""))
        }
        appsJson = list
        appsStamp = now
        return list
    }

    private fun savePng(d: android.graphics.drawable.Drawable, out: File) {
        val size = 128
        val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, size, size)
        d.draw(Canvas(b))
        val tmp = File(out.parentFile, ".${out.name}.tmp")
        tmp.outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        tmp.renameTo(out)
        b.recycle()
    }

    // ---- requests ---------------------------------------------------------------------------

    private fun handleRequest(context: Context, file: File) {
        val req = runCatching { JSONObject(file.readText()) }.getOrNull()
        file.delete()
        if (req == null) return
        val op = req.optString("op")
        Log.i(TAG, "request $op")
        try {
            when (op) {
                "launch" -> {
                    val pkg = req.optString("package")
                    context.packageManager.getLaunchIntentForPackage(pkg)?.let {
                        context.startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                }
                "volume" -> {
                    val am = context.getSystemService(AudioManager::class.java)
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, Math.round(max * req.optInt("percent", 50) / 100f), 0)
                }
                "mute" -> {
                    val am = context.getSystemService(AudioManager::class.java)
                    am.adjustStreamVolume(AudioManager.STREAM_MUSIC,
                        if (req.optBoolean("on")) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE, 0)
                }
                "brightness" -> setBrightness(context, req.optInt("percent", 50))
                "settings" -> {
                    val page = req.optString("page")
                    val action = when {
                        page == "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                        Build.VERSION.SDK_INT >= 29 -> Settings.Panel.ACTION_INTERNET_CONNECTIVITY
                        else -> Settings.ACTION_WIFI_SETTINGS
                    }
                    context.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                "home" -> context.startActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "exit", "restart" -> com.droiddeck.launcher.session.SessionService.stop(context)
                else -> Log.w(TAG, "unknown request $op")
            }
        } catch (e: Exception) {
            Log.w(TAG, "request $op failed", e)
        }
    }

    /** The phone's brightness if the app may change it, otherwise just Kalyna's window. */
    private fun setBrightness(context: Context, percent: Int) {
        val p = percent.coerceIn(1, 100)
        if (Settings.System.canWrite(context)) {
            Settings.System.putInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL)
            Settings.System.putInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, p * 255 / 100)
            windowBrightness = -1
            return
        }
        windowBrightness = p
        activity.get()?.let { a ->
            a.runOnUiThread {
                val lp = a.window.attributes
                lp.screenBrightness = p / 100f
                a.window.attributes = lp
            }
        }
    }
}
