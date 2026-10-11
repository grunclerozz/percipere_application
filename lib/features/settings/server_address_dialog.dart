import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/accessibility/command_bus.dart';
import '../../core/network/server_address.dart';
import '../../l10n/app_localizations.dart';

/// Hidden developer setting: type the web app's address (the dashboard
/// folder) on the tablet, so a new PC address or another server needs no
/// new build. Plain `http://` is only accepted for hosts the build allows
/// (`Env.allowsCleartext`); the address is checked before it is saved.
Future<void> showServerAddressDialog(WidgetRef ref, CommandBus bus) async {
  final context = ref
      .read(routerProvider)
      .routerDelegate
      .navigatorKey
      .currentContext;
  if (context == null || !context.mounted) return;
  final notifier = ref.read(serverAddressProvider.notifier);
  final spoken = await showDialog<String>(
    context: context,
    builder: (_) => _ServerAddressDialog(
      current: ref.read(serverAddressProvider),
      notifier: notifier,
    ),
  );
  if (spoken != null) await bus.say(spoken);
}

class _ServerAddressDialog extends StatefulWidget {
  const _ServerAddressDialog({required this.current, required this.notifier});

  final String current;
  final ServerAddressNotifier notifier;

  @override
  State<_ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<_ServerAddressDialog> {
  late final TextEditingController _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l) async {
    final check = ServerAddressRules.check(_text.text);
    final address = check.address;
    if (address == null) {
      setState(() {
        _error = check.problem == ServerAddressProblem.cleartextNotAllowed
            ? l.serverAddressCleartext
            : l.serverAddressInvalid;
      });
      return;
    }
    await widget.notifier.save(address);
    if (mounted) Navigator.of(context).pop(l.serverAddressSaved);
  }

  Future<void> _reset(AppLocalizations l) async {
    await widget.notifier.reset();
    if (mounted) Navigator.of(context).pop(l.serverAddressResetDone);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.serverAddressTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.serverAddressHelp),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(errorText: _error, errorMaxLines: 4),
            onSubmitted: (_) => _save(l),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.serverAddressCancel),
        ),
        TextButton(
          onPressed: () => _reset(l),
          child: Text(l.serverAddressReset),
        ),
        FilledButton(
          onPressed: () => _save(l),
          child: Text(l.serverAddressSave),
        ),
      ],
    );
  }
}
