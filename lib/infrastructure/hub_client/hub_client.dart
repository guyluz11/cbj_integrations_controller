import 'dart:async';

import 'package:async/async.dart';
import 'package:cbj_integrations_controller/infrastructure/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbgrpc.dart';
import 'package:cbj_integrations_controller/utils.dart';
import 'package:grpc/grpc.dart';
import 'package:rxdart/rxdart.dart';

class HubClient {
  static ClientChannel? channel;
  static CbjHubClient? stub;

  ///  Creates a stream with the Hub
  static Future createStreamWithHub(
    String addressToHub,
    int hubPort,
  ) async {
    await channel?.terminate();

    channel = await _createCbjHubClient(addressToHub, hubPort);
    channel!.onConnectionStateChanged.listen((event) {
      logger.i('gRPC connection state $event');
    });
    stub = CbjHubClient(channel!);
    ResponseStream<RequestsAndStatusFromHub> response;

    try {
      response = stub!.clientTransferEntities(
        AppRequestsToHub.appRequestsToHubStreamBroadcast.stream,
      );

      AppRequestsToHub.appRequestsToHubStreamController
          .add(ClientStatusRequests(sendingType: SendingType.firstConnection));

      HubRequestsToApp.streamRequestsToApp.add(response);
    } catch (e) {
      logger.e('Caught error while stream with hub\n$e');
      await channel?.shutdown();
    }
  }

  ///  Get Hub computer and software info
  static Future<CompHubInfo?> getHubCompInfo(
    String addressToHub,
    int hubPort,
    CompHubInfo compHubInfo,
  ) async {
    // channel = await _createCbjHubClient(addressToHub, hubPort);
    // stub = CbjHubClient(channel!);

    try {
      return await stub!.getCompHubInfo(compHubInfo);
    } catch (e) {
      logger.e('Caught error while trying to get Hub comp info\n$e');
      await channel?.shutdown();
    }
    return null;
  }

  static Future<ClientChannel> _createCbjHubClient(
    String deviceIp,
    int hubPort,
  ) async {
    await channel?.shutdown();
    return ClientChannel(
      deviceIp,
      port: hubPort,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
  }
}

/// Requests and updates from hub to the app
class HubRequestsToApp {
  static BehaviorSubject<dynamic> streamRequestsToApp =
      BehaviorSubject<dynamic>();
}

/// App requests for the hub to execute
class AppRequestsToHub {
  /// Stream controller of the app request for the hub

  static StreamGroup<ClientStatusRequests> appRequestsToHubStreamBroadcast =
      StreamGroup.broadcast();

  static bool boolListenWorking = false;

  static final appRequestsToHubStreamController =
      StreamController<ClientStatusRequests>();

  static Future<void> listenToApp() async {
    if (boolListenWorking) {
      return;
    }
    boolListenWorking = true;
    appRequestsToHubStreamBroadcast
        .add(appRequestsToHubStreamController.stream);
  }
}
