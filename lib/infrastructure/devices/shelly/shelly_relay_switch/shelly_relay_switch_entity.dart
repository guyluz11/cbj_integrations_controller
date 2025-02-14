import 'dart:async';

import 'package:cbj_integrations_controller/infrastructure/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbenum.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/core_failures.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/device_entity_abstract.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/value_objects_core.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/device_type_enums.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/generic_switch_device/generic_switch_entity.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/generic_switch_device/generic_switch_value_objects.dart';
import 'package:cbj_integrations_controller/utils.dart';
import 'package:dartz/dartz.dart';
import 'package:shelly/shelly.dart';

class ShellyRelaySwitchEntity extends GenericSwitchDE {
  ShellyRelaySwitchEntity({
    required super.uniqueId,
    required super.entityUniqueId,
    required super.cbjEntityName,
    required super.entityOriginalName,
    required super.deviceOriginalName,
    required super.stateMassage,
    required super.senderDeviceOs,
    required super.senderDeviceModel,
    required super.senderId,
    required super.compUuid,
    required super.entityStateGRPC,
    required super.powerConsumption,
    required super.deviceUniqueId,
    required super.devicePort,
    required super.deviceLastKnownIp,
    required super.deviceHostName,
    required super.deviceMdns,
    required super.devicesMacAddress,
    required super.entityKey,
    required super.requestTimeStamp,
    required super.lastResponseFromDeviceTimeStamp,
    required super.deviceCbjUniqueId,
    required super.switchState,
  }) : super(
          deviceVendor: DeviceVendor(VendorsAndServices.shelly.toString()),
        ) {
    shellyRelaySwitch = ShellyApiRelaySwitch(
      lastKnownIp: deviceLastKnownIp.getOrCrash(),
      mDnsName: deviceMdns.getOrCrash(),
      hostName: deviceHostName.getOrCrash(),
    );
  }

  late ShellyApiRelaySwitch shellyRelaySwitch;

  @override
  Future<Either<CoreFailure, Unit>> executeDeviceAction({
    required DeviceEntityAbstract newEntity,
  }) async {
    if (newEntity is! GenericSwitchDE) {
      return left(
        const CoreFailure.actionExcecuter(
          failedValue: 'Not the correct type',
        ),
      );
    }

    try {
      if (newEntity.switchState!.getOrCrash() != switchState!.getOrCrash() ||
          entityStateGRPC.getOrCrash() != EntityStateGRPC.ack.toString()) {
        final EntityActions? actionToPreform =
            EnumHelperCbj.stringToDeviceAction(
          newEntity.switchState!.getOrCrash(),
        );

        if (actionToPreform == EntityActions.on) {
          (await turnOnSwitch()).fold(
            (l) {
              logger.e('Error turning Shelly switch on\n$l');
              throw l;
            },
            (r) {
              logger.i('Shelly switch turn on success');
            },
          );
        } else if (actionToPreform == EntityActions.off) {
          (await turnOffSwitch()).fold(
            (l) {
              logger.e('Error turning Shelly off\n$l');
              throw l;
            },
            (r) {
              logger.i('Shelly switch turn off success');
            },
          );
        } else {
          logger.w(
            'actionToPreform is not set correctly on Shelly Switch',
          );
        }
      }
      entityStateGRPC = EntityState(EntityStateGRPC.ack.toString());
      // IMqttServerRepository.instance.postSmartDeviceToAppMqtt(
      //   entityFromTheHub: this,
      // );
      return right(unit);
    } catch (e) {
      entityStateGRPC = EntityState(EntityStateGRPC.newStateFailed.toString());
      // IMqttServerRepository.instance.postSmartDeviceToAppMqtt(
      //   entityFromTheHub: this,
      // );
      return left(const CoreFailure.unexpected());
    }
  }

  @override
  Future<Either<CoreFailure, Unit>> turnOnSwitch() async {
    switchState = GenericSwitchSwitchState(EntityActions.on.toString());

    try {
      logger.t('Turn on Shelly device');
      shellyRelaySwitch.turnOn();
      return right(unit);
    } catch (e) {
      return left(const CoreFailure.unexpected());
    }
  }

  @override
  Future<Either<CoreFailure, Unit>> turnOffSwitch() async {
    switchState = GenericSwitchSwitchState(EntityActions.off.toString());

    try {
      logger.t('Turn off Shelly device');
      await shellyRelaySwitch.turnOff();
      return right(unit);
    } catch (exception) {
      return left(const CoreFailure.unexpected());
    }
  }
}
