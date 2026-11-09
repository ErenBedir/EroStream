import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../telegram/telegram_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Telegram sign-in. Pops with `true` once the account is ready.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    final tg = context.services.telegram;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: tg,
          builder: (context, _) {
            if (tg.step == AuthStep.ready && !_popped) {
              _popped = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop(true);
              });
            }
            return AnimatedSwitcher(
              duration: Motion.normal,
              child: KeyedSubtree(key: ValueKey(tg.step), child: _step(context, tg)),
            );
          },
        ),
      ),
    );
  }

  Widget _step(BuildContext context, TelegramService tg) {
    final l = L.of(context);
    return switch (tg.step) {
      AuthStep.unavailable => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l.telegramUnavailable,
          body: tg.lastError ?? '',
        ),
      AuthStep.missingCredentials => const _CredentialsForm(),
      AuthStep.waitPhone => const _PhoneForm(),
      AuthStep.waitQr => const _QrView(),
      AuthStep.waitCode => const _CodeForm(),
      AuthStep.waitPassword => const _PasswordForm(),
      AuthStep.unsupported => EmptyState(
          icon: Icons.info_outline_rounded,
          title: l.unsupportedAuth,
          body: '',
          action: OutlinedButton(onPressed: tg.cancelLogin, child: Text(l.back)),
        ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Shared frame: title, text, fields, primary action.
class _AuthForm extends StatefulWidget {
  const _AuthForm({
    required this.title,
    required this.body,
    required this.label,
    required this.onSubmit,
    this.obscure = false,
    this.keyboard = TextInputType.text,
    this.extra,
  });

  final String title;
  final String body;
  final String label;
  final bool obscure;
  final TextInputType keyboard;
  final Future<void> Function(String value) onSubmit;
  final Widget? extra;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _c = TextEditingController();
  bool _busy = false;

  Future<void> _go() async {
    if (_busy || _c.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await widget.onSubmit(_c.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tg = context.services.telegram;
    return Readable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: t.headlineSmall),
          if (widget.body.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(widget.body, style: t.bodyMedium?.copyWith(color: Palette.textDim)),
          ],
          const SizedBox(height: Space.xl),
          TextField(
            controller: _c,
            autofocus: true,
            obscureText: widget.obscure,
            keyboardType: widget.keyboard,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(labelText: widget.label),
          ),
          ListenableBuilder(listenable: tg, builder: (_, _) => ErrorLine(tg.lastError)),
          const SizedBox(height: Space.l),
          FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(L.of(context).continueAction),
          ),
          if (widget.extra != null) ...[const SizedBox(height: Space.m), widget.extra!],
        ],
      ),
    );
  }
}

class _PhoneForm extends StatelessWidget {
  const _PhoneForm();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tg = context.services.telegram;
    return _AuthForm(
      title: l.loginPhoneTitle,
      body: '',
      label: l.phoneHint,
      keyboard: TextInputType.phone,
      onSubmit: tg.submitPhone,
      extra: OutlinedButton.icon(
        onPressed: tg.requestQr,
        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
        label: Text(l.loginWithQr),
      ),
    );
  }
}

class _CodeForm extends StatelessWidget {
  const _CodeForm();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tg = context.services.telegram;
    return _AuthForm(
      title: l.codeTitle,
      body: l.codeSentTo(tg.codePhone),
      label: l.codeLabel,
      keyboard: TextInputType.number,
      onSubmit: tg.submitCode,
    );
  }
}

class _PasswordForm extends StatelessWidget {
  const _PasswordForm();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tg = context.services.telegram;
    return _AuthForm(
      title: l.passwordTitle,
      body: tg.passwordHint.isEmpty ? '' : l.passwordHintText(tg.passwordHint),
      label: l.passwordLabel,
      obscure: true,
      keyboard: TextInputType.visiblePassword,
      onSubmit: tg.submitPassword,
    );
  }
}

class _QrView extends StatelessWidget {
  const _QrView();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tg = context.services.telegram;
    final t = Theme.of(context).textTheme;
    return Readable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.loginWithQr, style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.xl),
          Container(
            padding: const EdgeInsets.all(Space.l),
            decoration: BoxDecoration(color: Palette.text, borderRadius: BorderRadius.circular(Radii.l)),
            child: QrImageView(
              data: tg.qrLink,
              size: 220,
              backgroundColor: Palette.text,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Palette.bg),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Palette.bg),
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(l.qrInstructions, style: t.bodyMedium?.copyWith(color: Palette.textDim), textAlign: TextAlign.center),
          ErrorLine(tg.lastError),
          const SizedBox(height: Space.l),
          TextButton(onPressed: tg.cancelLogin, child: Text(l.usePhoneInstead)),
        ],
      ),
    );
  }
}

class _CredentialsForm extends StatefulWidget {
  const _CredentialsForm();

  @override
  State<_CredentialsForm> createState() => _CredentialsFormState();
}

class _CredentialsFormState extends State<_CredentialsForm> {
  final _id = TextEditingController();
  final _hash = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _hash.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = int.tryParse(_id.text.trim()) ?? 0;
    if (id == 0 || _hash.text.trim().isEmpty) return;
    final s = context.services;
    await s.settings.setTelegramCredentials(id, _hash.text);
    await s.telegram.retry();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final t = Theme.of(context).textTheme;
    return Readable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.credentialsTitle, style: t.headlineSmall),
          const SizedBox(height: Space.s),
          Text(l.credentialsBody, style: t.bodyMedium?.copyWith(color: Palette.textDim)),
          const SizedBox(height: Space.xl),
          TextField(controller: _id, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.apiId)),
          const SizedBox(height: Space.m),
          TextField(controller: _hash, decoration: InputDecoration(labelText: l.apiHash), onSubmitted: (_) => _save()),
          const SizedBox(height: Space.l),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
