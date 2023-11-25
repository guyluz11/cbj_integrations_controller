import 'dart:convert';

import 'package:cbj_integrations_controller/domain/app_communication/i_app_communication_repository.dart';
import 'package:cbj_integrations_controller/domain/mqtt_server/i_mqtt_server_repository.dart';
import 'package:cbj_integrations_controller/domain/rooms/i_saved_rooms_repo.dart';
import 'package:cbj_integrations_controller/domain/routine/i_routine_cbj_repository.dart';
import 'package:cbj_integrations_controller/domain/routine/routine_cbj_entity.dart';
import 'package:cbj_integrations_controller/domain/routine/value_objects_routine_cbj.dart';
import 'package:cbj_integrations_controller/domain/saved_devices/i_saved_devices_repo.dart';
import 'package:cbj_integrations_controller/domain/scene/i_scene_cbj_repository.dart';
import 'package:cbj_integrations_controller/domain/scene/scene_cbj_entity.dart';
import 'package:cbj_integrations_controller/domain/scene/value_objects_scene_cbj.dart';
import 'package:cbj_integrations_controller/infrastructure/devices/device_helper/device_helper.dart';
import 'package:cbj_integrations_controller/infrastructure/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbgrpc.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/device_entity_abstract.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/device_entity_dto_abstract.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/value_objects_core.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_vendors_login/generic_login_abstract/login_entity_dto_abstract.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_vendors_login/vendor_helper.dart';
import 'package:cbj_integrations_controller/infrastructure/remote_pipes/remote_pipes_dtos.dart';
import 'package:cbj_integrations_controller/infrastructure/room/room_entity_dtos.dart';
import 'package:cbj_integrations_controller/infrastructure/routines/routine_cbj_dtos.dart';
import 'package:cbj_integrations_controller/infrastructure/scenes/scene_cbj_dtos.dart';
import 'package:cbj_integrations_controller/utils.dart';

class DeviceHelperMethods {
  static RequestsAndStatusFromHub dynamicToRequestsAndStatusFromHub(
      dynamic entityDto) {
    if (entityDto is DeviceEntityDtoAbstract) {
      return RequestsAndStatusFromHub(
        sendingType: SendingType.entityType,
        allRemoteCommands: DeviceHelper.convertDtoToJsonString(entityDto),
      );
    } else if (entityDto is RoomEntityDtos) {
      return RequestsAndStatusFromHub(
        sendingType: SendingType.roomType,
        allRemoteCommands: jsonEncode(entityDto.toJson()),
      );
    } else if (entityDto is SceneCbjDtos) {
      return RequestsAndStatusFromHub(
        sendingType: SendingType.sceneType,
        allRemoteCommands: jsonEncode(entityDto.toJson()),
      );
    } else if (entityDto is RoutineCbjDtos) {
      return RequestsAndStatusFromHub(
        sendingType: SendingType.routineType,
        allRemoteCommands: jsonEncode(entityDto.toJson()),
      );
    } else {
      logger.w('Not sure what type to send');
      return RequestsAndStatusFromHub(
        sendingType: SendingType.undefinedType,
        allRemoteCommands: '',
      );
    }
  }

  static dynamic clientStatusRequestsToItsDtosType(
      ClientStatusRequests clientStatusRequests) {
    clientStatusRequests.sendingType;

    if (clientStatusRequests.sendingType == SendingType.entityType) {
      return DeviceHelper.convertJsonStringToDomain(
          clientStatusRequests.allRemoteCommands);
    } else if (clientStatusRequests.sendingType == SendingType.roomType) {
      return RoomEntityDtos.fromJson(
        jsonDecode(clientStatusRequests.allRemoteCommands)
            as Map<String, dynamic>,
      );
    } else if (clientStatusRequests.sendingType ==
        SendingType.vendorLoginType) {
      return VendorHelper.convertJsonStringToDomain(
          clientStatusRequests.allRemoteCommands);
    } else if (clientStatusRequests.sendingType ==
        SendingType.remotePipesInformation) {
      final Map<String, dynamic> jsonDecoded =
          jsonDecode(clientStatusRequests.allRemoteCommands)
              as Map<String, dynamic>;

      return RemotePipesDtos.fromJson(jsonDecoded);
    } else if (clientStatusRequests.sendingType == SendingType.sceneType) {
      final Map<String, dynamic> jsonSceneFromJsonString =
          jsonDecode(clientStatusRequests.allRemoteCommands)
              as Map<String, dynamic>;

      return SceneCbjDtos.fromJson(jsonSceneFromJsonString);
    } else if (clientStatusRequests.sendingType == SendingType.routineType) {
      final Map<String, dynamic> jsonRoutineFromJsonString =
          jsonDecode(clientStatusRequests.allRemoteCommands)
              as Map<String, dynamic>;

      return RoutineCbjDtos.fromJson(jsonRoutineFromJsonString);
    } else {
      logger.w('Request from app does not support this sending device type');
    }

    return null;
  }

  static Future handleClientStatusRequests(
      ClientStatusRequests clientStatusRequests) async {
    logger.i('Got From App');

    dynamic dtosEntity =
        clientStatusRequestsToItsDtosType(clientStatusRequests);

    if (dtosEntity is DeviceEntityDtoAbstract) {
      DeviceEntityAbstract deviceEntityAbstract = dtosEntity.toDomain();
      deviceEntityAbstract.entityStateGRPC =
          EntityState(EntityStateGRPC.waitingInComp.toString());

      IMqttServerRepository.instance.postToHubMqtt(
        entityFromTheApp: deviceEntityAbstract,
        gotFromApp: true,
      );
    } else if (dtosEntity is RoomEntityDtos) {
      ISavedRoomsRepo.instance.saveAndActiveRoomToDb(
        roomEntity: dtosEntity.toDomain(),
      );

      IMqttServerRepository.instance.postToHubMqtt(
        entityFromTheApp: dtosEntity,
        gotFromApp: true,
      );
    } else if (dtosEntity is LoginEntityDtoAbstract) {
      ISavedDevicesRepo.instance
          .saveAndActivateVendorLoginCredentialsDomainToDb(
        loginEntity: dtosEntity.toDomain(),
      );
    } else if (clientStatusRequests.sendingType ==
        SendingType.firstConnection) {
      IAppCommunicationRepository.instance.sendAllRoomsFromHubRequestsStream();
      IAppCommunicationRepository.instance
          .sendAllDevicesFromHubRequestsStream();
      IAppCommunicationRepository.instance.sendAllScenesFromHubRequestsStream();
    } else if (dtosEntity is RemotePipesDtos) {
      ISavedDevicesRepo.instance.saveAndActivateRemotePipesDomainToDb(
          remotePipes: dtosEntity.toDomain());
    } else if (dtosEntity is SceneCbjDtos) {
      final SceneCbjEntity sceneCbj = dtosEntity.toDomain();

      final String sceneStateGrpcTemp = sceneCbj.entityStateGRPC.getOrCrash()!;

      sceneCbj.copyWith(
        entityStateGRPC: SceneCbjDeviceStateGRPC(
          EntityStateGRPC.waitingInComp.toString(),
        ),
      );

      if (sceneStateGrpcTemp == EntityStateGRPC.addingNewScene.toString()) {
        ISceneCbjRepository.instance.addNewSceneAndSaveInDb(sceneCbj);
      } else {
        ISceneCbjRepository.instance.activateScene(sceneCbj);
      }
    } else if (dtosEntity is RoutineCbjDtos) {
      final RoutineCbjEntity routineCbj = dtosEntity.toDomain();

      final String routineStateGrpcTemp =
          routineCbj.entityStateGRPC.getOrCrash()!;

      routineCbj.copyWith(
        entityStateGRPC: RoutineCbjDeviceStateGRPC(
          EntityStateGRPC.waitingInComp.toString(),
        ),
      );

      if (routineStateGrpcTemp == EntityStateGRPC.addingNewRoutine.toString()) {
        IRoutineCbjRepository.instance
            .addNewRoutineAndSaveItToLocalDb(routineCbj);
      } else {
        // For a way to active it manually
        // IRoutineCbjRepository.instance.activateRoutine(routineCbj);
      }
    } else {
      logger.w('Request from app does not support this sending device type');
    }
  }
}
