import 'dart:async';
import 'dart:math';

import 'package:dbus/dbus.dart';

/// Uses XDG Desktop Portal so the desktop environment supplies its own dialog.
class PortalFileChooser {
  static const _portalName = 'org.freedesktop.portal.Desktop';
  static const _portalPath = '/org/freedesktop/portal/desktop';
  static const _fileChooserInterface = 'org.freedesktop.portal.FileChooser';
  static const _requestInterface = 'org.freedesktop.portal.Request';

  static Future<String?> saveFile({
    required String title,
    required String suggestedName,
    String acceptLabel = 'Save',
  }) => _choose(
    method: 'SaveFile',
    title: title,
    options: {
      'current_name': DBusString(suggestedName),
      'accept_label': DBusString(acceptLabel),
      'filters': _textFileFilters,
    },
  );

  static Future<String?> openFile({
    required String title,
    String acceptLabel = 'Open',
  }) => _choose(
    method: 'OpenFile',
    title: title,
    options: {
      'accept_label': DBusString(acceptLabel),
      'filters': _textFileFilters,
    },
  );

  static final _textFileFilters = DBusArray(DBusSignature('(sa(us))'), [
    DBusStruct([
      DBusString('Text files'),
      DBusArray(DBusSignature('(us)'), [
        DBusStruct([DBusUint32(0), DBusString('*.txt')]),
      ]),
    ]),
  ]);

  static Future<String?> _choose({
    required String method,
    required String title,
    required Map<String, DBusValue> options,
  }) async {
    final client = DBusClient.session();
    StreamSubscription<DBusSignal>? responseSubscription;
    try {
      // Establish the bus connection first, so we can subscribe to the
      // predictable request path before asking the portal to show the dialog.
      await client.callMethod(
        destination: 'org.freedesktop.DBus',
        path: DBusObjectPath('/org/freedesktop/DBus'),
        interface: 'org.freedesktop.DBus',
        name: 'GetId',
        replySignature: DBusSignature('s'),
      );

      final token =
          'leenky_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
      final sender = client.uniqueName
          .replaceFirst(':', '')
          .replaceAll('.', '_');
      final expectedPath = '$_portalPath/request/$sender/$token';
      options['handle_token'] = DBusString(token);

      final response = Completer<String?>();
      responseSubscription = _subscribe(client, expectedPath, response);

      final call = await client.callMethod(
        destination: _portalName,
        path: DBusObjectPath(_portalPath),
        interface: _fileChooserInterface,
        name: method,
        values: [
          const DBusString(''), // Optional parent window identifier.
          DBusString(title),
          DBusDict.stringVariant(options),
        ],
        replySignature: DBusSignature('o'),
      );

      final actualPath = call.returnValues.first.asObjectPath().value;
      if (actualPath != expectedPath) {
        // Older portal versions may not use handle_token to construct their
        // request path. The response normally follows the user interaction.
        await responseSubscription.cancel();
        responseSubscription = _subscribe(client, actualPath, response);
      }
      return await response.future;
    } finally {
      await responseSubscription?.cancel();
      await client.close();
    }
  }

  static StreamSubscription<DBusSignal> _subscribe(
    DBusClient client,
    String path,
    Completer<String?> response,
  ) =>
      DBusRemoteObjectSignalStream(
        object: DBusRemoteObject(
          client,
          name: _portalName,
          path: DBusObjectPath(path),
        ),
        interface: _requestInterface,
        name: 'Response',
        signature: DBusSignature('ua{sv}'),
      ).listen((signal) {
        if (response.isCompleted) return;
        final status = signal.values[0].asUint32();
        if (status == 1) {
          response.complete(null); // User cancelled.
        } else if (status != 0) {
          response.completeError(StateError('The desktop file dialog failed.'));
        } else {
          final values = signal.values[1].asStringVariantDict();
          final uris =
              values['uris']?.asStringArray().toList() ?? const <String>[];
          if (uris.isEmpty) {
            response.completeError(
              StateError('The desktop returned no selected file.'),
            );
          } else {
            response.complete(Uri.parse(uris.first).toFilePath());
          }
        }
      });
}
