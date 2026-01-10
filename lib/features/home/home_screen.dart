import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/imports/resmed_night_catalog.dart';
import '../../core/imports/resmed_saf_bridge.dart';
import '../../core/imports/resmed_source_prefs.dart';
import '../imports/import_screen.dart';
import '../nights/night_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Nights
  List<ResmedNightSummary> _nights = [];
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

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<Directory> _getImportsDir() async {
    final appDocs = await getApplicationDocumentsDirectory();
    return Directory('${appDocs.path}/imports');
  }

  Future<void> _refreshPairing() async {
    final uri = await ResmedSourcePrefs.getTreeUri();
    if (!mounted) return;
    setState(() {
      _pairedTreeUri = (uri != null && uri.isNotEmpty) ? uri : null;
      if (_pairedTreeUri == null) {
        _autoStatus = 'Carte SD: non connectée';
      } else {
        _autoStatus = 'Carte SD: autorisée';
      }
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
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carte SD oubliée. Tu peux reconnecter.')),
    );
  }

  Future<void> _loadNights({bool setLoadingState = true}) async {
    if (setLoadingState) setState(() => _loadingNights = true);
    try {
      final dir = await _getImportsDir();
      final nights = await ResmedNightCatalog.scan(dir);
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

  ResmedNightSummary? _findNightByKey(String nightKey) {
    // nightKey attendu: "YYYYMMDD"
    for (final n in _nights) {
      if (_fmtDate(n.nightDate).replaceAll('-', '') == nightKey) return n;
    }
    return null;
  }

  void _openNightViewer(ResmedNightSummary night) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NightViewerScreen(night: night)),
      );
    });
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

    // Anti spam (auto)
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
    });

    try {
      final importsDir = await _getImportsDir();
      if (!await importsDir.exists()) await importsDir.create(recursive: true);

      final res = await ResmedSafBridge.syncLatest(
        treeUri: treeUri,
        destBasePath: importsDir.path,
      );

      final sessionKey = (res['sessionKey'] as String?) ?? '';
      final nightKey = (res['nightKey'] as String?) ?? '';
      final copiedCount = (res['copiedCount'] as int?) ?? 0;

      if (copiedCount <= 0) throw Exception('Aucun fichier copié');

      await _loadNights(setLoadingState: false);

      if (!mounted) return;
      setState(() {
        _lastAutoSync = DateTime.now();
        _autoStatus = 'Synchronisation: OK • $copiedCount fichier(s)';
        _isAutoSyncing = false;
        _autoHadError = false;
        _autoUserError = null;
      });

      // Auto-open (une fois par sessionKey)
      if (sessionKey.isEmpty) return;
      if (sessionKey == _lastAutoOpenedSessionKey) return;
      _lastAutoOpenedSessionKey = sessionKey;

      ResmedNightSummary? night;
      if (nightKey.length == 8) {
        night = _findNightByKey(nightKey);
      }
      night ??= _nights.isNotEmpty ? _nights.first : null;

      if (night == null) return;

      final canNavigate = ModalRoute.of(context)?.isCurrent ?? true;
      if (canNavigate) _openNightViewer(night);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPAPorama'),
        actions: [
          IconButton(
            onPressed: _openAdvanced,
            icon: const Icon(Icons.tune),
            tooltip: 'Avancé',
          )
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
              Text('Nuits', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                onPressed: _loadingNights ? null : () => _loadNights(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Rafraîchir',
              ),
            ],
          ),

          if (_loadingNights) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],

          if (_nights.isEmpty && !_loadingNights) ...[
            const SizedBox(height: 8),
            const Text('Aucune nuit ResMed détectée. Connecte la carte SD pour synchroniser.'),
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
                  subtitle: Text('Segments: ${n.segmentsCount} • $start → $end'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openNightViewer(n),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
