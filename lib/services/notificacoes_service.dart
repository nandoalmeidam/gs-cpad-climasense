import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/regra_alerta.dart';

class PermissaoNotificacaoException implements Exception {
  @override
  String toString() =>
      'As notificações estão bloqueadas. Permita as notificações do ClimaSense nas configurações do celular.';
}

class NotificacoesService {
  final FlutterLocalNotificationsPlugin plugin;
  NotificacoesService({FlutterLocalNotificationsPlugin? plugin})
    : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  VoidCallback? aoAbrirAlerta;
  Future<void>? _inicio;
  Future<void> _fila = Future.value();
  bool get suportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _iniciar() =>
      _inicio ??= _configurar().catchError((Object erro, StackTrace pilha) {
        _inicio = null;
        Error.throwWithStackTrace(erro, pilha);
      });

  Future<void> _configurar() async {
    if (!suportado) {
      throw UnsupportedError(
        'Instale o aplicativo no celular para receber notificações.',
      );
    }
    final iniciou = await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_clima'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resposta) {
        if (resposta.payload == 'alertas') aoAbrirAlerta?.call();
      },
    );
    if (iniciou != true) {
      throw StateError('Não foi possível iniciar as notificações.');
    }
  }

  Future<bool> ativar() async {
    await _iniciar();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) throw StateError('Serviço Android indisponível.');
      final permitido = await android.requestNotificationsPermission() ?? false;
      if (!permitido) return false;
      final canais = await android.getNotificationChannels();
      return !(canais ?? []).any(
        (canal) =>
            canal.id == 'sinais_territoriais' &&
            canal.importance == Importance.none,
      );
    }
    return await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<bool> abrirConfiguracoes() => Geolocator.openAppSettings();

  Future<void> restaurarAbertura() async {
    if (!suportado) return;
    await _iniciar();
    final abertura = await plugin.getNotificationAppLaunchDetails();
    if (abertura?.didNotificationLaunchApp == true &&
        abertura?.notificationResponse?.payload == 'alertas') {
      aoAbrirAlerta?.call();
    }
  }

  Future<void> mostrar(String titulo, String corpo, {int id = 1}) async {
    await _iniciar();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final permitido = await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      if (permitido != true) throw PermissaoNotificacaoException();
    }
    await plugin.show(
      id: id,
      title: titulo,
      body: corpo,
      payload: 'alertas',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sinais_territoriais',
          'Alertas do ClimaSense',
          channelDescription:
              'Avisos locais de chuva, vento e ocorrências acompanhadas no aplicativo',
          icon: 'ic_stat_clima',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(corpo),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> verificar(List<RegraAlerta> alertas) {
    // Serializa as avaliações: clima e cadastro podem pedir o mesmo aviso juntos.
    final operacao = _fila.then((_) => _verificar(List.of(alertas)));
    _fila = operacao.catchError((Object _) {});
    return operacao;
  }

  Future<void> _verificar(List<RegraAlerta> alertas) async {
    if (!suportado) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notificacoes') ?? false)) return;
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final enviadas = (prefs.getStringList('notificacoes_enviadas') ?? [])
        .where((s) => s.startsWith('$hoje|'))
        .toSet();
    for (final alerta in alertas.where((a) => a.nivel == 'Alto')) {
      final assinatura = '$hoje|${alerta.titulo}|${alerta.evidencia}';
      if (enviadas.contains(assinatura)) continue;
      // Um ID estável por aviso evita que alertas diferentes se substituam.
      final id = assinatura.codeUnits.fold<int>(
        0,
        (valor, letra) => (valor * 31 + letra) & 0x7fffffff,
      );
      await mostrar(
        'ClimaSense: ${alerta.titulo}',
        '${alerta.evidencia} Confira os detalhes no app e acompanhe os avisos oficiais da sua região.',
        id: id,
      );
      enviadas.add(assinatura);
      await prefs.setStringList('notificacoes_enviadas', enviadas.toList());
    }
  }
}
