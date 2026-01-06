package com.example.cpaporama

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Calendar
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
        val name: String,        // filename
        val nightKey: String     // YYYYMMDD (frontière midi)
    )

    // OSCAR-like: tout ce qui est avant midi appartient à la "nuit" de la veille.
    private fun nightKeyFrom(ymd: String, hms: String): String {
        val y = ymd.substring(0, 4).toInt()
        val m = ymd.substring(4, 6).toInt()
        val d = ymd.substring(6, 8).toInt()
        val hh = hms.substring(0, 2).toInt()
        val mm = hms.substring(2, 4).toInt()
        val ss = hms.substring(4, 6).toInt()

        val cal = Calendar.getInstance()
        cal.set(y, m - 1, d, hh, mm, ss)
        if (hh < 12) cal.add(Calendar.DATE, -1)

        return String.format(
            Locale.US,
            "%04d%02d%02d",
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH)
        )
    }

    private fun syncResmedLatest(treeUriStr: String, destBasePath: String, result: MethodChannel.Result) {
        Thread {
            try {
                val treeUri = Uri.parse(treeUriStr)

                val root = DocumentFile.fromTreeUri(this, treeUri)
                    ?: throw IllegalStateException("Tree URI invalide / inaccessible.")

                // SD absente / pas montée: listFiles souvent vide.
                val rootFiles = safeListFiles(root)
                if (rootFiles.isEmpty()) {
                    throw IllegalStateException("Carte SD non détectée. Reconnecte-la.")
                }

                val datalog = findDatalogDir(root)
                    ?: throw IllegalStateException("DATALOG introuvable (sélectionne la racine SD ou DATALOG).")

                val entries = collectEdfs(datalog)
                if (entries.isEmpty()) throw IllegalStateException("Aucun EDF trouvé dans DATALOG.")

                // 1) Repère la session la plus récente
                val newest = entries.maxByOrNull { it.startKey }!!

                // 2) On synchronise la "nuit" associée (frontière midi)
                val nightKey = newest.nightKey
                val nightEntries = entries.filter { it.nightKey == nightKey }
                if (nightEntries.isEmpty()) throw IllegalStateException("Aucun EDF pour la nuit $nightKey.")

                // 3) Choisir le meilleur EDF à ouvrir: type prioritaire, puis le plus gros fichier
                val priority = listOf("PLD", "BRP", "SA2", "SAD", "CSL", "EVE", "STR")
                val bestType = priority.firstOrNull { t -> nightEntries.any { it.type == t } }
                val candidates = if (bestType != null) nightEntries.filter { it.type == bestType } else nightEntries
                val chosen = candidates.maxByOrNull { it.doc.length() } ?: newest

                var copied = 0
                var bestLocalPath: String? = null
                val touchedSessions = HashSet<String>()

                // 4) Copie tous les EDF de la nuit dans /imports/resmed/<sessionKey>/
                for (e in nightEntries) {
                    val sessionDir = File(destBasePath, "resmed/${e.sessionKey}")
                    if (!sessionDir.exists()) sessionDir.mkdirs()

                    val destFile = File(sessionDir, e.name)
                    copyDocToFile(e.doc.uri, destFile)

                    copied++
                    touchedSessions.add(e.sessionKey)

                    if (e.sessionKey == chosen.sessionKey && e.name == chosen.name) {
                        bestLocalPath = destFile.absolutePath
                    }
                }

                val payload = hashMapOf<String, Any?>(
                    "bestEdfPath" to (bestLocalPath ?: ""),
                    "sessionKey" to "night_$nightKey",
                    "copiedCount" to copied,
                    "nightKey" to nightKey,
                    "sessionsCount" to touchedSessions.size,
                    "newestSessionKey" to newest.sessionKey
                )

                runOnUiThread { result.success(payload) }
            } catch (t: Throwable) {
                Log.e("CPAPorama", "syncResmedLatest error", t)

                val (code, msg) = mapError(t)
                runOnUiThread { result.error(code, msg, null) }
            }
        }.start()
    }

    private fun mapError(t: Throwable): Pair<String, String> {
        // Codes stables côté Flutter
        val msg = t.message ?: "Erreur inconnue"

        // SecurityException / permissions
        if (t is SecurityException) {
            return "permission_lost" to "Permission perdue. Reconnecte la carte SD (ou reconnecte via Connecter)."
        }

        val low = msg.lowercase(Locale.US)
        return when {
            low.contains("carte sd non détectée") || low.contains("non détectée") ->
                "sd_missing" to "Carte SD non détectée. Reconnecte-la."

            low.contains("datalog introuvable") || low.contains("datalog") && low.contains("introuvable") ->
                "datalog_missing" to "Dossier ResMed introuvable. Sélectionne la racine SD ou le dossier DATALOG."

            low.contains("tree uri invalide") || low.contains("inaccessible") || low.contains("permission") ->
                "permission_lost" to "Permission perdue ou dossier inaccessible. Reconnecte la carte SD."

            else ->
                "sync_failed" to msg
        }
    }

    private fun findDatalogDir(root: DocumentFile): DocumentFile? {
        if (root.isDirectory && root.name?.equals("DATALOG", ignoreCase = true) == true) return root
        return safeListFiles(root).firstOrNull {
            it.isDirectory && it.name?.equals("DATALOG", ignoreCase = true) == true
        }
    }

    private fun collectEdfs(datalog: DocumentFile): List<Entry> {
        val out = ArrayList<Entry>()
        val stack = ArrayDeque<DocumentFile>()
        stack.add(datalog)

        val rx = Regex("""^(\d{8})_(\d{6})_([A-Za-z0-9]{3})\.edf$""")

        while (stack.isNotEmpty()) {
            val dir = stack.removeFirst()
            for (child in safeListFiles(dir)) {
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
                val nightKey = nightKeyFrom(ymd, hms)

                out.add(Entry(child, sessionKey, startKey, type, name, nightKey))
            }
        }
        return out
    }

    private fun safeListFiles(dir: DocumentFile): Array<DocumentFile> {
        return try {
            dir.listFiles()
        } catch (t: Throwable) {
            emptyArray()
        }
    }

    private fun copyDocToFile(uri: Uri, destFile: File) {
        destFile.parentFile?.mkdirs()

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