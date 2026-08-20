/*
 * BleAdvertisingService.kt
 *
 * A native Android foreground service that owns the BluetoothLeAdvertiser directly.
 * This is the ONLY correct way to keep BLE advertising alive on Android when the
 * screen is locked — the advertiser must live inside a foreground service context,
 * not in the Flutter activity context which gets deprioritized on screen lock.
 *
 * Communication with Dart:
 *   - Start: startService(context, intent) with action ACTION_START_ADVERTISING
 *            and extras: SERVICE_UUID (String), CHANNEL_ID (String), CHANNEL_NAME (String)
 *   - Stop:  startService(context, intent) with action ACTION_STOP_ADVERTISING
 */

package dev.steenbakker.flutter_ble_peripheral

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.ParcelUuid
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.UUID

class BleAdvertisingService : Service() {

    companion object {
        const val TAG = "BleAdvertisingService"
        const val ACTION_START_ADVERTISING = "dev.steenbakker.flutter_ble_peripheral.START_ADVERTISING"
        const val ACTION_STOP_ADVERTISING  = "dev.steenbakker.flutter_ble_peripheral.STOP_ADVERTISING"
        const val EXTRA_SERVICE_UUID       = "SERVICE_UUID"
        const val EXTRA_CHANNEL_ID         = "CHANNEL_ID"
        const val EXTRA_CHANNEL_NAME       = "CHANNEL_NAME"
        const val EXTRA_NOTIFICATION_TITLE = "NOTIFICATION_TITLE"
        const val EXTRA_NOTIFICATION_TEXT  = "NOTIFICATION_TEXT"
        private const val NOTIFICATION_ID  = 9471  // arbitrary unique ID
    }

    private var mBluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.i(TAG, "BleAdvertisingService: advertising started successfully in foreground service")
            isAdvertising = true
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "BleAdvertisingService: advertising start failed with error code $errorCode")
            isAdvertising = false
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_ADVERTISING -> {
                val serviceUuid       = intent.getStringExtra(EXTRA_SERVICE_UUID) ?: return START_NOT_STICKY
                val channelId         = intent.getStringExtra(EXTRA_CHANNEL_ID) ?: "spatially_ble_advertise"
                val channelName       = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: "Spatially BLE Advertising"
                val notificationTitle = intent.getStringExtra(EXTRA_NOTIFICATION_TITLE) ?: "Spatially"
                val notificationText  = intent.getStringExtra(EXTRA_NOTIFICATION_TEXT) ?: "Advertising active"

                // Promote to foreground FIRST — must happen within 10s of service start (Android 14)
                val notification = buildNotification(channelId, channelName, notificationTitle, notificationText)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    // Android 14+: must pass service type explicitly
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                Log.i(TAG, "BleAdvertisingService: promoted to foreground (connectedDevice type)")

                startAdvertising(serviceUuid)
            }
            ACTION_STOP_ADVERTISING -> {
                stopAdvertising()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun buildNotification(
        channelId: String,
        channelName: String,
        title: String,
        text: String
    ): Notification {
        // Create notification channel (required for API 26+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                setSound(null, null)
                enableLights(false)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun startAdvertising(serviceUuid: String) {
        if (isAdvertising) {
            Log.w(TAG, "BleAdvertisingService: already advertising, ignoring start request")
            return
        }

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val bluetoothAdapter: BluetoothAdapter? = bluetoothManager?.adapter

        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e(TAG, "BleAdvertisingService: Bluetooth not available or not enabled")
            stopSelf()
            return
        }

        mBluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
        if (mBluetoothLeAdvertiser == null) {
            Log.e(TAG, "BleAdvertisingService: device does not support BLE advertising")
            stopSelf()
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .setTimeout(0)  // 0 = advertise indefinitely
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(UUID.fromString(serviceUuid)))
            .build()

        Log.i(TAG, "BleAdvertisingService: calling startAdvertising() for UUID=$serviceUuid")
        mBluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    private fun stopAdvertising() {
        if (isAdvertising && mBluetoothLeAdvertiser != null) {
            Log.i(TAG, "BleAdvertisingService: stopping advertising")
            try {
                mBluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
            } catch (e: Exception) {
                Log.e(TAG, "BleAdvertisingService: error stopping advertising: ${e.message}")
            }
            isAdvertising = false
        }
        mBluetoothLeAdvertiser = null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAdvertising()
        Log.i(TAG, "BleAdvertisingService: destroyed")
    }
}
