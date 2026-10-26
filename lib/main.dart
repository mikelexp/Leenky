import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'portal_file_chooser.dart';
import 'url_tools.dart';

void main() => runApp(const LeenkyApp());

class LeenkyApp extends StatefulWidget {
  const LeenkyApp({super.key});

  @override
  State<LeenkyApp> createState() => _LeenkyAppState();
}

class _LeenkyAppState extends State<LeenkyApp> {
  final _systemTheme = _SystemTheme();

  @override
  void initState() {
    super.initState();
    _systemTheme.addListener(_themeChanged);
    _systemTheme.initialize();
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _systemTheme
      ..removeListener(_themeChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Leenky',
    debugShowCheckedModeBanner: false,
    themeMode: _systemTheme.mode,
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    home: const CollectorPage(),
  );

  ThemeData _buildTheme(Brightness brightness) {
    final accent = brightness == Brightness.light
        ? const Color(0xff00bfff)
        : const Color(0xff38bdf8);
    final onAccent = const Color(0xff003044);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: brightness == Brightness.light
              ? const Color(0xfffaf9f6)
              : const Color(0xff17181d),
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          primaryContainer: brightness == Brightness.light
              ? const Color(0xff0077b6)
              : const Color(0xff075985),
          onPrimaryContainer: Colors.white,
          secondary: accent,
          onSecondary: onAccent,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xfff4f3ef)
          : const Color(0xff111216),
      fontFamily: 'Sans',
    );
  }
}

/// Reads the freedesktop portal preference so GTK desktops (including GNOME
/// and Plasma) can drive the theme even when Flutter's Linux brightness is not
/// populated by the host. Falls back to Flutter's platform brightness.
class _SystemTheme extends ChangeNotifier {
  static const _portalName = 'org.freedesktop.portal.Desktop';
  static const _portalPath = '/org/freedesktop/portal/desktop';
  static const _portalInterface = 'org.freedesktop.portal.Settings';
  static const _appearanceNamespace = 'org.freedesktop.appearance';
  static const _colorSchemeKey = 'color-scheme';

  DBusClient? _client;
  StreamSubscription<DBusSignal>? _signals;
  ThemeMode mode = ThemeMode.system;

  Future<void> initialize() async {
    if (!Platform.isLinux) return;
    final client = DBusClient.session();
    try {
      _client = client;
      final object = DBusRemoteObject(
        client,
        name: _portalName,
        path: DBusObjectPath(_portalPath),
      );
      _signals =
          DBusRemoteObjectSignalStream(
            object: object,
            interface: _portalInterface,
            name: 'SettingChanged',
            signature: DBusSignature('ssv'),
          ).listen((signal) {
            if (signal.values.length == 3 &&
                signal.values[0].asString() == _appearanceNamespace &&
                signal.values[1].asString() == _colorSchemeKey) {
              _applyColorScheme(signal.values[2].asVariant().asUint32());
            }
          });
      final setting = await client.callMethod(
        destination: _portalName,
        path: DBusObjectPath(_portalPath),
        interface: _portalInterface,
        name: 'Read',
        values: const [
          DBusString(_appearanceNamespace),
          DBusString(_colorSchemeKey),
        ],
        replySignature: DBusSignature('v'),
      );
      _applyColorScheme(setting.returnValues.first.asVariant().asUint32());
    } catch (_) {
      // Older desktops may not expose the portal setting; ThemeMode.system
      // still follows platformBrightness wherever the Flutter embedder reports it.
      await _signals?.cancel();
      _signals = null;
      await client.close();
      _client = null;
    }
  }

  void _applyColorScheme(int value) {
    final next = switch (value) {
      1 => ThemeMode.dark,
      2 => ThemeMode.light,
      _ => ThemeMode.system,
    };
    if (next == mode) return;
    mode = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _signals?.cancel();
    _client?.close();
    super.dispose();
  }
}

class CollectorPage extends StatefulWidget {
  const CollectorPage({super.key});

  @override
  State<CollectorPage> createState() => _CollectorPageState();
}

class _CollectorPageState extends State<CollectorPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _poll;
  bool _polling = false;
  bool _discardDuplicates = true;
  bool _klipperErrorShown = false;
  DBusClient? _bus;
  StreamSubscription<DBusSignal>? _klipperSignals;

  List<String> get _lines => _text.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _readClipboard(),
    );
    _connectKlipper();
  }

  Future<void> _connectKlipper() async {
    final desktop = (Platform.environment['XDG_CURRENT_DESKTOP'] ?? '')
        .toLowerCase();
    if (!Platform.isLinux ||
        (Platform.environment['WAYLAND_DISPLAY'] ?? '').isEmpty ||
        !(desktop.contains('kde') || desktop.contains('plasma'))) {
      return;
    }
    DBusClient? bus;
    try {
      final connectedBus = DBusClient.session();
      bus = connectedBus;
      final object = DBusRemoteObject(
        connectedBus,
        name: 'org.kde.klipper',
        path: DBusObjectPath('/klipper'),
      );
      await connectedBus.callMethod(
        destination: 'org.kde.klipper',
        path: DBusObjectPath('/klipper'),
        interface: 'org.freedesktop.DBus.Introspectable',
        name: 'Introspect',
        replySignature: DBusSignature('s'),
      );
      final signals = DBusRemoteObjectSignalStream(
        object: object,
        interface: 'org.kde.klipper.klipper',
        name: 'clipboardHistoryUpdated',
      );
      _bus = connectedBus;
      _klipperSignals = signals.listen((_) => _readKlipper());
    } catch (_) {
      await _klipperSignals?.cancel();
      _klipperSignals = null;
      await bus?.close();
      _bus = null;
      _showKlipperError(
        'No se pudo conectar con Klipper. Se seguirá usando el portapapeles normal.',
      );
    }
  }

  Future<void> _readKlipper() async {
    final bus = _bus;
    if (bus == null || _polling) return;
    try {
      final reply = await bus.callMethod(
        destination: 'org.kde.klipper',
        path: DBusObjectPath('/klipper'),
        interface: 'org.kde.klipper.klipper',
        name: 'getClipboardContents',
        replySignature: DBusSignature('s'),
      );
      await _collect(
        reply.returnValues.first.asString(),
        clear: () async {
          await bus.callMethod(
            destination: 'org.kde.klipper',
            path: DBusObjectPath('/klipper'),
            interface: 'org.kde.klipper.klipper',
            name: 'clearClipboardContents',
          );
        },
      );
    } catch (_) {
      _showKlipperError(
        'Klipper dejó de responder. Se seguirá usando el portapapeles normal.',
      );
    }
  }

  Future<void> _readClipboard() async {
    if (_polling) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty) return;
      await _collect(
        text,
        clear: () => Clipboard.setData(const ClipboardData(text: '')),
      );
    } catch (_) {
      // Some Wayland compositors restrict clipboard access to focused applications.
    }
  }

  Future<void> _collect(
    String text, {
    required Future<void> Function() clear,
  }) async {
    final urls = extractUrls(text);
    if (urls.isEmpty) return;
    _addUrls(urls);
    _polling = true;
    try {
      await clear();
    } finally {
      _polling = false;
    }
  }

  void _addUrls(List<String> urls) {
    final current = _lines;
    final seen = current.toSet();
    final additions = <String>[];
    for (final url in urls) {
      if (!_discardDuplicates || seen.add(url)) additions.add(url);
    }
    if (additions.isEmpty) return;
    _text.text = [...current, ...additions].join('\n');
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    setState(() {});
  }

  Future<void> _saveAs() async {
    try {
      final path = await PortalFileChooser.saveFile(
        title: 'Save Links',
        suggestedName: 'links.txt',
        acceptLabel: 'Save',
      );
      if (path == null) return;
      final target = path.toLowerCase().endsWith('.txt') ? path : '$path.txt';
      await File(target).writeAsString(_text.text);
      _notify('Saved ${_lines.length} links');
    } catch (_) {
      _showFileDialogError(
        'No se pudo abrir el diálogo nativo para guardar. Comprueba que el portal del escritorio esté disponible.',
      );
    }
  }

  Future<void> _appendTo() async {
    try {
      final selected = await PortalFileChooser.openFile(
        title: 'Append Links',
        acceptLabel: 'Append',
      );
      if (selected == null || _text.text.trim().isEmpty) return;
      final path = File(selected);
      final existing = await path.readAsString();
      final combined = [...existing.split('\n'), ..._text.text.split('\n')];
      final result = <String>[];
      final seen = <String>{};
      for (final line in combined) {
        final value = line.trim();
        if (extractUrls(value).length == 1 &&
            extractUrls(value).single == value) {
          if (!seen.add(value)) continue;
        }
        result.add(line);
      }
      await path.writeAsString(result.join('\n'));
      _notify('Links appended');
    } catch (_) {
      _showFileDialogError(
        'No se pudo abrir el diálogo nativo para elegir un archivo. Comprueba que el portal del escritorio esté disponible.',
      );
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void _showKlipperError(String message) {
    if (!mounted || _klipperErrorShown) return;
    _klipperErrorShown = true;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: colors.error,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: colors.onError),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: TextStyle(color: colors.onError)),
              ),
            ],
          ),
        ),
      );
  }

  void _showFileDialogError(String message) {
    if (!mounted) return;
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: colors.error,
          content: Text(message, style: TextStyle(color: colors.onError)),
        ),
      );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _klipperSignals?.cancel();
    _bus?.close();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final links = _lines;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'COLLECTED LINKS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.2,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${links.length}',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      _text.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Stack(
                    children: [
                      TextField(
                        controller: _text,
                        focusNode: _focus,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.8,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Copy links from anywhere — they’ll appear here automatically.\n\nYou can also paste or type links directly.',
                          hintStyle: TextStyle(
                            height: 1.8,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: .72,
                            ),
                            fontFamily: 'Sans',
                          ),
                          contentPadding: EdgeInsets.all(22),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Discard duplicates',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: _discardDuplicates,
                      onChanged: (value) =>
                          setState(() => _discardDuplicates = value ?? true),
                      dense: true,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _appendTo,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Append to'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saveAs,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save as'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
