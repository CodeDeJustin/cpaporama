import 'dart:io';

import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/imports/resmed_saf_bridge.dart';
import '../../core/imports/resmed_source_prefs.dart';
import '../../core/nights/night_repository.dart';
import '../../core/storage/app_db_provider.dart';
import '../imports/import_screen.dart';
import '../nights/night_viewer_screen.dart';
import '../stats/stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Repo (DB index)
  final NightRepository _repo = NightRepository(appDb);

  // UI filter (source de vérité)
  DateTimeRange? _range; // mode "plage"
  int? _latestN; // mode "dernières N" (null = pas de limite)

  // Nights (from DB index)
  List<NightListItem> _nights = [];
  bool _loadingNights = false;

  // Auto-sync (SAF)
  bool _isAutoSyncing = false;
  String _autoStatus = 'Carte SD: non connectée';
  DateTime? _lastAutoSync;
  DateTime? _lastAutoSyncAttempt;

  String? _pairedTreeUri;
  String? _autoUserError;
  bool _autoHadError = false;

  String? _lastAutoOpenedSessionKey;

  // Diagnostics (optionnel mais utile)
  int? _lastCopiedCount;
  int? _lastSkippedCount;
  String? _lastSyncKind; // 'latest' | 'lastN' | 'range' (si tu ajoutes range)

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _filterText() {
    if (_range != null) {
      return 'Plage: ${_fmtDate(_range!.start)} → ${_fmtDate(_range!.end)}';
    }
    if (_latestN != null) {
      return 'Dernières: $_latestN nuits';
    }
    return 'Plage: toutes';
  }

  bool get _hasActiveFilter => _range != null || _latestN != null;

  Future<Directory> _getImportsDir() async {
    final appDocs = await getApplicationDocumentsDirectory();
    return Directory('${appDocs.path}/imports');
  }

  Future<void> _refreshPairing() async {
    final uri = await ResmedSourcePrefs.getTreeUri();
    if (!mounted) return;
    setState(() {
      _pairedTreeUri = (uri != null && uri.isNotEmpty) ? uri : null;
      _autoStatus = (_pairedTreeUri == null) ? 'Carte SD: non connectée' : 'Carte SD: autorisée';
    });
  }

  String _humanizeAutoError(Object e) {
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
        return 'Permission perdue ou carte SD non accessible. Reconnecte la carte SD, sinon utilise “Oublier la carte SD”.';
      }
      if (msg.contains('impossible d\'ouvrir') || msg.contains('openinputstream')) {
        return 'Carte SD non détectée. Reconnecte-la puis réessaie.';
      }
      if (code == 'sync_failed') {
        return 'Synchronisation impossible. Vérifie la carte SD (et que ResMed/DATALOG existe).';
      }
    }

    final lower = e.toString().toLowerCase();
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
      _lastAutoOpenedSessionKey = null;
      _lastAutoSync = null;
      _lastAutoSyncAttempt = null;
      _lastCopiedCount = null;
      _lastSkippedCount = null;
      _lastSyncKind = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carte SD oubliée. Tu peux reconnecter.')),
    );
  }

  Future<void> _loadNights({bool setLoadingState = true}) async {
    if (setLoadingState) {
      setState(() {
        _loadingNights = true;
        _nights = []; // évite l’ancienne liste qui "reste longue"
      });
    }

    try {
      await _repo.ensureIndexBuilt();

      final r = _range;
      final limit = (r == null) ? _latestN : null;

      final nights = await _repo.listNights(
        from: r?.start,
        to: r?.end,
        limit: limit,
      );

      if (!mounted) return;
      setState(() {
        _nights = nights;
        _loadingNights = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNights = false);
    }
  }

  Future<void> _openNightViewerByKey(String nightKey) async {
    final night = await _repo.getNight(nightKey);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NightViewerScreen(night: night)),
    );
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
      await _tryAutoSync(force: true);
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

  Future<void> _tryAutoSync({bool force = false}) async {
    if (_isAutoSyncing) return;

    // Garde: auto-sync seulement si HomeScreen est la route courante.
    if (!force) {
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (!isCurrent) return;
    }

    // Anti-spam (auto)
    final now = DateTime.now();
    if (!force &&
        _lastAutoSyncAttempt != null &&
        now.difference(_lastAutoSyncAttempt!).inSeconds < 60) {
      return;
    }
    _lastAutoSyncAttempt = now;

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

    if (!mounted) return;
    setState(() {
      _isAutoSyncing = true;
      _autoStatus = 'Synchronisation: en cours…';
      _autoHadError = false;
      _autoUserError = null;
      _lastSyncKind = 'latest';
    });

    try {
      final importsDir = await _getImportsDir();
      if (!await importsDir.exists()) await importsDir.create(recursive: true);

      final res = await ResmedSafBridge.syncLatest(
        treeUri: treeUri,
        destBasePath: importsDir.path,
      );

      final nightKeys = ((res['nightKeys'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((k) => k.length == 8)
          .toList();

      // ✅ v0.2.9: upsert ciblé (fallback rebuild si rien n’est retourné)
      if (nightKeys.isNotEmpty) {
        await _repo.upsertIndexForNightKeys(nightKeys);
      } else {
        await _repo.rebuildIndexFromImports();
      }

      final sessionKey = (res['sessionKey'] as String?) ?? '';
      final nightKey = (res['nightKey'] as String?) ?? '';
      final copiedCount = (res['copiedCount'] as int?) ?? 0;
      final skippedCount = (res['skippedCount'] as int?) ?? 0;

      _lastCopiedCount = copiedCount;
      _lastSkippedCount = skippedCount;

      await _loadNights(setLoadingState: false);

      if (!mounted) return;
      setState(() {
        _lastAutoSync = DateTime.now();
        _autoStatus = (copiedCount > 0)
            ? 'Synchronisation: OK • $copiedCount copié(s), $skippedCount déjà présents'
            : 'Synchronisation: OK • déjà à jour';
        _isAutoSyncing = false;
        _autoHadError = false;
        _autoUserError = null;
      });

      // Auto-open (une fois par sessionKey)
      if (sessionKey.isEmpty) return;
      if (sessionKey == _lastAutoOpenedSessionKey) return;
      _lastAutoOpenedSessionKey = sessionKey;

      // Choix de la nuit à ouvrir
      String? targetNightKey;
      if (nightKey.length == 8) {
        targetNightKey = nightKey;
      } else if (_nights.isNotEmpty) {
        targetNightKey = _nights.first.nightKey;
      }

      if (targetNightKey == null || targetNightKey.isEmpty) return;

      final canNavigate = ModalRoute.of(context)?.isCurrent ?? true;
      if (canNavigate) {
        // ignore: unawaited_futures
        _openNightViewerByKey(targetNightKey);
      }
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

  Future<void> _syncLastN(int n) async {
    final treeUri = await ResmedSourcePrefs.getTreeUri();
    if (treeUri == null || treeUri.isEmpty) return;

    if (!mounted) return;
    setState(() {
      // Filtre = source de vérité: applique "Dernières N" tout de suite
      _latestN = n;
      _range = null;

      // UI propre
      _nights = [];
      _loadingNights = true;

      _isAutoSyncing = true;
      _autoStatus = 'Synchronisation historique: en cours…';
      _autoHadError = false;
      _autoUserError = null;
      _lastSyncKind = 'lastN';
    });

    try {
      final importsDir = await _getImportsDir();
      if (!await importsDir.exists()) await importsDir.create(recursive: true);

      final res = await ResmedSafBridge.syncLastN(
        treeUri: treeUri,
        destBasePath: importsDir.path,
        n: n,
      );

      final nightKeys = ((res['nightKeys'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((k) => k.length == 8)
          .toList();

      // ✅ v0.2.9: upsert ciblé (fallback rebuild)
      if (nightKeys.isNotEmpty) {
        await _repo.upsertIndexForNightKeys(nightKeys);
      } else {
        await _repo.rebuildIndexFromImports();
      }

      final copiedCount = (res['copiedCount'] as int?) ?? 0;
      final skippedCount = (res['skippedCount'] as int?) ?? 0;

      _lastCopiedCount = copiedCount;
      _lastSkippedCount = skippedCount;

      await _loadNights(setLoadingState: false);

      if (!mounted) return;
      setState(() {
        _lastAutoSync = DateTime.now();
        _autoStatus = 'Historique: OK • $copiedCount copié(s), $skippedCount déjà présents';
        _isAutoSyncing = false;
        _autoHadError = false;
        _autoUserError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = _humanizeAutoError(e);
      setState(() {
        _autoStatus = 'Historique: échec';
        _isAutoSyncing = false;
        _autoHadError = true;
        _autoUserError = msg;
        _loadingNights = false;
      });
    }
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Sync historique'),
              subtitle: Text('Importe plusieurs nuits depuis la SD (offline, local).'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('3 dernières nuits'),
              onTap: () {
                Navigator.pop(context);
                _syncLastN(3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('7 dernières nuits'),
              onTap: () {
                Navigator.pop(context);
                _syncLastN(7);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('14 dernières nuits'),
              onTap: () {
                Navigator.pop(context);
                _syncLastN(14);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('30 dernières nuits'),
              onTap: () {
                Navigator.pop(context);
                _syncLastN(30);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Deux date pickers (début / fin)
  Future<void> _pickStartEndDates() async {
    final now = DateTime.now();

    final startInit = _range?.start ?? now.subtract(const Duration(days: 30));
    final endInit = _range?.end ?? now;

    final start = await showDatePicker(
      context: context,
      initialDate: DateTime(startInit.year, startInit.month, startInit.day),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (!mounted || start == null) return;

    final end = await showDatePicker(
      context: context,
      initialDate: DateTime(endInit.year, endInit.month, endInit.day).isBefore(start) ? start : endInit,
      firstDate: start,
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (!mounted || end == null) return;

    setState(() {
      _range = DateTimeRange(start: start, end: end);
      _latestN = null; // mode plage prend le dessus
    });

    await _loadNights(setLoadingState: true);
  }

  void _clearFilter() {
    setState(() {
      _range = null;
      _latestN = null;
    });
    _loadNights(setLoadingState: true);
  }

  void _openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          repo: _repo,
          range: _range,
          limit: _range == null ? _latestN : null,
        ),
      ),
    );
  }

  void _openAdvanced() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ImportScreen(
          appBarTitle: 'Avancé',
          enableAutoSync: false,
          showSdCard: false,
          showResmedNights: false,
        ),
      ),
    );
  }

  void _openDiagnostics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DiagnosticsScreen(
          repo: _repo,
          pairedTreeUri: _pairedTreeUri,
          autoStatus: _autoStatus,
          lastSync: _lastAutoSync,
          lastCopiedCount: _lastCopiedCount,
          lastSkippedCount: _lastSkippedCount,
          lastSyncKind: _lastSyncKind,
          filterText: _filterText(),
          currentListCount: _nights.length,
          isAutoSyncing: _isAutoSyncing,
          onRebuildIndex: () async {
            await _repo.rebuildIndexFromImports();
            await _loadNights(setLoadingState: true);
          },
          onReload: () async {
            await _loadNights(setLoadingState: true);
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshPairing();
      await _loadNights(setLoadingState: false);
      await _tryAutoSync(); // auto au démarrage
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
      final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrent) _tryAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterText = _filterText();
    final nightsCountText = '${_nights.length} nuit${_nights.length == 1 ? '' : 's'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CPAPorama'),
        actions: [
          IconButton(
            onPressed: _pickStartEndDates,
            icon: const Icon(Icons.date_range),
            tooltip: 'Début / Fin',
          ),
          IconButton(
            onPressed: _openStats,
            icon: const Icon(Icons.query_stats),
            tooltip: 'Stats',
          ),
          if (kDebugMode)
            IconButton(
              onPressed: _openDiagnostics,
              icon: const Icon(Icons.bug_report),
              tooltip: 'Diagnostics',
            ),
          if (kDebugMode)
            IconButton(
              onPressed: _openAdvanced,
              icon: const Icon(Icons.tune),
              tooltip: 'Avancé',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Carte SD', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(_autoStatus),
                  if (_lastAutoSync != null) ...[
                    const SizedBox(height: 4),
                    Text('Dernière synchro: ${_fmtClock(_lastAutoSync!)}'),
                  ],
                  if (_autoHadError && _autoUserError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _autoUserError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Astuce: quand Android te demande un dossier, choisis la racine de la carte SD ou “DATALOG”.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),

                  if (_pairedTreeUri == null) ...[
                    FilledButton.icon(
                      onPressed: _isAutoSyncing ? null : _pairSd,
                      icon: const Icon(Icons.link),
                      label: const Text('Connecter la carte SD'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _isAutoSyncing ? null : () => _tryAutoSync(force: true),
                      icon: const Icon(Icons.sync),
                      label: const Text('Synchroniser'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isAutoSyncing ? null : _openHistorySheet,
                      icon: const Icon(Icons.history),
                      label: const Text('Historique'),
                    ),
                  ],

                  if (_isAutoSyncing) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],

                  if (_pairedTreeUri != null) ...[
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nuits', style: Theme.of(context).textTheme.titleMedium),
                  Text(filterText, style: Theme.of(context).textTheme.bodySmall),
                  Text(nightsCountText, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              Row(
                children: [
                  if (_hasActiveFilter)
                    IconButton(
                      onPressed: _clearFilter,
                      icon: const Icon(Icons.clear),
                      tooltip: 'Effacer le filtre',
                    ),
                  IconButton(
                    onPressed: _loadingNights ? null : () => _loadNights(setLoadingState: true),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Rafraîchir',
                  ),
                ],
              ),
            ],
          ),

          if (_loadingNights) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],

          if (_nights.isEmpty && !_loadingNights) ...[
            const SizedBox(height: 8),
            Text(
              _hasActiveFilter
                  ? 'Aucune nuit pour ce filtre. Efface le filtre ou synchronise.'
                  : 'Aucune nuit détectée (index). Connecte la carte SD pour synchroniser.',
            ),
          ],

          if (_nights.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._nights.map((n) {
              final date = _fmtDate(n.nightDate);
              final start = _fmtClock(n.start);
              final end = _fmtClock(n.end);

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.nightlight_round),
                  title: Text(date),
                  subtitle: Text('Segments: ${n.sessionsCount} • gaps: ${n.gapCount} • $start → $end'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openNightViewerByKey(n.nightKey),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// Dev-only, minimaliste, et surtout compilable.
// Tu pourras le déplacer dans un fichier séparé plus tard.
class _DiagnosticsScreen extends StatefulWidget {
  const _DiagnosticsScreen({
    required this.repo,
    required this.pairedTreeUri,
    required this.autoStatus,
    required this.lastSync,
    required this.lastCopiedCount,
    required this.lastSkippedCount,
    required this.lastSyncKind,
    required this.filterText,
    required this.currentListCount,
    required this.isAutoSyncing,
    required this.onRebuildIndex,
    required this.onReload,
  });

  final NightRepository repo;
  final String? pairedTreeUri;
  final String autoStatus;
  final DateTime? lastSync;
  final int? lastCopiedCount;
  final int? lastSkippedCount;
  final String? lastSyncKind;
  final String filterText;
  final int currentListCount;
  final bool isAutoSyncing;

  final Future<void> Function() onRebuildIndex;
  final Future<void> Function() onReload;

  @override
  State<_DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<_DiagnosticsScreen> {
  bool _busy = false;

  String _fmtDateTime(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OK')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSyncText = widget.lastSync == null ? '—' : _fmtDateTime(widget.lastSync!);
    final copied = widget.lastCopiedCount?.toString() ?? '—';
    final skipped = widget.lastSkippedCount?.toString() ?? '—';
    final kind = widget.lastSyncKind ?? '—';
    final paired = (widget.pairedTreeUri == null) ? 'non' : 'oui';

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics (dev)')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('État', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('SD pairée: $paired'),
                  Text('Statut: ${widget.autoStatus}'),
                  Text('Dernier sync: $lastSyncText'),
                  Text('Dernier sync kind: $kind'),
                  Text('Dernier sync copied/skipped: $copied / $skipped'),
                  Text('Auto-sync en cours: ${widget.isAutoSyncing ? 'oui' : 'non'}'),
                  const SizedBox(height: 8),
                  Text('Filtre: ${widget.filterText}'),
                  Text('Liste actuelle: ${widget.currentListCount} nuit(s)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Actions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _run(widget.onReload),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recharger la liste'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(widget.onRebuildIndex),
                    icon: const Icon(Icons.build),
                    label: const Text('Reconstruire index (bulldozer)'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
