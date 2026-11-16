import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:climasense/models/regra_alerta.dart';
import 'package:climasense/services/notificacoes_service.dart';
import 'package:climasense/features/alertas/alertas_page.dart';
import 'package:climasense/providers/dados_app.dart';
import 'package:climasense/providers/dados_clima.dart';
import 'package:climasense/services/banco_ocorrencias.dart';
import 'package:sembast/sembast_memory.dart';

class NotificacoesDaTela extends NotificacoesService {
  @override
  bool get suportado => true;
  bool permitidas = false, configuracoesAbertas = false;
  @override
  Future<bool> ativar() async => permitidas;
  @override
  Future<bool> abrirConfiguracoes() async {
    configuracoesAbertas = true;
    return true;
  }

  @override
  Future<void> verificar(List<RegraAlerta> alertas) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('dexterous.com/flutter/local_notifications');
  final chamadas = <MethodCall>[];
  bool permitido = true, falharEnvio = false, lancadoPorNotificacao = false;
  const resposta = {
    'notificationId': 1,
    'payload': 'alertas',
    'notificationResponseType': 0,
  };
  late NotificacoesService servico;
  const alto = RegraAlerta(
    'Chuva na região',
    '60 mm previstos.',
    'Previsão sujeita a mudanças.',
    'Alto',
    0,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({'notificacoes': true});
    chamadas.clear();
    permitido = true;
    falharEnvio = false;
    lancadoPorNotificacao = false;
    servico = NotificacoesService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (chamada) async {
          chamadas.add(chamada);
          switch (chamada.method) {
            case 'initialize':
              return true;
            case 'requestNotificationsPermission':
            case 'areNotificationsEnabled':
              return permitido;
            case 'getNotificationChannels':
              return [];
            case 'getNotificationAppLaunchDetails':
              return {
                'notificationLaunchedApp': lancadoPorNotificacao,
                'notificationResponse': resposta,
              };
            case 'show':
              if (falharEnvio) throw PlatformException(code: 'erro_envio');
              return null;
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });
  test(
    'solicita permissão somente na ativação e usa o ícone do projeto',
    () async {
      await servico.restaurarAbertura();
      expect(
        chamadas.where((c) => c.method == 'requestNotificationsPermission'),
        isEmpty,
      );
      expect(await servico.ativar(), isTrue);
      expect(
        chamadas
            .firstWhere((c) => c.method == 'initialize')
            .arguments['defaultIcon'],
        'ic_stat_clima',
      );
      permitido = false;
      expect(await servico.ativar(), isFalse);
      await expectLater(
        servico.mostrar('Teste', 'Mensagem'),
        throwsA(isA<PermissaoNotificacaoException>()),
      );
      expect(chamadas.where((c) => c.method == 'show'), isEmpty);
    },
  );
  test(
    'envia somente nível alto, não duplica e mantém avisos distintos',
    () async {
      const outro = RegraAlerta(
        'Vento na região',
        '90 km/h previstos.',
        'Previsão sujeita a mudanças.',
        'Alto',
        0,
      );
      const baixo = RegraAlerta(
        'Um relato',
        '1 registro.',
        'Relato voluntário.',
        'Atenção',
        0,
      );
      await Future.wait([
        servico.verificar([alto, outro, baixo]),
        servico.verificar([alto, outro]),
      ]);
      final enviadas = chamadas.where((c) => c.method == 'show').toList();
      expect(enviadas, hasLength(2));
      expect(enviadas[0].arguments['id'], isNot(enviadas[1].arguments['id']));
      expect(enviadas.first.arguments['payload'], 'alertas');
      expect(enviadas.first.arguments['platformSpecifics']['importance'], 4);
    },
  );
  test(
    'falha de envio permite nova tentativa e preferência desligada não envia',
    () async {
      falharEnvio = true;
      await expectLater(
        servico.verificar([alto]),
        throwsA(isA<PlatformException>()),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('notificacoes_enviadas'), isNull);
      falharEnvio = false;
      await servico.verificar([alto]);
      expect(prefs.getStringList('notificacoes_enviadas'), hasLength(1));
      chamadas.clear();
      await prefs.setBool('notificacoes', false);
      await servico.verificar([alto]);
      expect(chamadas, isEmpty);
    },
  );
  test(
    'toque e início pela notificação acionam a abertura dos alertas',
    () async {
      var aberturas = 0;
      servico.aoAbrirAlerta = () => aberturas++;
      await servico.ativar();
      final concluido = Completer<void>();
      ServicesBinding.instance.channelBuffers.push(
        canal.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('didReceiveNotificationResponse', resposta),
        ),
        (_) => concluido.complete(),
      );
      await concluido.future;
      expect(aberturas, 1);
      lancadoPorNotificacao = true;
      await servico.restaurarAbertura();
      expect(aberturas, 2);
    },
  );
  testWidgets('tela permite ativar notificações sem expor ações de teste', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = null;
    SharedPreferences.setMockInitialValues({'consentimento': true});
    final avisos = NotificacoesDaTela();
    late DadosApp dados;
    await tester.runAsync(() async {
      final banco = BancoOcorrencias(
        await newDatabaseFactoryMemory().openDatabase('notificacoes-tela'),
      );
      dados = DadosApp(
        abrirBanco: () async => banco,
        avisos: avisos,
        intervaloSincronizacao: Duration.zero,
      );
      await dados.iniciar();
    });
    final clima = DadosClima();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertasPage(dados: dados, clima: clima),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Receber notificações'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Receber notificações'));
    await tester.pumpAndSettle();
    expect(dados.notificacoes, isFalse);
    expect(
      find.textContaining('As notificações estão bloqueadas'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Abrir configurações do celular'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir configurações do celular'));
    await tester.pumpAndSettle();
    expect(avisos.configuracoesAbertas, isTrue);
    avisos.permitidas = true;
    await tester.ensureVisible(find.text('Receber notificações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receber notificações'));
    await tester.pumpAndSettle();
    expect(dados.notificacoes, isTrue);
    expect(find.text('Enviar notificação de teste'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    dados.dispose();
    clima.dispose();
  });
}
