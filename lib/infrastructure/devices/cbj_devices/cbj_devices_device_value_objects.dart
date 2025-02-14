import 'package:cbj_integrations_controller/infrastructure/devices/cbj_devices/cbj_devices_device_validators.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/core_failures.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/value_objects_core.dart';
import 'package:dartz/dartz.dart';

/// CbjDevices communication port
class CbjDevicesPort extends ValueObjectCore<String> {
  factory CbjDevicesPort(String? input) {
    assert(input != null);
    return CbjDevicesPort._(
      validateCbjDevicesPortNotEmpty(input!),
    );
  }

  const CbjDevicesPort._(this.value);

  @override
  final Either<CoreFailure<String>, String> value;
}

/// CbjDevices communication port
class CbjDevicesMacAddress extends ValueObjectCore<String> {
  factory CbjDevicesMacAddress(String? input) {
    assert(input != null);
    return CbjDevicesMacAddress._(
      validateCbjDevicesMacAddressNotEmpty(input!),
    );
  }

  const CbjDevicesMacAddress._(this.value);

  @override
  final Either<CoreFailure<String>, String> value;
}
