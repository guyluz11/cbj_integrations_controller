part of 'package:cbj_integrations_controller/domain/routine/i_routine_cbj_repository.dart';

class _RoutineCbjRepository implements IRoutineCbjRepository {
  final Map<String, RoutineCbjEntity> _allRoutines = {};

  @override
  Future<void> setUpAllFromDb() async {
    await ICbjIntegrationsControllerDbRepository.instance
        .getRoutinesFromDb()
        .then((value) {
      value.fold((l) => null, (r) async {
        for (final element in r) {
          await addNewRoutine(element);
        }
      });
    });
  }

  @override
  Future<List<RoutineCbjEntity>> getAllRoutinesAsList() async {
    return _allRoutines.values.toList();
  }

  @override
  Future<Map<String, RoutineCbjEntity>> getAllRoutinesAsMap() async {
    return _allRoutines;
  }

  @override
  Future<Either<LocalDbFailures, Unit>> saveAndActivateRoutineToDb() async {
    return ICbjIntegrationsControllerDbRepository.instance.saveRoutines(
      routineList: List<RoutineCbjEntity>.from(_allRoutines.values),
    );
  }

  @override
  Future<Either<RoutineCbjFailure, Unit>> addNewRoutine(
    RoutineCbjEntity routineCbj,
  ) async {
    RoutineCbjEntity tempRoutineCbj = routineCbj;

    /// Check if routine already exist
    if (findRoutineIfAlreadyBeenAdded(tempRoutineCbj) == null) {
      _allRoutines.addEntries(
        [MapEntry(tempRoutineCbj.uniqueId.getOrCrash(), tempRoutineCbj)],
      );

      final String entityId = tempRoutineCbj.uniqueId.getOrCrash();

      /// If it is new routine
      _allRoutines[entityId] = tempRoutineCbj;

      ISavedRoomsRepo.instance
          .addRoutineToRoomDiscoveredIfNotExist(tempRoutineCbj);

      final String routineNodeRedFlowId = await NodeRedRepository.instance
          .createNewNodeRedRoutine(tempRoutineCbj);
      if (routineNodeRedFlowId.isNotEmpty) {
        tempRoutineCbj = tempRoutineCbj.copyWith(
          nodeRedFlowId: RoutineCbjNodeRedFlowId(routineNodeRedFlowId),
        );
      }
      return left(const RoutineCbjFailure.unableToUpdate());
    }
    return right(unit);
  }

  @override
  Future<Either<RoutineCbjFailure, Unit>> addNewRoutineAndSaveItToLocalDb(
    RoutineCbjEntity routineCbj,
  ) async {
    await addNewRoutine(routineCbj);
    await ISavedDevicesRepo.instance.saveAndActivateSmartDevicesToDb();
    await saveAndActivateRoutineToDb();

    return right(unit);
  }

  @override
  Future<bool> activateRoutine(
    RoutineCbjEntity routineCbj,
  ) async {
    final String fullPathOfRoutine = await getFullMqttPathOfRoutine(routineCbj);
    IMqttServerRepository.instance
        .publishMessage(fullPathOfRoutine, DateTime.now().toString());

    return true;
  }

  /// Get entity and return the full MQTT path to it
  @override
  Future<String> getFullMqttPathOfRoutine(RoutineCbjEntity routineCbj) async {
    final String hubBaseTopic =
        IMqttServerRepository.instance.getHubBaseTopic();
    final String routinesTopicTypeName =
        IMqttServerRepository.instance.getRoutinesTopicTypeName();
    final String routineId = routineCbj.firstNodeId.getOrCrash()!;

    return '$hubBaseTopic/$routinesTopicTypeName/$routineId';
  }

  /// Check if all routines does not contain the same routine already
  /// Will compare the unique id's that each company sent us
  RoutineCbjEntity? findRoutineIfAlreadyBeenAdded(
    RoutineCbjEntity routineEntity,
  ) {
    return _allRoutines[routineEntity.uniqueId.getOrCrash()];
  }

  @override
  Future<Either<RoutineCbjFailure, Unit>> activateRoutines(
    KtList<RoutineCbjEntity> routinesList,
  ) async {
    for (final RoutineCbjEntity routineCbjEntity in routinesList.asList()) {
      addOrUpdateNewRoutineInHub(
        routineCbjEntity.copyWith(
          entityStateGRPC: RoutineCbjDeviceStateGRPC(
            CbjDeviceStateGRPC.waitingInComp.toString(),
          ),
        ),
      );
    }
    return right(unit);
  }

  @override
  void addOrUpdateNewRoutineInApp(RoutineCbjEntity routineCbj) {
    _allRoutines[routineCbj.uniqueId.getOrCrash()] = routineCbj;

    routinesResponseFromTheHubStreamController.sink
        .add(_allRoutines.values.toImmutableList());
  }

  @override
  Future<void> initiateHubConnection() async {}

  @override
  Stream<Either<RoutineCbjFailure, KtList<RoutineCbjEntity>>>
      watchAllRoutines() async* {
    yield* routinesResponseFromTheHubStreamController.stream
        .map((event) => right(event));
  }

  @override
  BehaviorSubject<KtList<RoutineCbjEntity>>
      routinesResponseFromTheHubStreamController =
      BehaviorSubject<KtList<RoutineCbjEntity>>();

  @override
  Future<Either<RoutineCbjFailure, RoutineCbjEntity>>
      addOrUpdateNewRoutineInHub(
    RoutineCbjEntity routineCbjEntity,
  ) async {
    _allRoutines[routineCbjEntity.uniqueId.getOrCrash()] = routineCbjEntity;

    final ClientStatusRequests clientStatusRequests = ClientStatusRequests(
      allRemoteCommands:
          jsonEncode(routineCbjEntity.toInfrastructure().toJson()),
      sendingType: SendingType.routineType,
    );

    AppRequestsToHub.appRequestsToHubStreamController.add(clientStatusRequests);

    return right(routineCbjEntity);
  }

  @override
  Future<Either<RoutineCbjFailure, RoutineCbjEntity>>
      addOrUpdateNewRoutineInHubFromDevicesPropertyActionList(
    String routineName,
    List<MapEntry<DeviceEntityAbstract, MapEntry<String?, String?>>>
        smartDevicesWithActionToAdd,
    RoutineCbjRepeatDateDays daysToRepeat,
    RoutineCbjRepeatDateHour hourToRepeat,
    RoutineCbjRepeatDateMinute minutesToRepeat,
  ) async {
    final RoutineCbjEntity newCbjRoutine =
        NodeRedConverter.convertToRoutineNodes(
      nodeName: routineName,
      devicesPropertyAction: smartDevicesWithActionToAdd,
      daysToRepeat: daysToRepeat,
      hourToRepeat: hourToRepeat,
      minutesToRepeat: minutesToRepeat,
      routineColor: Colors.blueAccent.value,
    );
    return addOrUpdateNewRoutineInHub(newCbjRoutine);
  }

  @override
  Future<Either<RoutineCbjFailure, RoutineCbjEntity>> getRoutine() async {
    //
    // final RoutineCbj routine = RoutineCbj(
    //   uniqueId: UniqueId(),
    //   name: 'Turn on all lights out side',
    //   routinesActionsToExecute: [
    //     'Turn on all lights',
    //     ' Turn on all lights',
    //   ].toImmutableList(),
    // );
    //
    //
    // final KtList<String> routinesActionsList = [
    //   'Gut Calling',
    //   'Out Side North',
    // ].toImmutableList();

    try {
      return right(
        RoutineCbjEntity(
          uniqueId: UniqueId(),
          name: RoutineCbjName('Go to sleep ----------- 😴'),
          backgroundColor:
              RoutineCbjBackgroundColor(Colors.blue.value.toString()),
          iconCodePoint: RoutineCbjIconCodePoint(null
              // FontAwesomeIcons.school.codePoint.toString(),
              ),
          image: RoutineCbjBackgroundImage(null),
          automationString: RoutineCbjAutomationString(null),
          nodeRedFlowId: RoutineCbjNodeRedFlowId(null),
          firstNodeId: RoutineCbjFirstNodeId(null),
          lastDateOfExecute: RoutineCbjLastDateOfExecute(null),
          entityStateGRPC: RoutineCbjDeviceStateGRPC(null),
          senderDeviceModel: RoutineCbjSenderDeviceModel(null),
          senderDeviceOs: RoutineCbjSenderDeviceOs(null),
          senderId: RoutineCbjSenderId(null),
          compUuid: RoutineCbjCompUuid(null),
          stateMassage: RoutineCbjStateMassage(null),
          repeateType: RoutineCbjRepeatType(null),
          repeateDateDays: RoutineCbjRepeatDateDays(null),
          repeateDateHour: RoutineCbjRepeatDateHour(null),
          repeateDateMinute: RoutineCbjRepeatDateMinute(null),
        ),
      );
    } catch (e) {
      return left(const RoutineCbjFailure.unexpected());
    }
  }
}
