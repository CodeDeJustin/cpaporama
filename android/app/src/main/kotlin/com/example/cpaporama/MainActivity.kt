package com.example.cpaporama

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val CHANNEL = "cpaporama/saf"
    private val REQ_OPEN_TREE = 41001
    private var pendingPickTreeResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickTree" -> {
                        if (pendingPickTreeResult != null) {
                            result.error("busy", "Une sélection de dossier est déjà en cours.", null)
                            return@setMethodCallHandler
                        }
                        pendingPickTreeResult = result
                        launchTreePicker()
                    }

                    "syncResmedLatest" -> {
                        val treeUriStr = call.argument<String>("treeUri")
                        val destBasePath = call.argument<String>("destBasePath")
                        if (treeUriStr.isNullOrBlank() || destBasePath.isNullOrBlank()) {
                            result.error("bad_args", "treeUri/destBasePath manquant.", null)
                            return@setMethodCallHandler
                        }
                        syncResmedLatest(treeUriStr, destBasePath, result)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun launchTreePicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        startActivityForResult(intent, REQ_OPEN_TREE)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_OPEN_TREE) return

        val res = pendingPickTreeResult
        pendingPickTreeResult = null
        if (res == null) return

        if (resultCode != Activity.RESULT_OK) {
            res.error("canceled", "Sélection annulée.", null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            res.error("no_uri", "Aucun URI retourné par le sélecteur.", null)
            return
        }

        try {
            val flags = data.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags)
        } catch (t: Throwable) {
            Log.w("CPAPorama", "takePersistableUriPermission failed: ${t.message}", t)
            // Certaines ROM sont capricieuses. On continue.
        }

        res.success(uri.toString())
    }

    private data class Entry(
        val doc: DocumentFile,
        val sessionKey: String,  // YYYYMMDD_HHMMSS
        val startKey: Long,      // yyyymmddhhmmss (numérique)
        val type: String,        // PLD/BRP/...
        val name: String
    )

    private fun syncResmedLatest(treeUriStr: String, destBasePath: String, result: MethodChannel.Result) {
        Thread {
            try {
                val treeUri = Uri.parse(treeUriStr)
                val root = DocumentFile.fromTreeUri(this, treeUri)
                    ?: throw IllegalStateException("Tree URI invalide / inaccessible.")

                val datalog = findDatalogDir(root)
                    ?: throw IllegalStateException("DATALOG introuvable (sélectionne la racine SD ou DATALOG).")

                val entries = collectEdfs(datalog)
                if (entries.isEmpty()) throw IllegalStateException("Aucun EDF trouvé dans DATALOG.")

                val newest = entries.maxBy { it.startKey }
                val sessionKey = newest.sessionKey
                val sessionEntries = entries.filter { it.sessionKey == sessionKey }

                val sessionDir = File(destBasePath, "resmed/$sessionKey")
                sessionDir.mkdirs()

                val priority = listOf("PLD", "BRP", "SA2", "SAD", "CSL", "EVE", "STR")
                val bestType = priority.firstOrNull { t -> sessionEntries.any { it.type == t } }
                val chosen = if (bestType != null) sessionEntries.first { it.type == bestType } else sessionEntries.first()

                var copied = 0
                var bestLocalPath: String? = null

                for (e in sessionEntries) {
                    val destFile = File(sessionDir, e.name)
                    copyDocToFile(e.doc.uri, destFile)
                    copied++
                    if (e.name == chosen.name) bestLocalPath = destFile.absolutePath
                }

                val payload = hashMapOf<String, Any?>(
                    "bestEdfPath" to (bestLocalPath ?: ""),
                    "sessionKey" to sessionKey,
                    "copiedCount" to copied
                )

                runOnUiThread { result.success(payload) }
            } catch (t: Throwable) {
                Log.e("CPAPorama", "syncResmedLatest error", t)
                runOnUiThread { result.error("sync_failed", t.message ?: "Erreur inconnue", null) }
            }
        }.start()
    }

    private fun findDatalogDir(root: DocumentFile): DocumentFile? {
        if (root.isDirectory && root.name?.equals("DATALOG", ignoreCase = true) == true) return root
        return root.listFiles().firstOrNull { it.isDirectory && it.name?.equals("DATALOG", ignoreCase = true) == true }
    }

    private fun collectEdfs(datalog: DocumentFile): List<Entry> {
        val out = ArrayList<Entry>()
        val stack = ArrayDeque<DocumentFile>()
        stack.add(datalog)

        val rx = Regex("""^(\d{8})_(\d{6})_([A-Za-z0-9]{3})\.edf$""")

        while (stack.isNotEmpty()) {
            val dir = stack.removeFirst()
            for (child in dir.listFiles()) {
                if (child.isDirectory) {
                    stack.add(child)
                    continue
                }
                val name = child.name ?: continue
                val m = rx.matchEntire(name) ?: continue

                val ymd = m.groupValues[1]
                val hms = m.groupValues[2]
                val type = m.groupValues[3].uppercase(Locale.US)
                val sessionKey = "${ymd}_${hms}"
                val startKey = (ymd + hms).toLongOrNull() ?: 0L

                out.add(Entry(child, sessionKey, startKey, type, name))
            }
        }
        return out
    }

    private fun copyDocToFile(uri: Uri, destFile: File) {
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("Impossible d'ouvrir: $uri")
            FileOutputStream(destFile).use { output ->
                val buf = ByteArray(64 * 1024)
                while (true) {
                    val r = input.read(buf)
                    if (r <= 0) break
                    output.write(buf, 0, r)
                }
                output.flush()
            }
        }
    }
}

//package com.example.cpaporama
//
//import io.flutter.embedding.android.FlutterActivity
//
//class MainActivity : FlutterActivity()
