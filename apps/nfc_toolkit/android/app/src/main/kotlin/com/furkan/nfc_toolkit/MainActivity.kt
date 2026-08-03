package com.furkan.nfc_toolkit

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Uygulamanin tek Android etkinligi.
 *
 * NFC okuma/yazma isini `nfc_manager` eklentisi yapar; burada yalnizca
 * eklentinin sunmadigi sistem islevleri karsilanir.
 *
 * Kanal adi Dart tarafinda
 * `packages/services/nfc_transport/lib/src/android_session_service.dart`
 * icinde tanimlidir — degistirirken iki tarafi birlikte guncelle.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val SYSTEM_CHANNEL = "nfc_toolkit/system"
        private const val ACTION_NDEF_DISCOVERED = "android.nfc.action.NDEF_DISCOVERED"
        private const val ACTION_TECH_DISCOVERED = "android.nfc.action.TECH_DISCOVERED"
        private const val ACTION_TAG_DISCOVERED = "android.nfc.action.TAG_DISCOVERED"
    }

    private var systemChannel: MethodChannel? = null
    private var readPageVisible: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_CHANNEL
        )

        systemChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openNfcSettings" -> {
                    openNfcSettings()
                    result.success(null)
                }
                "canInstallUnknownApps" -> {
                    result.success(canInstallUnknownApps())
                }
                "openInstallUnknownAppsSettings" -> {
                    openInstallUnknownAppsSettings()
                    result.success(null)
                }
                "setReadPageVisible" -> {
                    readPageVisible = when (val args = call.arguments) {
                        is Boolean -> args
                        else -> call.argument<Boolean>("visible") ?: false
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        if (_isNfcIntent(intent)) {
            if (!readPageVisible) {
                setIntent(intent)
                return
            }

            systemChannel?.invokeMethod(
                "onNfcIntent",
                mapOf("action" to intent.action)
            )

            setIntent(intent)
            return
        }

        super.onNewIntent(intent)
    }

    private fun _isNfcIntent(intent: Intent?): Boolean {
        val action = intent?.action ?: return false
        return action == ACTION_NDEF_DISCOVERED ||
            action == ACTION_TECH_DISCOVERED ||
            action == ACTION_TAG_DISCOVERED
    }

    /**
     * Sistem NFC ayarlarini acar.
     *
     * ACTION_NFC_SETTINGS bazi ureticilerde bulunmayabilir; o durumda
     * genel kablosuz ayarlarina duseriz. Hicbiri acilamazsa sessizce
     * vazgeceriz — kullanici ayarlara elle gidebilir, uygulama cokmemeli.
     */
    private fun openNfcSettings() {
        val candidates = listOf(
            Settings.ACTION_NFC_SETTINGS,
            Settings.ACTION_WIRELESS_SETTINGS
        )

        for (action in candidates) {
            val intent = Intent(action).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return
            }
        }
    }

    private fun canInstallUnknownApps(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallUnknownAppsSettings() {
        val candidates = mutableListOf<Intent>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            candidates += Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }

        candidates += Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        for (intent in candidates) {
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return
            }
        }
    }
}
