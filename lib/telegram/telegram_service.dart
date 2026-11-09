import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/settings.dart';
import 'td_client.dart';
import 'transport/td_transport.dart';

enum AuthStep {
  starting,
  unavailable,
  missingCredentials,
  waitPhone,
  waitQr,
  waitCode,
  waitPassword,
  unsupported,
  ready,
  closing,
  closed,
}

class TgChat {
  const TgChat({
    required this.id,
    required this.title,
    required this.isChannel,
    required this.isForum,
    this.supergroupId = 0,
  });

  final int id;
  final String title;
  final bool isChannel;
  final bool isForum;
  final int supergroupId;
}

class TgTopic {
  const TgTopic({required this.id, required this.name, this.isGeneral = false});

  final int id;
  final String name;
  final bool isGeneral;
}

/// Owns the TDLib client and the login flow.
class TelegramService extends ChangeNotifier {
  TelegramService(this.settings, {TdTransport Function()? transportFactory})
      : _factory = transportFactory ?? createTdTransport {
    client = TdClient(_factory());
  }

  final Settings settings;
  final TdTransport Function() _factory;
  late TdClient client;
  bool _disposed = false;

  AuthStep step = AuthStep.starting;
  String qrLink = '';
  String passwordHint = '';
  String codePhone = '';
  String? lastError;
  String meName = '';

  StreamSubscription<TdObject>? _sub;
  String _databaseDir = 'tdlib/db';
  String _filesDir = 'tdlib/files';
  String _languageCode = 'en';
  String _deviceModel = 'EroStream';
  String _systemVersion = '';

  bool get isReady => step == AuthStep.ready;

  /// [databaseDir]/[filesDir] are ignored on web (tdweb uses IndexedDB).
  Future<void> start({
    required String databaseDir,
    required String filesDir,
    required String languageCode,
    String deviceModel = 'EroStream',
    String systemVersion = '',
  }) async {
    _databaseDir = databaseDir;
    _filesDir = filesDir;
    _languageCode = languageCode;
    _deviceModel = deviceModel;
    _systemVersion = systemVersion;
    if (!client.isAvailable) {
      _setStep(AuthStep.unavailable, error: client.transport.unavailableReason);
      return;
    }
    if (!settings.hasTelegramCredentials) {
      _setStep(AuthStep.missingCredentials);
      return;
    }
    _sub ??= client.updates.listen(_onUpdate);
    await client.start();
  }

  /// Called after the user enters api_id / api_hash in Settings.
  Future<void> retry() => start(
        databaseDir: _databaseDir,
        filesDir: _filesDir,
        languageCode: _languageCode,
        deviceModel: _deviceModel,
        systemVersion: _systemVersion,
      );

  void _onUpdate(TdObject u) {
    if (u['@type'] != 'updateAuthorizationState') return;
    final s = u['authorization_state'] as TdObject;
    switch (s['@type']) {
      case 'authorizationStateWaitTdlibParameters':
        _sendParameters();
      case 'authorizationStateWaitPhoneNumber':
        _setStep(AuthStep.waitPhone);
      case 'authorizationStateWaitOtherDeviceConfirmation':
        qrLink = '${s['link']}';
        _setStep(AuthStep.waitQr);
      case 'authorizationStateWaitCode':
        codePhone = '${(s['code_info'] as TdObject?)?['phone_number'] ?? ''}';
        _setStep(AuthStep.waitCode);
      case 'authorizationStateWaitPassword':
        passwordHint = '${s['password_hint'] ?? ''}';
        _setStep(AuthStep.waitPassword);
      case 'authorizationStateWaitRegistration':
      case 'authorizationStateWaitEmailAddress':
      case 'authorizationStateWaitEmailCode':
      case 'authorizationStateWaitPremiumPurchase':
        _setStep(AuthStep.unsupported);
      case 'authorizationStateReady':
        _setStep(AuthStep.ready);
        _loadMe();
      case 'authorizationStateLoggingOut':
      case 'authorizationStateClosing':
        _setStep(AuthStep.closing);
      case 'authorizationStateClosed':
        _setStep(AuthStep.closed);
        _restart();
    }
  }

  /// A closed TDLib client cannot be reused (log out, QR -> phone switch).
  Future<void> _restart() async {
    if (_disposed) return;
    await _sub?.cancel();
    _sub = null;
    final old = client;
    client = TdClient(_factory());
    unawaited(old.dispose());
    await retry();
  }

  Future<void> _sendParameters() async {
    try {
      await client.send({
        '@type': 'setTdlibParameters',
        'use_test_dc': false,
        'database_directory': _databaseDir,
        'files_directory': _filesDir,
        'database_encryption_key': '',
        'use_file_database': true,
        'use_chat_info_database': true,
        'use_message_database': true,
        'use_secret_chats': false,
        'api_id': settings.apiId,
        'api_hash': settings.apiHash,
        'system_language_code': _languageCode,
        'device_model': _deviceModel,
        'system_version': _systemVersion,
        'application_version': AppConfig.version,
      });
    } on TdError catch (e) {
      _setStep(step, error: e.message);
    }
  }

  Future<void> _loadMe() async {
    try {
      final me = await client.send({'@type': 'getMe'});
      meName = [me['first_name'], me['last_name']].where((x) => '${x ?? ''}'.isNotEmpty).join(' ');
      notifyListeners();
    } on TdError catch (_) {}
  }

  Future<void> requestQr() => _guard(() => client.send({'@type': 'requestQrCodeAuthentication', 'other_user_ids': <int>[]}));

  Future<void> submitPhone(String phone) => _guard(() => client.send({
        '@type': 'setAuthenticationPhoneNumber',
        'phone_number': phone.replaceAll(RegExp(r'[^\d+]'), ''),
        'settings': null,
      }));

  Future<void> submitCode(String code) =>
      _guard(() => client.send({'@type': 'checkAuthenticationCode', 'code': code.trim()}));

  Future<void> submitPassword(String password) =>
      _guard(() => client.send({'@type': 'checkAuthenticationPassword', 'password': password}));

  /// TDLib has no way back from the QR state; drop the half-done session and start over.
  Future<void> cancelLogin() => _guard(() => client.send({'@type': 'logOut'}));

  Future<void> logOut() => _guard(() => client.send({'@type': 'logOut'}));

  Future<bool> _guard(Future<Object?> Function() f) async {
    lastError = null;
    notifyListeners();
    try {
      await f();
      return true;
    } on TdError catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  void _setStep(AuthStep s, {String? error}) {
    step = s;
    lastError = error;
    notifyListeners();
  }

  // ---- chats & topics -----------------------------------------------------

  /// Channels and supergroups from the main chat list.
  Future<List<TgChat>> listMediaChats({int limit = 400}) async {
    try {
      await client.send({'@type': 'loadChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': limit});
    } on TdError catch (e) {
      if (e.code != 404) rethrow; // 404 = everything is already loaded
    }
    final r = await client.send({'@type': 'getChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': limit});
    final ids = (r['chat_ids'] as List).cast<num>().map((e) => e.toInt());
    final out = <TgChat>[];
    for (final id in ids) {
      final c = await getChat(id);
      if (c != null) out.add(c);
    }
    return out;
  }

  /// Returns null for private chats and basic groups.
  Future<TgChat?> getChat(int id) async {
    final chat = await client.send({'@type': 'getChat', 'chat_id': id});
    final type = chat['type'] as TdObject;
    if (type['@type'] != 'chatTypeSupergroup') return null;
    final sgId = (type['supergroup_id'] as num).toInt();
    var forum = false;
    try {
      final sg = await client.send({'@type': 'getSupergroup', 'supergroup_id': sgId});
      forum = sg['is_forum'] == true;
    } on TdError catch (_) {}
    return TgChat(
      id: id,
      title: '${chat['title']}',
      isChannel: type['is_channel'] == true,
      isForum: forum,
      supergroupId: sgId,
    );
  }

  /// Resolves `@username` or a `t.me/...` link.
  Future<TgChat?> resolvePublicChat(String input) async {
    final name = input.trim().replaceFirst(RegExp(r'^(https?://)?(t\.me/|telegram\.me/)?@?'), '').split('/').first;
    if (name.isEmpty) return null;
    final chat = await client.send({'@type': 'searchPublicChat', 'username': name});
    return getChat((chat['id'] as num).toInt());
  }

  Future<List<TgTopic>> listTopics(int chatId) async {
    final out = <TgTopic>[];
    var offDate = 0, offMsg = 0, offTopic = 0;
    for (var page = 0; page < 50; page++) {
      final r = await client.send({
        '@type': 'getForumTopics',
        'chat_id': chatId,
        'query': '',
        'offset_date': offDate,
        'offset_message_id': offMsg,
        'offset_forum_topic_id': offTopic,
        'limit': 100,
      });
      final topics = (r['topics'] as List).cast<TdObject>();
      for (final t in topics) {
        final info = t['info'] as TdObject;
        out.add(TgTopic(
          id: (info['forum_topic_id'] as num).toInt(),
          name: '${info['name']}',
          isGeneral: info['is_general'] == true,
        ));
      }
      offDate = (r['next_offset_date'] as num?)?.toInt() ?? 0;
      offMsg = (r['next_offset_message_id'] as num?)?.toInt() ?? 0;
      offTopic = (r['next_offset_forum_topic_id'] as num?)?.toInt() ?? 0;
      if (topics.length < 100 || (offDate == 0 && offMsg == 0 && offTopic == 0)) break;
    }
    return out;
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    client.dispose();
    super.dispose();
  }
}
