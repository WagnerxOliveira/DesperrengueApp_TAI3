package br.com.desperrengue.app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

private const val FOUNDER_OTA_SUBDIR = "ota"
private const val FOUNDER_APK_FILE_NAME = "desperrengue-founder-ceo.apk"
private const val APK_MIME_TYPE = "application/vnd.android.package-archive"

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val otaExecutor = Executors.newSingleThreadExecutor()
    private val otaDownloadActive = AtomicBoolean(false)

    private var flagSecureActive: Boolean = false
    private var bypassExpiresAtEpochMs: Long = 0L
    private var otaChannel: MethodChannel? = null

    @Volatile
    private var pendingPermissionApkFile: File? = null

    private val relockRunnable = Runnable {
        applyFlagSecureProtection(enable = true)
    }

    private val isFounderCeoBuild: Boolean
        get() = applicationContext.packageName.endsWith(".founder")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFounderCeoBuild) {
            applyFlagSecureProtection(enable = true)
            cleanupStaleOtaArtifactsAsync()
        }
    }

    override fun onResume() {
        super.onResume()
        if (!isFounderCeoBuild) return
        val waitingApk = pendingPermissionApkFile
        if (waitingApk != null && canInstallPackagesNow()) {
            pendingPermissionApkFile = null
            if (waitingApk.exists() && waitingApk.length() > 0L) {
                val launched = launchNativePackageInstaller(waitingApk)
                emitOtaProgress(
                    phase = if (launched) "installer_launched" else "error",
                    receivedBytes = waitingApk.length(),
                    totalBytes = waitingApk.length(),
                    progress = 1.0,
                    errorCode = if (launched) null else "ERR_INSTALLER_UNAVAILABLE"
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!isFounderCeoBuild) return

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.desperrengue.app.founder/security"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getScreenProtectionStatus" -> {
                    result.success(
                        mapOf(
                            "flagSecureActive" to flagSecureActive,
                            "bypassExpiresAtEpochMs" to bypassExpiresAtEpochMs
                        )
                    )
                }
                "setTemporaryCaptureAllowed" -> {
                    val allow = call.argument<Boolean>("allow") ?: false
                    val minutes = (call.argument<Int>("minutes") ?: 5).coerceIn(1, 5)
                    mainHandler.removeCallbacks(relockRunnable)
                    if (allow) {
                        val durationMs = minutes * 60_000L
                        bypassExpiresAtEpochMs = System.currentTimeMillis() + durationMs
                        applyFlagSecureProtection(enable = false)
                        mainHandler.postDelayed(relockRunnable, durationMs)
                    } else {
                        bypassExpiresAtEpochMs = 0L
                        applyFlagSecureProtection(enable = true)
                    }
                    result.success(
                        mapOf(
                            "flagSecureActive" to flagSecureActive,
                            "bypassExpiresAtEpochMs" to bypassExpiresAtEpochMs
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.desperrengue.app.founder/ota"
        )
        otaChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallPackages" -> {
                    result.success(canInstallPackagesNow())
                }
                "openInstallPermissionSettings" -> {
                    result.success(openUnknownAppSourcesSettings())
                }
                "triggerPendingInstall" -> {
                    val otaFile = File(File(applicationContext.cacheDir, FOUNDER_OTA_SUBDIR), FOUNDER_APK_FILE_NAME)
                    if (!otaFile.exists() || otaFile.length() <= 0L) {
                        result.success(mapOf("status" to "missing_file"))
                    } else if (!canInstallPackagesNow()) {
                        pendingPermissionApkFile = otaFile
                        openUnknownAppSourcesSettings()
                        result.success(mapOf("status" to "permission_required"))
                    } else {
                        pendingPermissionApkFile = null
                        val ok = launchNativePackageInstaller(otaFile)
                        result.success(
                            mapOf("status" to if (ok) "installer_launched" else "error")
                        )
                    }
                }
                "downloadAndInstallApk" -> {
                    val apkUrl = call.argument<String>("apkUrl")?.trim().orEmpty()
                    val expectedSha256 = call.argument<String>("expectedSha256")?.trim()?.lowercase(Locale.ROOT)
                    if (!isTrustedGithubHttpsUrl(apkUrl) ||
                        !apkUrl.lowercase(Locale.ROOT).contains(FOUNDER_APK_FILE_NAME)
                    ) {
                        result.error(
                            "ERR_UNTRUSTED_OTA_URL",
                            "URL de atualização rejeitada pela política Zero-Trust.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    if (!otaDownloadActive.compareAndSet(false, true)) {
                        result.error(
                            "ERR_OTA_ALREADY_RUNNING",
                            "Download de atualização já está em andamento.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    otaExecutor.execute {
                        try {
                            val outcome = performStreamingOtaDownload(apkUrl, expectedSha256)
                            mainHandler.post {
                                val apkFile = outcome.file
                                if (!canInstallPackagesNow()) {
                                    pendingPermissionApkFile = apkFile
                                    openUnknownAppSourcesSettings()
                                    emitOtaProgress(
                                        phase = "permission_required",
                                        receivedBytes = outcome.bytesWritten,
                                        totalBytes = outcome.bytesWritten,
                                        progress = 1.0,
                                        sha256 = outcome.sha256Hex
                                    )
                                    result.success(
                                        mapOf(
                                            "status" to "permission_required",
                                            "bytes" to outcome.bytesWritten,
                                            "sha256" to outcome.sha256Hex
                                        )
                                    )
                                } else {
                                    pendingPermissionApkFile = null
                                    val launched = launchNativePackageInstaller(apkFile)
                                    if (launched) {
                                        emitOtaProgress(
                                            phase = "installer_launched",
                                            receivedBytes = outcome.bytesWritten,
                                            totalBytes = outcome.bytesWritten,
                                            progress = 1.0,
                                            sha256 = outcome.sha256Hex
                                        )
                                        result.success(
                                            mapOf(
                                                "status" to "installer_launched",
                                                "bytes" to outcome.bytesWritten,
                                                "sha256" to outcome.sha256Hex
                                            )
                                        )
                                    } else {
                                        emitOtaProgress(
                                            phase = "error",
                                            receivedBytes = outcome.bytesWritten,
                                            totalBytes = outcome.bytesWritten,
                                            progress = 1.0,
                                            errorCode = "ERR_INSTALLER_UNAVAILABLE"
                                        )
                                        result.error(
                                            "ERR_INSTALLER_UNAVAILABLE",
                                            "Não foi possível iniciar o instalador nativo do Android.",
                                            null
                                        )
                                    }
                                }
                            }
                        } catch (e: SecurityException) {
                            mainHandler.post {
                                emitOtaProgress(
                                    phase = "error",
                                    receivedBytes = 0L,
                                    totalBytes = 0L,
                                    progress = 0.0,
                                    errorCode = e.message ?: "ERR_OTA_SECURITY"
                                )
                                result.error(
                                    "ERR_OTA_SECURITY",
                                    e.message ?: "Falha de integridade criptográfica do APK.",
                                    null
                                )
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                emitOtaProgress(
                                    phase = "error",
                                    receivedBytes = 0L,
                                    totalBytes = 0L,
                                    progress = 0.0,
                                    errorCode = "ERR_OTA_NETWORK"
                                )
                                result.error(
                                    "ERR_OTA_NETWORK",
                                    e.message ?: "Falha de rede durante download da atualização.",
                                    null
                                )
                            }
                        } finally {
                            otaDownloadActive.set(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(relockRunnable)
        otaChannel?.setMethodCallHandler(null)
        otaChannel = null
        otaExecutor.shutdownNow()
        super.onDestroy()
    }

    private data class DownloadedApkResult(
        val file: File,
        val bytesWritten: Long,
        val sha256Hex: String
    )

    private fun performStreamingOtaDownload(
        initialUrl: String,
        expectedSha256: String?
    ): DownloadedApkResult {
        val otaDir = File(applicationContext.cacheDir, FOUNDER_OTA_SUBDIR).apply { mkdirs() }
        val partFile = File(otaDir, "$FOUNDER_APK_FILE_NAME.part")
        val finalFile = File(otaDir, FOUNDER_APK_FILE_NAME)
        if (partFile.exists()) partFile.delete()

        var currentUrl = initialUrl
        var connection: HttpURLConnection? = null
        try {
            var redirects = 0
            while (true) {
                if (!isTrustedGithubHttpsUrl(currentUrl)) {
                    throw SecurityException("ERR_UNTRUSTED_REDIRECT_HOST")
                }
                val conn = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    requestMethod = "GET"
                    setRequestProperty("User-Agent", "DesperrengueCEO-OTA/2.13")
                    setRequestProperty("Accept", "application/octet-stream")
                }
                val code = conn.responseCode
                if (code in setOf(301, 302, 303, 307, 308)) {
                    val location = conn.getHeaderField("Location")?.trim()
                    conn.disconnect()
                    if (location.isNullOrEmpty() || redirects >= 5) {
                        throw SecurityException("ERR_INVALID_OTA_REDIRECT")
                    }
                    currentUrl = URI(currentUrl).resolve(location).toString()
                    redirects++
                    continue
                }
                if (code != HttpURLConnection.HTTP_OK) {
                    conn.disconnect()
                    throw IllegalStateException("HTTP $code ao baixar pacote de atualização.")
                }
                connection = conn
                break
            }

            val activeConn = connection
            val contentLength = activeConn.contentLengthLong
            val digest = MessageDigest.getInstance("SHA-256")
            var bytesWritten = 0L
            var lastProgressEmitMs = 0L

            emitOtaProgressOnMain(
                phase = "downloading",
                receivedBytes = 0L,
                totalBytes = if (contentLength > 0L) contentLength else 0L,
                progress = 0.0
            )

            activeConn.inputStream.use { input ->
                FileOutputStream(partFile).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        bytesWritten += read

                        val now = System.currentTimeMillis()
                        if (now - lastProgressEmitMs >= 80L) {
                            lastProgressEmitMs = now
                            val frac = if (contentLength > 0L) {
                                (bytesWritten.toDouble() / contentLength.toDouble()).coerceIn(0.0, 1.0)
                            } else {
                                0.0
                            }
                            emitOtaProgressOnMain(
                                phase = "downloading",
                                receivedBytes = bytesWritten,
                                totalBytes = if (contentLength > 0L) contentLength else 0L,
                                progress = frac
                            )
                        }
                    }
                    output.fd.sync()
                }
            }

            if (bytesWritten <= 0L || (contentLength > 0L && bytesWritten != contentLength)) {
                partFile.delete()
                throw IllegalStateException("Download incompleto ($bytesWritten de $contentLength bytes).")
            }

            emitOtaProgressOnMain(
                phase = "verifying",
                receivedBytes = bytesWritten,
                totalBytes = bytesWritten,
                progress = 1.0
            )

            val computedSha256 = digest.digest().joinToString("") { "%02x".format(it) }
            if (!expectedSha256.isNullOrBlank() &&
                !computedSha256.equals(expectedSha256, ignoreCase = true)
            ) {
                partFile.delete()
                throw SecurityException("ERR_OTA_SHA256_MISMATCH")
            }

            if (finalFile.exists()) {
                finalFile.delete()
            }
            if (!partFile.renameTo(finalFile)) {
                partFile.copyTo(finalFile, overwrite = true)
                partFile.delete()
            }

            return DownloadedApkResult(
                file = finalFile,
                bytesWritten = bytesWritten,
                sha256Hex = computedSha256
            )
        } catch (t: Throwable) {
            if (partFile.exists()) {
                runCatching { partFile.delete() }
            }
            throw t
        } finally {
            connection?.disconnect()
        }
    }

    private fun emitOtaProgressOnMain(
        phase: String,
        receivedBytes: Long,
        totalBytes: Long,
        progress: Double,
        sha256: String? = null,
        errorCode: String? = null
    ) {
        mainHandler.post {
            emitOtaProgress(
                phase = phase,
                receivedBytes = receivedBytes,
                totalBytes = totalBytes,
                progress = progress,
                sha256 = sha256,
                errorCode = errorCode
            )
        }
    }

    private fun emitOtaProgress(
        phase: String,
        receivedBytes: Long,
        totalBytes: Long,
        progress: Double,
        sha256: String? = null,
        errorCode: String? = null
    ) {
        val payload = HashMap<String, Any?>(6).apply {
            put("phase", phase)
            put("receivedBytes", receivedBytes)
            put("totalBytes", totalBytes)
            put("progress", progress)
            if (sha256 != null) put("sha256", sha256)
            if (errorCode != null) put("errorCode", errorCode)
        }
        otaChannel?.invokeMethod("onOtaProgress", payload)
    }

    private fun canInstallPackagesNow(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openUnknownAppSourcesSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${applicationContext.packageName}")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun launchNativePackageInstaller(apkFile: File): Boolean {
        if (!apkFile.exists() || apkFile.length() <= 0L) return false
        val authority = "${applicationContext.packageName}.ota.provider"
        val contentUri = Uri.Builder()
            .scheme("content")
            .authority(authority)
            .appendPath(FOUNDER_APK_FILE_NAME)
            .build()
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(installIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun cleanupStaleOtaArtifactsAsync() {
        otaExecutor.execute {
            runCatching {
                val otaDir = File(applicationContext.cacheDir, FOUNDER_OTA_SUBDIR)
                if (!otaDir.exists()) return@execute
                val cutoff = System.currentTimeMillis() - 30 * 60_000L
                otaDir.listFiles()?.forEach { f ->
                    if (f.isFile && f.lastModified() < cutoff) {
                        f.delete()
                    }
                }
            }
        }
    }

    private fun isTrustedGithubHttpsUrl(rawUrl: String): Boolean {
        return try {
            val uri = URI(rawUrl.trim())
            val scheme = uri.scheme?.lowercase(Locale.ROOT) ?: return false
            if (scheme != "https") return false
            if (uri.rawUserInfo != null) return false
            if (uri.port != -1 && uri.port != 443) return false
            val host = uri.host?.lowercase(Locale.ROOT) ?: return false
            host == "github.com" || host.endsWith(".githubusercontent.com")
        } catch (_: Exception) {
            false
        }
    }

    private fun applyFlagSecureProtection(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                setRecentsScreenshotEnabled(false)
            }
            flagSecureActive = true
            bypassExpiresAtEpochMs = 0L
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                setRecentsScreenshotEnabled(true)
            }
            flagSecureActive = false
        }
    }
}

/**
 * Provider isolado exclusivamente no manifesto `src/founder/AndroidManifest.xml`
 * (`br.com.desperrengue.app.founder.ota.provider`, `exported=false`).
 * Entrega somente o binário verificado `cacheDir/ota/desperrengue-founder-ceo.apk`
 * ao PackageInstaller nativo do sistema Android, eliminando qualquer navegador externo.
 */
class FounderOtaFileProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun resolveVerifiedFounderApk(uri: Uri): File {
        val ctx = context ?: throw FileNotFoundException("Contexto indisponível.")
        if (!ctx.packageName.endsWith(".founder")) {
            throw SecurityException("Provider exclusivo do binário soberano CEO.")
        }
        if (uri.lastPathSegment != FOUNDER_APK_FILE_NAME) {
            throw SecurityException("Artefato não autorizado.")
        }
        val otaDir = File(ctx.cacheDir, FOUNDER_OTA_SUBDIR).canonicalFile
        val candidate = File(otaDir, FOUNDER_APK_FILE_NAME).canonicalFile
        if (candidate.parentFile != otaDir || !candidate.exists() || !candidate.isFile) {
            throw FileNotFoundException("Pacote OTA não encontrado em cache.")
        }
        return candidate
    }

    override fun getType(uri: Uri): String = APK_MIME_TYPE

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val apkFile = resolveVerifiedFounderApk(uri)
        val requested = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cols = ArrayList<String>(requested.size)
        val values = ArrayList<Any?>(requested.size)
        for (col in requested) {
            when (col) {
                OpenableColumns.DISPLAY_NAME -> {
                    cols.add(OpenableColumns.DISPLAY_NAME)
                    values.add(FOUNDER_APK_FILE_NAME)
                }
                OpenableColumns.SIZE -> {
                    cols.add(OpenableColumns.SIZE)
                    values.add(apkFile.length())
                }
            }
        }
        return MatrixCursor(cols.toTypedArray(), 1).apply {
            addRow(values.toTypedArray())
        }
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") {
            throw SecurityException("Somente leitura permitida.")
        }
        val apkFile = resolveVerifiedFounderApk(uri)
        return ParcelFileDescriptor.open(apkFile, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("Somente leitura.")

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException("Somente leitura.")

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = throw UnsupportedOperationException("Somente leitura.")
}
