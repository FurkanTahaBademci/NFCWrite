package com.furkan.nfc_toolkit

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Uygulamanin tek Android etkinligi.
 *
 * NFC okuma/yazma isini `nfc_manager` eklentisi yapar; burada yalnizca
 * eklentinin sunmadigi sistem islevleri karsilanir.
 *
 * ## On plan NFC sahiplenmesi
 *
 * Android'de bir etiket okutuldugunda dagitim sirasi sudur:
 *
 *   1. **Reader mode** (`enableReaderMode`) — en yuksek oncelik, sessiz,
 *      hicbir Intent uretilmez.
 *   2. **On plan dagitimi** (`enableForegroundDispatch`) — Intent dogrudan
 *      on plandaki etkinlige gelir, uygulama secici cikmaz.
 *   3. **Arka plan dagitimi** (manifest intent-filter) — sistem hangi
 *      uygulamanin acilacagina karar verir; birden fazla aday varsa
 *      "uygulama secin" penceresi/bildirimi cikar.
 *
 * `nfc_manager` reader mode'u **yalnizca aktif oturum boyunca** acar.
 * Oturum yokken (ana ekranda dururken, form doldururken...) hicbir katman
 * etiketi sahiplenmedigi icin 3. adim devreye giriyordu — kullanicinin
 * gordugu surekli bildirim buydu.
 *
 * Cozum iki katmanli:
 *
 *   * Etkinlik on plandayken **her zaman** on plan dagitimi acik tutulur —
 *     etiket asla baska uygulamaya ya da sisteme gitmez.
 *   * Okuma ekraninda degilken ve aktif bir oturum yokken ustune **sessiz
 *     nobet** (no-op reader mode + `NO_PLATFORM_SOUNDS`) kurulur — etiket
 *     sessizce yutulur, ses bile calmaz.
 *
 * Okuma ekranindayken nobet bilerek kaldirilir: etiket `onNewIntent`'e
 * duser ve Dart tarafina `onNfcIntent` olarak iletilir (dokun-ve-oku).
 *
 * Kanal adi Dart tarafinda
 * `packages/services/nfc_transport/lib/src/android_session_service.dart`
 * icinde tanimlidir — degistirirken iki tarafi birlikte guncelle.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "NfcToolkit"
        private const val SYSTEM_CHANNEL = "nfc_toolkit/system"
        private const val ACTION_NDEF_DISCOVERED = "android.nfc.action.NDEF_DISCOVERED"
        private const val ACTION_TECH_DISCOVERED = "android.nfc.action.TECH_DISCOVERED"
        private const val ACTION_TAG_DISCOVERED = "android.nfc.action.TAG_DISCOVERED"

        /**
         * Sessiz nobetin okuyucu bayraklari.
         *
         * Tum teknolojiler dinlenir; NDEF kontrolu atlanir (bos/ham
         * etiketler de yakalansin) ve platform sesi kapatilir.
         */
        // Not: `const val` bitsel `or` kabul etmez — duz `val` olmali.
        private val GUARD_READER_FLAGS =
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_NFC_F or
                NfcAdapter.FLAG_READER_NFC_V or
                NfcAdapter.FLAG_READER_NFC_BARCODE or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK or
                NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS
    }

    private var systemChannel: MethodChannel? = null
    private var readPageVisible: Boolean = false

    private var nfcAdapter: NfcAdapter? = null
    private var nfcPendingIntent: PendingIntent? = null

    /** Etkinlik su an on planda mi? */
    private var resumed: Boolean = false

    /** Dart tarafinda `nfc_manager` oturumu calisiyor mu? */
    private var nfcSessionActive: Boolean = false

    /** Sessiz nobet (no-op reader mode) su an kurulu mu? */
    private var guardArmed: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        // On plan dagitiminin hedefi: kendimiz. singleTop oldugumuz icin
        // yeni bir kopya acilmaz, Intent onNewIntent'e duser.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Sistem etiket ekstralarini doldurdugu icin MUTABLE zorunlu.
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }
        nfcPendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            flags
        )
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        applyNfcClaim()
    }

    override fun onPause() {
        // disableForegroundDispatch etkinlik hala on plandayken cagrilmali.
        releaseNfcClaim()
        resumed = false
        super.onPause()
    }

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
                    applyNfcClaim()
                    result.success(null)
                }
                "setNfcSessionActive" -> {
                    nfcSessionActive = when (val args = call.arguments) {
                        is Boolean -> args
                        else -> call.argument<Boolean>("active") ?: false
                    }
                    applyNfcClaim()
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

    /**
     * On plan NFC sahiplenmesini guncel duruma gore kurar.
     *
     * Her durum degisikliginde (sekme degisti, oturum basladi/bitti,
     * etkinlik on plana geldi) cagrilir; ayni durumda tekrar cagrilmasi
     * zararsizdir.
     */
    private fun applyNfcClaim() {
        val adapter = nfcAdapter ?: return
        if (!resumed) return

        // 1. Katman — etiket her kosulda once bize gelsin.
        // Bu olmadan Android arka plan dagitimini calistirir: uygulama
        // secici penceresi, bildirim ya da baska bir NFC uygulamasi.
        //
        // Aktif oturum sirasinda da kayitli birakilir: reader mode zaten
        // daha yuksek oncelikli oldugu icin bu kayit devreye girmez, ama
        // oturum beklenmedik sekilde duserse (uygulama arka plana atilip
        // geri gelirse Android reader mode'u kapatir) bosluk kalmaz.
        try {
            adapter.enableForegroundDispatch(this, nfcPendingIntent, null, null)
        } catch (e: Exception) {
            // Etkinlik tam olarak on planda degilse firlatabilir; NFC yine
            // de calisir, yalnizca dagitim onceligini alamayiz.
            Log.w(TAG, "enableForegroundDispatch basarisiz", e)
        }

        // 2. Katman — okuma ekraninda degilsek ve oturum yoksa etiketi
        // sessizce yut.
        //
        //   * Oturum varken nobet kurulmaz: reader mode'u nfc_manager
        //     yonetiyor, ustune yazarsak okuma bozulur.
        //   * Okuma ekranindayken nobet kurulmaz: Intent bize gelsin ve
        //     dokun-ve-oku akisi calissin.
        if (nfcSessionActive || readPageVisible) {
            disarmGuard(adapter)
        } else {
            armGuard(adapter)
        }
    }

    private fun armGuard(adapter: NfcAdapter) {
        if (guardArmed) return
        try {
            // Callback bilerek bos: etiket okunmaz, yalnizca sisteme
            // "bu etiketi ben aldim" denir ve dagitim engellenir.
            adapter.enableReaderMode(
                this,
                NfcAdapter.ReaderCallback { },
                GUARD_READER_FLAGS,
                null
            )
            guardArmed = true
        } catch (e: Exception) {
            Log.w(TAG, "Sessiz NFC nobeti kurulamadi", e)
        }
    }

    private fun disarmGuard(adapter: NfcAdapter) {
        if (!guardArmed) return
        try {
            adapter.disableReaderMode(this)
        } catch (e: Exception) {
            Log.w(TAG, "Sessiz NFC nobeti kapatilamadi", e)
        }
        guardArmed = false
    }

    /** Etkinlik arka plana giderken sahiplenmeyi birakir. */
    private fun releaseNfcClaim() {
        val adapter = nfcAdapter ?: return

        try {
            adapter.disableForegroundDispatch(this)
        } catch (e: Exception) {
            Log.w(TAG, "disableForegroundDispatch basarisiz", e)
        }

        // Android duraklamada reader mode'u zaten kapatir; bayragi da
        // sifirlayalim ki geri donunce yeniden kurulsun.
        disarmGuard(adapter)
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
