import 'package:cbj_integrations_controller/infrastructure/gen/cbj_hub_server/protoc_as_dart/cbj_hub_server.pbenum.dart';
import 'package:cbj_integrations_controller/infrastructure/generic_devices/abstract_device/core_failures.dart';
import 'package:dartz/dartz.dart';

Either<CoreFailure<String>, String> validateGenericSmartTvStateNotEmpty(
  String input,
) {
  return right(input);
}

Either<CoreFailure<String>, String> validateGenericSmartTvUrlValidation(
  String input,
) {
  return right(input);
}

Either<CoreFailure<String>, String>
    validateGenericSmartTvPausePlayStateValidation(
  String input,
) {
  return right(input);
}

Either<CoreFailure<String>, String>
    validateGenericSmartTvSkipBackOrForwardValidation(
  String input,
) {
  return right(input);
}

Either<CoreFailure<String>, String> validateGenericSmartTvVolumeValidation(
  String input,
) {
  return right(input);
}

/// Return all the valid actions for smart tv
List<String> smartTvAllValidActions() {
  return [
    EntityActions.off.toString(),
    EntityActions.on.toString(),
    EntityActions.pausePlay.toString(),
    EntityActions.changeVolume.toString(),
    EntityActions.skip.toString(),
  ];
}
