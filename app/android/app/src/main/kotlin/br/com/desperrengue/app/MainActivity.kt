package br.com.desperrengue.app

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
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

private const val OTA_CACHE_SUBDIR = "ota"
private const val PUBLIC_APK_FILE_NAME = "desperrengue.apk"
private const val FOUNDER_APK_FILE_NAME = "desperrengue-founder-ceo.apk"
private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
private const val DOCUMENT_PICKER_CHANNEL = "br.com.desperrengue.app/document_picker"
private const val REQUEST_CODE_PICK_DOCUMENT_DOWNLOADS = 29031
private const val MAX_DOCUMENT_BYTES = 15 * 1024 * 1024

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val otaExecutor = Executors.newSingleThreadExecutor()
    private val documentExecutor = Executors.newSingleThreadExecutor()
    private val otaDownloadActive = AtomicBoolean(false)

    private var flagSecureActive: Boolean = false
    private var bypassExpiresAtEpochMs: Long = 0L
    private var otaChannel: MethodChannel? = null
    private var documentPickerChannel: MethodChannel? = null
    private var pendingDocumentPickerResult: MethodChannel.Result? = null

    @Volatile
    private var pendingPermissionApkFile: File? = null

    private val relockRunnable = Runnable {
        applyFlagSecureProtection(enable = true)
    }

    private val isFounderCeoBuild: Boolean
        get() = applicationContext.packageName.endsWith(".founder")

    private val expectedApkFileName: String
        get() = if (isFounderCeoBuild) FOUNDER_APK_FILE_NAME else PUBLIC_APK_FILE_NAME

    private val otaChannelName: String
        get() = if (isFounderCeoBuild) {
            "br.com.desperrengue.app.founder/ota"
        } else {
            "br.com.desperrengue.app/ota"
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFounderCeoBuild) {
            applyFlagSecureProtection(enable = true)
        }
        cleanupStaleOtaArtifactsAsync()
    }

    override fun onResume() {
        super.onResume()
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

        if (isFounderCeoBuild) {
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "br.com.desperrengue.app.founder/security"
            ).setMethodCallHandler { call, result ->
                when (call.method) {
                    "getScreenProtectionStatus" -> {
                        val remainingMs = (bypassExpiresAtEpochMs - System.currentTimeMillis()).coerceAtLeast(0L)
                        result.success(
                            mapOf(
                                "flagSecureActive" to flagSecureActive,
                                "temporaryCaptureAllowed" to (!flagSecureActive && remainingMs > 0L),
                                "remainingCaptureMs" to remainingMs,
                                "bypassExpiresAtEpochMs" to bypassExpiresAtEpochMs
                            )
                        )
                    }
                    "setTemporaryCaptureAllowed" -> {
                        val allow = call.argument<Boolean>("allow") ?: false
                        val durationSec = call.argument<Int>("durationSeconds")
                        val minutes = (call.argument<Int>("minutes") ?: 5).coerceIn(1, 5)
                        val durationMs = if (durationSec != null) {
                            durationSec.coerceIn(30, 300) * 1000L
                        } else {
                            minutes * 60_000L
                        }
                        mainHandler.removeCallbacks(relockRunnable)
                        if (allow) {
                            bypassExpiresAtEpochMs = System.currentTimeMillis() + durationMs
                            applyFlagSecureProtection(enable = false)
                            mainHandler.postDelayed(relockRunnable, durationMs)
                        } else {
                            bypassExpiresAtEpochMs = 0L
                            applyFlagSecureProtection(enable = true)
                        }
                        val remainingMs = (bypassExpiresAtEpochMs - System.currentTimeMillis()).coerceAtLeast(0L)
                        result.success(
                            mapOf(
                                "flagSecureActive" to flagSecureActive,
                                "temporaryCaptureAllowed" to !flagSecureActive,
                                "remainingCaptureMs" to remainingMs,
                                "bypassExpiresAtEpochMs" to bypassExpiresAtEpochMs
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        }

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            otaChannelName
        )
        otaChannel = channel
        channel.setMethodCallHandler { call, result ->
            val targetApkName = expectedApkFileName
            when (call.method) {
                "canInstallPackages" -> {
                    result.success(canInstallPackagesNow())
                }
                "openInstallPermissionSettings" -> {
                    result.success(openUnknownAppSourcesSettings())
                }
                "triggerPendingInstall" -> {
                    val otaFile = File(File(applicationContext.cacheDir, OTA_CACHE_SUBDIR), targetApkName)
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
                    if (!isAuthorizedFlavorApkUrl(apkUrl)) {
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
                            val outcome = performStreamingOtaDownload(
                                initialUrl = apkUrl,
                                targetFileName = targetApkName,
                                expectedSha256 = expectedSha256
                            )
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
                                val secCode = e.message ?: "ERR_OTA_SECURITY"
                                emitOtaProgress(
                                    phase = "error",
                                    receivedBytes = 0L,
                                    totalBytes = 0L,
                                    progress = 0.0,
                                    errorCode = secCode
                                )
                                result.error(
                                    secCode,
                                    "Verificação de segurança bloqueou o pacote ($secCode).",
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

        val docChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOCUMENT_PICKER_CHANNEL
        )
        documentPickerChannel = docChannel
        docChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDocumentInDownloads" -> launchDownloadsDocumentPicker(result)
                "renderPdfFirstPagePng" -> {
                    val pdfBytes = (call.arguments as? ByteArray)
                        ?: call.argument<ByteArray>("bytes")
                    val targetWidth = call.argument<Int>("targetWidth") ?: 1600
                    if (pdfBytes == null || pdfBytes.isEmpty()) {
                        result.error(
                            "ERR_INVALID_PDF_BYTES",
                            "Conteúdo PDF vazio ou inválido.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    if (pdfBytes.size > MAX_DOCUMENT_BYTES) {
                        result.error(
                            "ERR_FILE_TOO_LARGE",
                            "O arquivo PDF excede o limite de 15 MB.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    documentExecutor.execute {
                        try {
                            val pngBytes = renderPdfFirstPageToPng(pdfBytes, targetWidth)
                            mainHandler.post { result.success(pngBytes) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error(
                                    "ERR_PDF_RENDER_FAILED",
                                    e.message ?: "Não foi possível renderizar a página do PDF.",
                                    null
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun launchDownloadsDocumentPicker(result: MethodChannel.Result) {
        if (pendingDocumentPickerResult != null) {
            result.error(
                "ERR_PICKER_ALREADY_ACTIVE",
                "Já existe uma seleção de arquivo em andamento.",
                null
            )
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp")
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val downloadsUri = Uri.parse(
                    "content://com.android.externalstorage.documents/document/primary%3ADownload%2F"
                )
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, downloadsUri)
            }
        }
        pendingDocumentPickerResult = result
        try {
            startActivityForResult(intent, REQUEST_CODE_PICK_DOCUMENT_DOWNLOADS)
        } catch (e: Exception) {
            pendingDocumentPickerResult = null
            result.error(
                "ERR_PICKER_UNAVAILABLE",
                e.message ?: "Seletor nativo de arquivos indisponível neste aparelho.",
                null
            )
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_PICK_DOCUMENT_DOWNLOADS) {
            val pending = pendingDocumentPickerResult
            pendingDocumentPickerResult = null
            if (pending == null) return
            val uri = if (resultCode == RESULT_OK) data?.data else null
            if (uri == null) {
                pending.success(null)
                return
            }
            documentExecutor.execute {
                try {
                    val payload = readPickedDocumentUri(uri)
                    mainHandler.post { pending.success(payload) }
                } catch (e: IllegalStateException) {
                    mainHandler.post {
                        pending.error(
                            "ERR_FILE_TOO_LARGE",
                            e.message ?: "O arquivo selecionado excede o limite de 15 MB.",
                            null
                        )
                    }
                } catch (e: Exception) {
                    mainHandler.post {
                        pending.error(
                            "ERR_DOCUMENT_READ_FAILED",
                            e.message ?: "Não foi possível ler o arquivo selecionado.",
                            null
                        )
                    }
                }
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun readPickedDocumentUri(uri: Uri): Map<String, Any> {
        var displayName = ""
        var reportedSize = -1L
        contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIdx >= 0) {
                    displayName = cursor.getString(nameIdx)?.trim().orEmpty()
                }
                val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) {
                    reportedSize = cursor.getLong(sizeIdx)
                }
            }
        }
        if (reportedSize > MAX_DOCUMENT_BYTES.toLong()) {
            throw IllegalStateException("O arquivo selecionado ultrapassa o limite máximo de 15 MB.")
        }

        val mimeType = contentResolver.getType(uri)?.trim().orEmpty().ifEmpty {
            inferDocumentMimeType(displayName)
        }
        if (displayName.isEmpty()) {
            displayName = when {
                mimeType.contains("pdf", ignoreCase = true) -> "certidao_pf.pdf"
                mimeType.contains("png", ignoreCase = true) -> "certidao_pf.png"
                mimeType.contains("webp", ignoreCase = true) -> "certidao_pf.webp"
                else -> "certidao_pf.jpg"
            }
        }

        val baos = ByteArrayOutputStream()
        contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(32 * 1024)
            var totalRead = 0
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                totalRead += read
                if (totalRead > MAX_DOCUMENT_BYTES) {
                    throw IllegalStateException("O arquivo selecionado ultrapassa o limite máximo de 15 MB.")
                }
                baos.write(buffer, 0, read)
            }
        } ?: throw FileNotFoundException("Não foi possível abrir o arquivo selecionado.")

        return mapOf(
            "bytes" to baos.toByteArray(),
            "fileName" to displayName,
            "mimeType" to mimeType
        )
    }

    private fun inferDocumentMimeType(fileName: String): String {
        val lower = fileName.lowercase(Locale.ROOT)
        return when {
            lower.endsWith(".pdf") -> "application/pdf"
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".webp") -> "image/webp"
            lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> "image/jpeg"
            else -> "application/octet-stream"
        }
    }

    private fun renderPdfFirstPageToPng(pdfBytes: ByteArray, targetWidth: Int): ByteArray? {
        val tempPdf = File.createTempFile("pf_cert_", ".pdf", applicationContext.cacheDir)
        try {
            FileOutputStream(tempPdf).use { fos ->
                fos.write(pdfBytes)
                fos.flush()
            }
            ParcelFileDescriptor.open(tempPdf, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
                PdfRenderer(pfd).use { renderer ->
                    if (renderer.pageCount <= 0) return null
                    renderer.openPage(0).use { page ->
                        val pageW = page.width.coerceAtLeast(1)
                        val pageH = page.height.coerceAtLeast(1)
                        val clampedWidth = targetWidth.coerceIn(600, 2200)
                        val scale = clampedWidth.toFloat() / pageW.toFloat()
                        val rawHeight = (pageH * scale).toInt().coerceAtLeast(1)
                        val maxHeight = 3200
                        val finalHeight: Int
                        val finalWidth: Int
                        if (rawHeight > maxHeight) {
                            finalHeight = maxHeight
                            finalWidth = (pageW.toFloat() * maxHeight.toFloat() / pageH.toFloat())
                                .toInt()
                                .coerceAtLeast(1)
                        } else {
                            finalWidth = clampedWidth
                            finalHeight = rawHeight
                        }
                        val bitmap = Bitmap.createBitmap(
                            finalWidth,
                            finalHeight,
                            Bitmap.Config.ARGB_8888
                        )
                        try {
                            bitmap.eraseColor(Color.WHITE)
                            page.render(
                                bitmap,
                                null,
                                null,
                                PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                            )
                            val out = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                            return out.toByteArray()
                        } finally {
                            bitmap.recycle()
                        }
                    }
                }
            }
        } finally {
            runCatching { tempPdf.delete() }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(relockRunnable)
        otaChannel?.setMethodCallHandler(null)
        otaChannel = null
        documentPickerChannel?.setMethodCallHandler(null)
        documentPickerChannel = null
        pendingDocumentPickerResult = null
        otaExecutor.shutdownNow()
        documentExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun isAuthorizedFlavorApkUrl(rawUrl: String): Boolean {
        if (!isTrustedGithubHttpsUrl(rawUrl)) return false
        val lower = rawUrl.lowercase(Locale.ROOT)
        return if (isFounderCeoBuild) {
            lower.endsWith("/$FOUNDER_APK_FILE_NAME")
        } else {
            !lower.contains("founder") && lower.endsWith("/$PUBLIC_APK_FILE_NAME")
        }
    }

    private data class DownloadedApkResult(
        val file: File,
        val bytesWritten: Long,
        val sha256Hex: String
    )

    private fun performStreamingOtaDownload(
        initialUrl: String,
        targetFileName: String,
        expectedSha256: String?
    ): DownloadedApkResult {
        val otaDir = File(applicationContext.cacheDir, OTA_CACHE_SUBDIR).apply { mkdirs() }
        val partFile = File(otaDir, "$targetFileName.part")
        val finalFile = File(otaDir, targetFileName)
        if (partFile.exists()) partFile.delete()

        var currentUrl = initialUrl
        var connection: HttpURLConnection? = null
        try {
            var redirects = 0
            while (true) {
                if (!isTrustedGithubHttpsUrl(currentUrl)) {
                    throw SecurityException("ERR_UNTRUSTED_REDIRECT_HOST")
                }
                val userAgent = if (isFounderCeoBuild) {
                    "DesperrengueCEO-OTA/2.19"
                } else {
                    "Desperrengue-OTA/2.19"
                }
                val conn = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    requestMethod = "GET"
                    setRequestProperty("User-Agent", userAgent)
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

            // Camada 1: Verificação criptográfica do hash SHA-256 contra o release oficial
            val computedSha256 = digest.digest().joinToString("") { "%02x".format(it) }
            if (isFounderCeoBuild && expectedSha256.isNullOrBlank()) {
                partFile.delete()
                throw SecurityException("ERR_OTA_MISSING_SHA256")
            }
            if (!expectedSha256.isNullOrBlank()) {
                val shaRegex = Regex("^[0-9a-f]{64}$")
                if (!shaRegex.matches(expectedSha256.lowercase(Locale.ROOT)) ||
                    !computedSha256.equals(expectedSha256, ignoreCase = true)
                ) {
                    partFile.delete()
                    throw SecurityException("ERR_OTA_SHA256_MISMATCH")
                }
            }

            // Camada 2: Verificação nativa do applicationId e da assinatura digital X.509 do APK
            verifyDownloadedApkSignature(partFile, applicationContext.packageName)

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

    @Suppress("DEPRECATION")
    private fun verifyDownloadedApkSignature(apkFile: File, expectedPackageName: String) {
        val pm = applicationContext.packageManager
        val rawArchiveInfo: PackageInfo? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageArchiveInfo(
                apkFile.absolutePath,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_SIGNING_CERTIFICATES.toLong())
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageArchiveInfo(apkFile.absolutePath, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            pm.getPackageArchiveInfo(apkFile.absolutePath, PackageManager.GET_SIGNATURES)
        }
        val archiveInfo: PackageInfo = rawArchiveInfo
            ?: throw SecurityException("ERR_OTA_INVALID_APK_ARCHIVE")

        if (archiveInfo.packageName != expectedPackageName) {
            throw SecurityException("ERR_OTA_PACKAGE_MISMATCH")
        }

        val archiveSignerDigests = extractSignerCertSha256Set(archiveInfo, apkFile.absolutePath)
        val installedInfo: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(
                expectedPackageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_SIGNING_CERTIFICATES.toLong())
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pm.getPackageInfo(expectedPackageName, PackageManager.GET_SIGNING_CERTIFICATES)
        } else {
            pm.getPackageInfo(expectedPackageName, PackageManager.GET_SIGNATURES)
        }
        val installedSignerDigests = extractSignerCertSha256Set(installedInfo, null)

        if (archiveSignerDigests.isEmpty() ||
            installedSignerDigests.isEmpty() ||
            archiveSignerDigests.intersect(installedSignerDigests).isEmpty()
        ) {
            throw SecurityException("ERR_OTA_SIGNATURE_MISMATCH")
        }
    }

    @Suppress("DEPRECATION")
    private fun extractSignerCertSha256Set(pkgInfo: PackageInfo, archivePathFallback: String?): Set<String> {
        val digests = HashSet<String>()
        fun addSignatures(sigs: Array<Signature>?) {
            sigs?.forEach { sig ->
                val hash = MessageDigest.getInstance("SHA-256")
                    .digest(sig.toByteArray())
                    .joinToString("") { "%02x".format(it) }
                digests.add(hash)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = pkgInfo.signingInfo
            if (signingInfo != null) {
                addSignatures(signingInfo.apkContentsSigners)
                addSignatures(signingInfo.signingCertificateHistory)
            }
        }
        if (digests.isEmpty()) {
            addSignatures(pkgInfo.signatures)
        }
        if (digests.isEmpty() && archivePathFallback != null) {
            val legacyInfo = applicationContext.packageManager.getPackageArchiveInfo(
                archivePathFallback,
                PackageManager.GET_SIGNATURES
            )
            addSignatures(legacyInfo?.signatures)
        }
        return digests
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
        try {
            verifyDownloadedApkSignature(apkFile, applicationContext.packageName)
        } catch (_: SecurityException) {
            runCatching { apkFile.delete() }
            return false
        }
        val authority = "${applicationContext.packageName}.ota.provider"
        val contentUri = Uri.Builder()
            .scheme("content")
            .authority(authority)
            .appendPath(expectedApkFileName)
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
                val otaDir = File(applicationContext.cacheDir, OTA_CACHE_SUBDIR)
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

abstract class BaseVerifiedOtaFileProvider internal constructor(
    private val expectedFileName: String,
    private val requireFounderPackage: Boolean
) : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun resolveVerifiedApk(uri: Uri): File {
        val ctx = context ?: throw FileNotFoundException("Contexto indisponível.")
        val isFounderPkg = ctx.packageName.endsWith(".founder")
        if (requireFounderPackage && !isFounderPkg) {
            throw SecurityException("Provider exclusivo do binário soberano CEO.")
        }
        if (!requireFounderPackage && isFounderPkg) {
            throw SecurityException("Provider exclusivo do aplicativo público Desperrengue.")
        }
        if (uri.lastPathSegment != expectedFileName) {
            throw SecurityException("Artefato não autorizado.")
        }
        val otaDir = File(ctx.cacheDir, OTA_CACHE_SUBDIR).canonicalFile
        val candidate = File(otaDir, expectedFileName).canonicalFile
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
        val apkFile = resolveVerifiedApk(uri)
        val requested = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cols = ArrayList<String>(requested.size)
        val values = ArrayList<Any?>(requested.size)
        for (col in requested) {
            when (col) {
                OpenableColumns.DISPLAY_NAME -> {
                    cols.add(OpenableColumns.DISPLAY_NAME)
                    values.add(expectedFileName)
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
        val apkFile = resolveVerifiedApk(uri)
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

/**
 * Provider isolado no manifesto `src/beta/AndroidManifest.xml`
 * (`br.com.desperrengue.app.ota.provider`, `exported=false`).
 * Entrega somente o binário verificado `cacheDir/ota/desperrengue.apk` ao instalador nativo do Android.
 */
class PublicOtaFileProvider : BaseVerifiedOtaFileProvider(
    expectedFileName = PUBLIC_APK_FILE_NAME,
    requireFounderPackage = false
)

/**
 * Provider isolado exclusivamente no manifesto `src/founder/AndroidManifest.xml`
 * (`br.com.desperrengue.app.founder.ota.provider`, `exported=false`).
 * Entrega somente o binário verificado `cacheDir/ota/desperrengue-founder-ceo.apk`
 * ao PackageInstaller nativo do sistema Android, eliminando qualquer navegador externo.
 */
class FounderOtaFileProvider : BaseVerifiedOtaFileProvider(
    expectedFileName = FOUNDER_APK_FILE_NAME,
    requireFounderPackage = true
)
