import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/parser/edf_header_parser.dart';
import '../../core/parser/edf_signal_reader.dart';
import '../../core/imports/zip_extractor.dart';
import '../../core/imports/imports_catalog.dart';
import '../../core/imports/resmed_datalog_picker.dart';
import '../../core/imports/resmed_sd_scanner.dart';
import '../../core/imports/resmed_night_catalog.dart';
import '../nights/resmed_night_details_screen.dart';
import '../../core/imports/resmed_source_prefs.dart';
import '../../core/imports/resmed_saf_bridge.dart';
import '../charts/simple_line_chart.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen>
    with WidgetsBindingObserver {
  String? _pickedFilePath;

  String? _edfInfoBase;
  String? _seriesInfo;
  bool _isLoadingSeries = false;

  File? _copiedFile;
  EdxEdfHeader? _header;

  EdfSignalSeries? _series;
  String? _seriesError;

  int? _selectedSignalIndex;
  int _windowSeconds = 30;

  List<ImportedEdfSummary> _catalog = [];
  bool _isLoadingCatalog = false;

  List<ResmedNightSummary> _resmedNights = [];
  bool _isLoadingResmedNights = false;

  bool _isAutoSyncing = false;
  String _autoStatus = 'Auto-sync: non configuré';
  DateTime? _lastAutoSync;

  String? _pairedTreeUri;
  String? _autoUserError;
  bool _autoHadError = false;

  Future<void> _refreshPairing() async {
    final uri = await ResmedSourcePrefs.getTreeUri();
    if (!mounted) return;
    setState(() {
      _pairedTreeUri = (uri != null && uri.isNotEmpty) ? uri : null;
    });
  }

  String _humanizeAutoError(Object e) {
    // Par défaut, on reste simple.
    if (e is PlatformException) {
      final code = e.code;
      final msg = (e.message ?? '').toLowerCase();

      if (code == 'canceled') return 'Sélection annulée.';
      if (msg.contains('datalog') &&
          (msg.contains('introuvable') || msg.contains('manquant'))) {
        return 'Dossier ResMed introuvable. Sélectionne la racine de la carte SD ou le dossier DATALOG.';
      }
      if (msg.contains('tree uri') ||
          msg.contains('inaccessible') ||
          msg.contains('permission') ||
          msg.contains('security')) {
        return 'Permission perdue ou carte SD non accessible. Reconnecte la carte SD, sinon appuie sur “Oublier la carte SD”.';
      }
      if (msg.contains('impossible d\'ouvrir') ||
          msg.contains('openinputstream')) {
        return 'Carte SD non détectée. Reconnecte-la puis réessaie.';
      }
      if (code == 'sync_failed') {
        // Fallback propre (au lieu du bruit brut)
        return 'Synchronisation impossible. Vérifie la carte SD (et que ResMed/DATALOG existe).';
      }
    }

    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('datalog')) {
      return 'Dossier ResMed introuvable. Sélectionne la racine de la carte SD ou le dossier DATALOG.';
    }
    return 'Erreur de synchronisation. Reconnecte la carte SD, puis réessaie.';
  }

  Future<void> _forgetSd() async {
    await ResmedSourcePrefs.clear();
    if (!mounted) return;
    setState(() {
      _pairedTreeUri = null;
      _autoHadError = false;
      _autoUserError = null;
      _autoStatus = 'Carte SD: non connectée';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carte SD oubliée. Tu peux reconnecter.')),
    );
  }

  // Navigation dans le temps
  int _startSeconds = 0;
  int _totalSeconds = 0;

  // Date/heure de début EDF (si on arrive à la parser)
  DateTime? _edfStartDateTime;

  // Format fallback mm:ss
  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // EDF typique: dd.MM.yy et HH.mm.ss
  DateTime? _parseEdfStart(String date, String time) {
    final d = date.trim().split('.');
    final t = time.trim().split('.');

    if (d.length < 3 || t.length < 2) return null;

    final day = int.tryParse(d[0]) ?? 1;
    final month = int.tryParse(d[1]) ?? 1;
    final yy = int.tryParse(d[2]) ?? 0;

    final hour = int.tryParse(t[0]) ?? 0;
    final minute = int.tryParse(t[1]) ?? 0;
    final second = t.length >= 3 ? (int.tryParse(t[2]) ?? 0) : 0;

    // règle simple: 00-84 => 2000+, sinon 1900+
    final year = (yy <= 84) ? (2000 + yy) : (1900 + yy);

    return DateTime(year, month, day, hour, minute, second);
  }

  String _fmtClock(DateTime dt, {bool withSeconds = false}) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (!withSeconds) return '$hh:$mm';
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _startLabel(int seconds, {bool withSeconds = false}) {
    final base = _edfStartDateTime;
    if (base == null) return _fmt(seconds);
    return _fmtClock(
      base.add(Duration(seconds: seconds)),
      withSeconds: withSeconds,
    );
  }

  Future<Directory> _getImportsDir() async {
    final appDocs = await getApplicationDocumentsDirectory();
    return Directory('${appDocs.path}/imports');
  }

  Future<void> _loadCatalog({bool setLoadingState = true}) async {
    if (setLoadingState) {
      setState(() => _isLoadingCatalog = true);
    }

    try {
      final dir = await _getImportsDir();
      final list = await ImportsCatalog.scan(dir);

      if (!mounted) return;
      setState(() {
        _catalog = list;
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCatalog = false);
    }
  }

  Future<void> _loadResmedNights({bool setLoadingState = true}) async {
    if (setLoadingState) {
      setState(() => _isLoadingResmedNights = true);
    }

    try {
      final dir = await _getImportsDir();
      final nights = await ResmedNightCatalog.scan(dir);

      if (!mounted) return;
      setState(() {
        _resmedNights = nights;
        _isLoadingResmedNights = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingResmedNights = false);
    }
  }

  /// Fonction unique qui:
  /// - parse l'entête EDF
  /// - calcule la durée totale
  /// - setState
  /// - reload la série + refresh catalog + refresh sessions ResMed
  Future<void> _loadEdfFile(File edfFile, {String? pickedInfoExtra}) async {
    final header = await EdfHeaderParser.parseHeader(edfFile);
    final selectedIdx = EdfSignalReader.findSignalIndex(header);
    final edfStart = _parseEdfStart(header.startDate, header.startTime);

    final labelsPreview = header.signalLabels.take(6).join(', ');
    String edfInfo =
        'EDF: ${header.numSignals} signaux | Début: ${header.startDate} ${header.startTime}\n'
        'Labels: $labelsPreview${header.signalLabels.length > 6 ? ', …' : ''}';

    if (pickedInfoExtra != null && pickedInfoExtra.trim().isNotEmpty) {
      edfInfo = '$edfInfo\n$pickedInfoExtra';
    }

    final bytesPerRecord =
        header.signals.fold<int>(0, (sum, s) => sum + s.samplesPerRecord) * 2;

    final fileLen = await edfFile.length();
    final dataBytes = fileLen - header.headerBytes;
    final computedRecords = dataBytes > 0 ? (dataBytes ~/ bytesPerRecord) : 0;

    final totalRecords = header.numRecords > 0
        ? min(header.numRecords, computedRecords)
        : computedRecords;

    final totalSeconds = (totalRecords * header.recordDurationSeconds).floor();

    if (!mounted) return;

    setState(() {
      _copiedFile = edfFile;
      _pickedFilePath = edfFile.path;

      _header = header;
      _edfInfoBase = edfInfo;

      _selectedSignalIndex = selectedIdx;

      _windowSeconds = 30;
      _totalSeconds = totalSeconds;
      _startSeconds = 0;

      _edfStartDateTime = edfStart;

      _series = null;
      _seriesError = null;
      _seriesInfo = null;
      _isLoadingSeries = false;
    });

    final fileName = edfFile.uri.pathSegments.isNotEmpty
        ? edfFile.uri.pathSegments.last
        : edfFile.path.split(Platform.pathSeparator).last;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Prêt: $fileName')));

    await _reloadSeries();
    await _loadCatalog();
    await _loadResmedNights(setLoadingState: false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );

    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final sourcePath = picked.path;

    final ext = (picked.extension ?? '').toLowerCase();
    if (ext != 'zip' && ext != 'edf') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis un fichier .zip ou .edf')),
      );
      return;
    }

    if (sourcePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chemin du fichier indisponible.')),
      );
      return;
    }

    try {
      final importsDir = await _getImportsDir();
      if (!await importsDir.exists()) {
        await importsDir.create(recursive: true);
      }

      // Copie le fichier choisi (edf ou zip) dans imports/
      final destPath = '${importsDir.path}/${picked.name}';
      final copiedFile = await File(sourcePath).copy(destPath);

      // Déterminer quel EDF analyser
      File? edfFileCandidate;
      String? pickedInfoExtra;

      if (ext == 'edf') {
        edfFileCandidate = copiedFile;
      } else {
        // ZIP
        final baseName = picked.name.toLowerCase().endsWith('.zip')
            ? picked.name.substring(0, picked.name.length - 4)
            : picked.name;

        final outDir = Directory('${importsDir.path}/$baseName');

        final res = await ZipExtractor.extractZipToDir(
          zipFile: copiedFile,
          outputDir: outDir,
        );

        if (res.edfFiles.isEmpty) {
          throw Exception('ZIP extrait, mais aucun .edf trouvé.');
        }

        final pick = await ResmedDatalogPicker.pickBestEdf(res.edfFiles);
        final chosenEdf = pick.file;
        edfFileCandidate = chosenEdf;

        final chosenName = chosenEdf.uri.pathSegments.isNotEmpty
            ? chosenEdf.uri.pathSegments.last
            : chosenEdf.path.split('/').last;

        pickedInfoExtra =
            'ZIP extrait: ${res.extractedFiles} fichiers, ${res.edfFiles.length} EDF\n'
            'EDF choisi: $chosenName\n'
            '${pick.reason}';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pick.sessionsDetected > 0
                  ? 'ResMed: ${pick.sessionsDetected} session(s), EDF=$chosenName'
                  : 'ZIP: EDF=$chosenName',
            ),
          ),
        );
      }

      if (edfFileCandidate == null) {
        throw Exception('Impossible de déterminer un fichier EDF à analyser.');
      }

      await _loadEdfFile(edfFileCandidate, pickedInfoExtra: pickedInfoExtra);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur import: $e')));
    }
  }

  Future<void> _pickResmedFolder() async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) return;

      final pick = await ResmedSdScanner.scanAndPickBest(dirPath);

      final importsDir = await _getImportsDir();
      if (!await importsDir.exists()) {
        await importsDir.create(recursive: true);
      }

      final sessionKey = pick.sessionKey ?? 'unknown_session';
      final sessionDir = Directory(
        '${importsDir.path}${Platform.pathSeparator}resmed${Platform.pathSeparator}$sessionKey',
      );
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }

      // Copie TOUS les EDF de la session (pas juste le meilleur)
      String baseName(String p) => p.split(Platform.pathSeparator).last;

      final copiedByName = <String, File>{};
      for (final sf in pick.sessionFiles) {
        final name = baseName(sf.file.path);
        final destPath = '${sessionDir.path}${Platform.pathSeparator}$name';
        final copied = await sf.file.copy(destPath);
        copiedByName[name] = copied;
      }

      // Choisir le "meilleur" EDF copié localement (même nom que pick.file)
      final bestName = baseName(pick.file.path);
      final bestLocal = copiedByName[bestName] ?? copiedByName.values.first;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ResMed: session $sessionKey • ${pick.sessionFiles.length} EDF copiés',
          ),
        ),
      );

      final extra =
          'Import ResMed (dossier)\n'
          'Session: $sessionKey\n'
          'Types: ${pick.availableTypes.join(", ")}\n'
          'Copié: ${pick.sessionFiles.length} EDF → ${sessionDir.path}\n'
          'Choix: $bestName\n'
          '${pick.reason}';

      await _loadEdfFile(bestLocal, pickedInfoExtra: extra);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import dossier échoué: $e')));
    }
  }

  Future<void> _pairSd() async {
    try {
      final uri = await ResmedSafBridge.pickTree();
      if (uri == null || uri.isEmpty) return;
      await ResmedSourcePrefs.setTreeUri(uri);
      if (!mounted) return;
      setState(() {
        _autoStatus = 'Carte SD: autorisée';
        _autoHadError = false;
        _autoUserError = null;
      });
      await _refreshPairing();
      await _tryAutoSync();
    } catch (e) {
      if (!mounted) return;
      final msg = _humanizeAutoError(e);
      setState(() {
        _autoStatus = 'Carte SD: problème';
        _autoHadError = true;
        _autoUserError = msg;
      });
    }
  }

  Future<void> _tryAutoSync() async {
    if (_isAutoSyncing) return;

    final treeUri = await ResmedSourcePrefs.getTreeUri();
    if (treeUri == null || treeUri.isEmpty) {
      if (!mounted) return;
      setState(() {
        _autoStatus = 'Carte SD: non connectée';
        _autoHadError = false;
        _autoUserError = null;
      });
      await _refreshPairing();
      return;
    }

    setState(() {
      _isAutoSyncing = true;
      _autoStatus = 'Synchronisation: en cours…';
      _autoHadError = false;
      _autoUserError = null;
    });

    try {
      final importsDir = await _getImportsDir();
      if (!await importsDir.exists()) {
        await importsDir.create(recursive: true);
      }

      final res = await ResmedSafBridge.syncLatest(
        treeUri: treeUri,
        destBasePath: importsDir.path,
      );

      final bestPath = (res['bestEdfPath'] as String?) ?? '';
      final sessionKey = (res['sessionKey'] as String?) ?? 'unknown';
      final copiedCount = (res['copiedCount'] as int?) ?? 0;

      if (bestPath.isEmpty) throw Exception('bestEdfPath vide');

      if (!mounted) return;
      setState(() {
        _lastAutoSync = DateTime.now();
        _autoStatus = 'Synchronisation: OK • $copiedCount fichier(s)';
        _isAutoSyncing = false;
        _autoHadError = false;
        _autoUserError = null;
      });

      final extra =
          'Auto-sync SD\nSession: $sessionKey\nCopié: $copiedCount fichier(s)\nSource: SAF';
      await _loadEdfFile(File(bestPath), pickedInfoExtra: extra);
    } catch (e) {
      if (!mounted) return;
      final msg = _humanizeAutoError(e);
      setState(() {
        _autoStatus = 'Synchronisation: échec';
        _isAutoSyncing = false;
        _autoHadError = true;
        _autoUserError = msg;
      });
    }
  }

  Future<void> _reloadSeries() async {
    final file = _copiedFile;
    final header = _header;
    final idx = _selectedSignalIndex;

    if (file == null || header == null || idx == null) return;

    final maxStart = max(0, _totalSeconds - _windowSeconds);
    final clampedStart = _startSeconds.clamp(0, maxStart);
    if (clampedStart != _startSeconds) {
      _startSeconds = clampedStart;
    }

    setState(() {
      _isLoadingSeries = true;
      _series = null;
      _seriesError = null;
      _seriesInfo = 'Chargement de la série…';
    });

    try {
      final series = await EdfSignalReader.readSignalSeries(
        file: file,
        header: header,
        signalIndex: idx,
        startSeconds: _startSeconds,
        windowSeconds: _windowSeconds,
        maxPoints: 3000,
      );

      if (!mounted) return;

      setState(() {
        _isLoadingSeries = false;
        _series = series;
        _seriesError = null;

        final sr = series.sampleRateHz;

        final withSeconds = _windowSeconds <= 30;
        final startLabel = _startLabel(_startSeconds, withSeconds: withSeconds);
        final endSeconds = min(_totalSeconds, _startSeconds + _windowSeconds);
        final endLabel = _startLabel(endSeconds, withSeconds: withSeconds);

        _seriesInfo =
            'Série: ${series.label} | ${sr.toStringAsFixed(1)} Hz | ${series.points.length} pts'
            ' | $startLabel → $endLabel';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSeries = false;
        _series = null;
        _seriesError = 'Série: impossible à lire ($e)';
        _seriesInfo = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isLoadingCatalog = true;
    _isLoadingResmedNights = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPairing();
      _loadCatalog(setLoadingState: false);
      _loadResmedNights(setLoadingState: false);
      _tryAutoSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _header;

    final windowStart = _edfStartDateTime?.add(
      Duration(seconds: _startSeconds),
    );
    final windowEnd = windowStart?.add(Duration(seconds: _windowSeconds));

    return Scaffold(
      appBar: AppBar(title: const Text('Importer')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sd_card, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Import v0.2.4 (début + fenêtre)',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'On copie localement, on lit l’entête EDF, puis on extrait une fenêtre d’un signal.\n'
                  'Tu peux te déplacer dans la nuit avec “Début”.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Carte SD',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(_autoStatus),
                        if (_lastAutoSync != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Dernière synchro: ${_fmtClock(_lastAutoSync!)}',
                          ),
                        ],
                        if (_autoHadError && _autoUserError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _autoUserError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Astuce: quand Android te demande un dossier, choisis la racine de la carte SD ou “DATALOG”.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),

                        // MODE SIMPLE
                        if (_pairedTreeUri == null) ...[
                          FilledButton.icon(
                            onPressed: _isAutoSyncing ? null : _pairSd,
                            icon: const Icon(Icons.link),
                            label: const Text('Connecter la carte SD'),
                          ),
                        ] else ...[
                          FilledButton.icon(
                            onPressed: _isAutoSyncing ? null : _tryAutoSync,
                            icon: const Icon(Icons.sync),
                            label: const Text('Synchroniser'),
                          ),
                        ],

                        if (_isAutoSyncing) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],

                        if (_pairedTreeUri != null && _autoHadError) ...[
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _forgetSd,
                            icon: const Icon(Icons.link_off),
                            label: const Text('Oublier la carte SD'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Options avancées'),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    FilledButton(
                      onPressed: _pickFile,
                      child: const Text('Choisir un fichier (.edf/.zip)'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickResmedFolder,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Importer dossier ResMed'),
                    ),
                    const SizedBox(height: 10),
                    if (_pairedTreeUri != null)
                      OutlinedButton.icon(
                        onPressed: _pairSd,
                        icon: const Icon(Icons.link),
                        label: const Text(
                          'Changer de dossier SD (reconnecter)',
                        ),
                      ),
                    if (_pairedTreeUri != null)
                      TextButton.icon(
                        onPressed: _forgetSd,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Oublier la carte SD'),
                      ),
                  ],
                ),

                if (_pickedFilePath != null)
                  Text(
                    'Fichier: $_pickedFilePath',
                    textAlign: TextAlign.center,
                  ),

                if (_edfInfoBase != null) ...[
                  const SizedBox(height: 8),
                  Text(_edfInfoBase!, textAlign: TextAlign.center),
                ],

                if (windowStart != null && windowEnd != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Fenêtre: ${_fmtClock(windowStart, withSeconds: _windowSeconds <= 30)}'
                    ' → ${_fmtClock(windowEnd, withSeconds: _windowSeconds <= 30)}',
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_seriesInfo != null) ...[
                  const SizedBox(height: 8),
                  Text(_seriesInfo!, textAlign: TextAlign.center),
                ],

                if (_isLoadingSeries) ...[
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(),
                ],

                if (header != null) ...[
                  const SizedBox(height: 16),

                  // Signal
                  DropdownButtonFormField<int>(
                    value: _selectedSignalIndex,
                    decoration: const InputDecoration(
                      labelText: 'Signal',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(header.numSignals, (i) {
                      final s = header.signals[i];
                      final unit = s.physicalDimension.trim().isEmpty
                          ? '—'
                          : s.physicalDimension.trim();
                      return DropdownMenuItem(
                        value: i,
                        child: Text('${s.label} ($unit)'),
                      );
                    }),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedSignalIndex = value);
                      await _reloadSeries();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Fenêtre
                  DropdownButtonFormField<int>(
                    value: _windowSeconds,
                    decoration: const InputDecoration(
                      labelText: 'Fenêtre',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30 secondes')),
                      DropdownMenuItem(value: 120, child: Text('2 minutes')),
                      DropdownMenuItem(value: 300, child: Text('5 minutes')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _windowSeconds = value);
                      await _reloadSeries();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Slider "Début"
                  Builder(
                    builder: (context) {
                      final maxStart = max(0, _totalSeconds - _windowSeconds);
                      final step = 60;
                      final snapped = (_startSeconds ~/ step) * step;
                      final current = snapped.clamp(0, maxStart);

                      final divisions = maxStart == 0
                          ? 1
                          : max(1, (maxStart / step).round());

                      final labelStart = (_edfStartDateTime == null)
                          ? _fmt(current)
                          : _fmtClock(
                              _edfStartDateTime!.add(
                                Duration(seconds: current),
                              ),
                            );

                      final labelTotal = (_edfStartDateTime == null)
                          ? _fmt(_totalSeconds)
                          : _fmtClock(
                              _edfStartDateTime!.add(
                                Duration(seconds: _totalSeconds),
                              ),
                            );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Début: $labelStart / $labelTotal',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Slider(
                            value: current.toDouble(),
                            min: 0,
                            max: maxStart.toDouble(),
                            divisions: divisions,
                            label: labelStart,
                            onChanged: maxStart == 0
                                ? null
                                : (v) {
                                    setState(() {
                                      _startSeconds =
                                          ((v / step).round() * step).toInt();
                                    });
                                  },
                            onChangeEnd: maxStart == 0
                                ? null
                                : (_) async {
                                    await _reloadSeries();
                                  },
                          ),
                        ],
                      );
                    },
                  ),
                ],

                if (_seriesError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _seriesError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                // -------------------------
                // Sessions ResMed (nouveau)
                // -------------------------
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Nuits ResMed', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      onPressed: _isLoadingResmedNights ? null : () => _loadResmedNights(),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Rafraîchir',
                    ),
                  ],
                ),

                if (_isLoadingResmedNights) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],

                if (_resmedNights.isEmpty && !_isLoadingResmedNights) ...[
                  const SizedBox(height: 8),
                  const Text('Aucune nuit ResMed détectée dans imports/.'),
                ],

                if (_resmedNights.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _resmedNights.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = _resmedNights[i];
                      final date = _fmtDate(n.nightDate);
                      final start = _fmtClock(n.start);
                      final end = _fmtClock(n.end);

                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.nightlight_round),
                        title: Text('$date • ${n.segmentsCount} segment(s)'),
                        subtitle: Text('Fenêtre: $start → $end'),
                        onTap: () async {
                          try {
                            final file = await Navigator.push<File?>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResmedNightDetailsScreen(night: n),
                              ),
                            );

                            if (file == null) return;

                            final extra =
                                'Nuit ResMed: $date\nSegments: ${n.segmentsCount}\nSource: imports/resmed';
                            await _loadEdfFile(file, pickedInfoExtra: extra);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Impossible d’ouvrir la nuit: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],

                // -------------------------
                // Imports trouvés (existant)
                // -------------------------
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Imports trouvés',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      onPressed: _isLoadingCatalog
                          ? null
                          : () => _loadCatalog(),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Rafraîchir',
                    ),
                  ],
                ),

                if (_isLoadingCatalog) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],

                if (_catalog.isEmpty && !_isLoadingCatalog) ...[
                  const SizedBox(height: 8),
                  const Text('Aucun EDF trouvé dans imports/.'),
                ],

                if (_catalog.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _catalog.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = _catalog[i];
                      final when = item.start != null
                          ? _fmtClock(item.start!)
                          : 'date inconnue';
                      final durMin = (item.totalSeconds / 60).floor();

                      return ListTile(
                        dense: true,
                        title: Text(item.fileName),
                        subtitle: Text(
                          '$when • ${durMin} min • ${item.numSignals} signaux',
                        ),
                        onTap: () async {
                          try {
                            await _loadEdfFile(item.file);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Impossible de charger cet EDF: $e',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],

                if (_series != null) ...[
                  const SizedBox(height: 16),
                  SimpleLineChart(
                    title: _series!.label,
                    unit: _series!.unit,
                    points: _series!.points,
                    xOrigin: windowStart,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
