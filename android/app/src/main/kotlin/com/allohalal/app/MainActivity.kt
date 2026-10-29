package com.allohalal.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_ID = "allohalal_high_importance_channel"
        const val METHOD_CHANNEL = "com.allohalal.app/notifications"
        const val LOCATION_CHANNEL = "com.allohalal.app/location"
        const val LOCATION_PERMISSION_REQ_CODE = 9901
    }

    private var pendingLocationResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createHighImportanceNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "showSystemNotification") {
                    val title = call.argument<String>("title") ?: "Allo Halal"
                    val body = call.argument<String>("body") ?: ""
                    val url = call.argument<String>("url") ?: ""
                    showSystemNotification(title, body, url)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentLocation" -> requestAndGetLocation(result)
                    "isLocationServiceEnabled" -> {
                        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                        val enabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                        result.success(enabled)
                    }
                    "openLocationSettings" -> {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = android.net.Uri.fromParts("package", packageName, null)
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestAndGetLocation(result: MethodChannel.Result) {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val isGpsEnabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
        val isNetworkEnabled = lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

        val hasFine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!isGpsEnabled && !isNetworkEnabled) {
            result.success(
                mapOf(
                    "status" to "LOCATION_DISABLED",
                    "hasPermission" to (hasFine || hasCoarse)
                )
            )
            return
        }

        if (hasFine || hasCoarse) {
            fetchBestLocation(result)
        } else {
            pendingLocationResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                LOCATION_PERMISSION_REQ_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQ_CODE) {
            val res = pendingLocationResult
            pendingLocationResult = null
            if (res != null) {
                val granted = grantResults.isNotEmpty() &&
                        grantResults.any { it == PackageManager.PERMISSION_GRANTED }
                if (granted) {
                    fetchBestLocation(res)
                } else {
                    res.success(mapOf("status" to "PERMISSION_DENIED"))
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun fetchBestLocation(result: MethodChannel.Result) {
        try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val providers = locationManager.getProviders(true)
            var bestLocation: Location? = null

            for (provider in providers) {
                val l = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || l.accuracy < bestLocation.accuracy) {
                    bestLocation = l
                }
            }

            if (bestLocation != null) {
                result.success(
                    mapOf(
                        "status" to "SUCCESS",
                        "latitude" to bestLocation.latitude,
                        "longitude" to bestLocation.longitude
                    )
                )
                return
            }

            // If no cached last known location, request a single active update
            val activeProvider = when {
                locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                    LocationManager.NETWORK_PROVIDER
                locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                    LocationManager.GPS_PROVIDER
                else -> null
            }

            if (activeProvider == null) {
                result.success(mapOf("status" to "LOCATION_DISABLED"))
                return
            }

            var replied = false
            val listener = object : LocationListener {
                override fun onLocationChanged(loc: Location) {
                    if (!replied) {
                        replied = true
                        locationManager.removeUpdates(this)
                        result.success(
                            mapOf(
                                "status" to "SUCCESS",
                                "latitude" to loc.latitude,
                                "longitude" to loc.longitude
                            )
                        )
                    }
                }
                override fun onProviderDisabled(provider: String) {}
                override fun onProviderEnabled(provider: String) {}
                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            }

            locationManager.requestSingleUpdate(activeProvider, listener, Looper.getMainLooper())
            window.decorView.postDelayed({
                if (!replied) {
                    replied = true
                    locationManager.removeUpdates(listener)
                    result.success(null)
                }
            }, 4000)
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun createHighImportanceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Allo Halal Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High importance push notifications for Allo Halal"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun showSystemNotification(title: String, body: String, url: String) {
        createHighImportanceNotificationChannel()
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (url.isNotEmpty()) {
                putExtra("notification_url", url)
            }
        }
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            pendingIntentFlags
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify((System.currentTimeMillis() and 0xFFFFFFF).toInt(), builder.build())
    }
}
