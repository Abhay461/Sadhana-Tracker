package com.example.mobile_app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mobile_app/screen_time"
    private val TAG = "ScreenTimeNative"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    result.success(hasUsagePermission())
                }
                "requestPermission" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening usage settings: ${e.message}")
                        result.success(false)
                    }
                }
                "getScreenTime" -> {
                    if (!hasUsagePermission()) {
                        result.error("NO_PERMISSION", "Usage access permission not granted", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val data = getTodayScreenTime()
                        result.success(data)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting screen time: ${e.message}", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getAppName(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(packageName, 0)
            }
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            // Fallback: clean up package name to get a sensible name
            val parts = packageName.split(".").filter {
                it != "com" && it != "google" && it != "android" && it != "apps" && it != "app"
            }
            val last = parts.lastOrNull() ?: packageName
            last.replaceFirstChar { it.uppercase() }
        }
    }

    private fun isSystemPackage(pkg: String): Boolean {
        val lowerPkg = pkg.lowercase()
        val systemPkgs = setOf(
            "com.android.systemui",
            "android",
            "com.google.android.inputmethod.latin",
            "com.sec.android.inputmethod",
            "com.samsung.android.honeyboard",
            "com.android.providers.media",
            "com.google.android.permissioncontroller",
            "com.android.settings",
            "com.android.packageinstaller",
            "com.miui.securitycenter",
            "com.miui.home",
            "com.android.vending",
            "com.google.android.apps.wellbeing",
            "com.google.android.apps.parentalcontrols"
        )
        return systemPkgs.contains(lowerPkg) ||
            lowerPkg.contains("launcher") ||
            lowerPkg.contains("theme") ||
            lowerPkg.endsWith(".home") ||
            lowerPkg.contains("inputmethod") ||
            lowerPkg.contains("keyboard") ||
            lowerPkg.contains("wallpaper") ||
            lowerPkg.contains("setupwizard")
    }

    private fun getTodayScreenTime(): Map<String, Any> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val debugLog = mutableListOf<String>()

        // Calculate today's midnight in local timezone
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val todayStartMs = cal.timeInMillis
        val nowMs = System.currentTimeMillis()
        val maxPossibleMs = nowMs - todayStartMs

        debugLog.add("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
        debugLog.add("Android: ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
        debugLog.add("Package: $packageName")
        debugLog.add("Permission: ${hasUsagePermission()}")
        debugLog.add("Max possible: ${maxPossibleMs / 1000 / 60} min since midnight")

        var appUsageMs = mutableMapOf<String, Long>()
        var method = "none"

        // ===== METHOD 1 (PRIMARY): queryEvents - track actual screen sessions =====
        // Most accurate: manually compute from ACTIVITY_RESUMED → ACTIVITY_PAUSED
        try {
            val usageEvents = usageStatsManager.queryEvents(todayStartMs, nowMs)

            // Track active activities in each package using a set of classNames to handle sub-activities correctly
            val activeActivities = mutableMapOf<String, MutableSet<String>>() // key = packageName
            val lastResumeTime = mutableMapOf<String, Long>() // key = packageName
            
            var eventCount = 0
            var resumeCount = 0
            var pauseCount = 0

            val event = UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                eventCount++
                val pkg = event.packageName ?: continue
                val timestamp = event.timeStamp
                val className = event.className ?: ""

                when (event.eventType) {
                    UsageEvents.Event.ACTIVITY_RESUMED -> {
                        val classes = activeActivities.getOrPut(pkg) { mutableSetOf() }
                        if (classes.isEmpty()) {
                            // Package was not in foreground, now it is!
                            lastResumeTime[pkg] = timestamp
                        }
                        classes.add(className)
                        resumeCount++
                    }
                    UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                        val classes = activeActivities[pkg]
                        if (classes != null) {
                            classes.remove(className)
                            if (classes.isEmpty()) {
                                // Package is no longer in foreground
                                val resumeTime = lastResumeTime.remove(pkg)
                                if (resumeTime != null && timestamp > resumeTime) {
                                    val duration = timestamp - resumeTime
                                    if (duration > 0 && duration <= maxPossibleMs) {
                                        appUsageMs[pkg] = (appUsageMs[pkg] ?: 0L) + duration
                                    }
                                }
                            }
                        }
                        pauseCount++
                    }
                }
            }

            // Handle currently foreground apps (still resumed at nowMs)
            for ((pkg, resumeTime) in lastResumeTime) {
                if (nowMs > resumeTime) {
                    val duration = nowMs - resumeTime
                    if (duration > 0 && duration <= maxPossibleMs) {
                        appUsageMs[pkg] = (appUsageMs[pkg] ?: 0L) + duration
                    }
                }
            }

            debugLog.add("Method1 queryEvents: $eventCount events (R:$resumeCount P:$pauseCount), ${appUsageMs.size} apps")
            if (appUsageMs.values.sum() > 0) {
                method = "queryEvents_refCount"
            }
        } catch (e: Exception) {
            debugLog.add("Method1 ERROR: ${e.message}")
        }

        // ===== METHOD 2 (FALLBACK): queryUsageStats with totalTimeVisible (SDK 29+) =====
        if (appUsageMs.values.sum() == 0L) {
            try {
                val stats: List<UsageStats> = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY, todayStartMs, nowMs
                )
                debugLog.add("Method2 INTERVAL_DAILY: ${stats.size} entries")

                for (stat in stats) {
                    val pkg = stat.packageName ?: continue
                    // Use totalTimeVisible on Android 10+ (matches Digital Wellbeing)
                    // Fall back to totalTimeInForeground on older versions
                    val fg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        stat.totalTimeVisible
                    } else {
                        stat.totalTimeInForeground
                    }
                    if (fg > 0) {
                        val cappedFg = minOf(fg, maxPossibleMs)
                        appUsageMs[pkg] = maxOf(appUsageMs[pkg] ?: 0L, cappedFg)
                    }
                }
                debugLog.add("Method2 apps with fg>0: ${appUsageMs.size}")

                if (appUsageMs.values.sum() > 0L) {
                    method = "queryUsageStats_DAILY_visible"
                }
            } catch (e: Exception) {
                debugLog.add("Method2 ERROR: ${e.message}")
            }
        }

        debugLog.add("Final method used: $method")

        // Filter system apps, apply per-app cap, and sort
        val filtered = appUsageMs.filter { (pkg, ms) ->
            ms > 0 && !isSystemPackage(pkg)
        }.mapValues { (_, ms) ->
            minOf(ms, maxPossibleMs)
        }

        val sorted = filtered.entries.sortedByDescending { it.value }

        var totalMs = 0L
        val appList = mutableListOf<Map<String, Any>>()
        for (entry in sorted) {
            totalMs += entry.value
            val mins = (entry.value / 1000 / 60).toInt()
            val appName = getAppName(entry.key)
            if (mins > 0) {
                val h = mins / 60
                val m = mins % 60
                val label = if (h > 0) "${h}h ${m}m" else "${m}m"
                appList.add(mapOf(
                    "package" to entry.key,
                    "name" to appName,
                    "duration" to label,
                    "ms" to entry.value
                ))
                debugLog.add("  $appName: ${label} (${entry.key})")
            } else if (entry.value > 10000) {
                val secs = (entry.value / 1000).toInt()
                appList.add(mapOf(
                    "package" to entry.key,
                    "name" to appName,
                    "duration" to "${secs}s",
                    "ms" to entry.value
                ))
            }
        }

        // Cap total at max possible
        totalMs = minOf(totalMs, maxPossibleMs)

        val totalMins = (totalMs / 1000 / 60).toInt()
        val totalH = totalMins / 60
        val totalM = totalMins % 60
        val totalLabel = if (totalH > 0) "${totalH}h ${totalM}m" else "${totalM}m"

        debugLog.add("Total: $totalLabel ($totalMs ms), Apps: ${appList.size}")

        Log.d(TAG, debugLog.joinToString("\n"))

        return mapOf(
            "totalMs" to totalMs,
            "totalLabel" to totalLabel,
            "apps" to appList,
            "method" to method,
            "debug" to debugLog
        )
    }
}
