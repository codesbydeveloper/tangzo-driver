import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_realtime_api.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/preferences.dart';
import 'package:driver/widget/location_disclosure_dialog.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

class DashBoardController extends GetxController {
  RxInt drawerIndex = 0.obs;

  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationHeartbeatTimer;

  bool _locationUpdateInFlight = false;
  DateTime? _lastRedisPublishAt;
  _PendingLocation? _pendingRedisLocation;

  /// Phase 2A: do not raise GPS frequency. Keep admin distance filter.
  /// Only throttle Redis *publishes* and coalesce bursts.
  static const Duration _minRedisPublishInterval = Duration(seconds: 8);

  /// Redis location TTL is ~90s. Re-publish last known coords while online so
  /// keys do not expire when the driver is nearly stationary (distanceFilter silent).
  static const Duration _redisHeartbeatInterval = Duration(seconds: 45);

  @override
  void onInit() {
    getUser();
    updateDriverOrder();
    getThem();
    super.onInit();
  }

  @override
  void onClose() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationHeartbeatTimer?.cancel();
    _locationHeartbeatTimer = null;
    super.onClose();
  }

  Rx<UserModel> userModel = UserModel().obs;

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;

  Future<void> getUser() async {
    // Wait for UI so the prominent disclosure dialog can present.
    await SchedulerBinding.instance.endOfFrame;
    await updateCurrentLocation();
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = UserModel.fromJson(event.data()!);
        }
      },
    );
  }

  RxString isDarkMode = "Light".obs;
  RxBool isDarkModeSwitch = false.obs;

  void getThem() {
    isDarkMode.value = Preferences.getString(Preferences.themKey);
    if (isDarkMode.value == "Dark") {
      isDarkModeSwitch.value = true;
    } else if (isDarkMode.value == "Light") {
      isDarkModeSwitch.value = false;
    } else {
      isDarkModeSwitch.value = false;
    }
  }

  Future<void> updateDriverOrder() async {
    Timestamp startTimestamp = Timestamp.now();
    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(const Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<OrderModel> orders = [];

    await FireStoreUtils.fireStore
        .collection(CollectionName.restaurantOrders)
        .where('status', whereIn: [Constant.orderAccepted, Constant.orderRejected])
        .where('createdAt', isGreaterThan: startTimestamp)
        .get()
        .then((value) async {
          await Future.forEach(value.docs, (QueryDocumentSnapshot<Map<String, dynamic>> element) {
            try {
              orders.add(OrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) async {
      OrderModel orderModel = element;
      orderModel.triggerDelivery = Timestamp.now();
      await FireStoreUtils.setOrder(orderModel);
    });
  }

  Location location = Location();

  Future<void> updateCurrentLocation() async {
    try {
      // Google Play: show prominent disclosure before any background-location access.
      final consented = await LocationDisclosureDialog.ensureConsent();
      if (!consented) {
        ShowToastDialog.closeLoader();
        return;
      }

      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
      }

      if (permissionStatus == PermissionStatus.granted) {
        await _startBackgroundLocationUpdates();
      } else {
        ShowToastDialog.closeLoader();
      }
    } catch (e) {
      print(e);
    }
  }

  /// Online/offline toggle: durable Firestore isActive + Redis presence (Phase 3).
  Future<void> setAvailableStatus(bool isOnline) async {
    userModel.value.isActive = isOnline;
    userModel.value.inProgressOrderID = Constant.userModel?.inProgressOrderID ?? userModel.value.inProgressOrderID;
    userModel.value.orderRequestData = Constant.userModel?.orderRequestData ?? userModel.value.orderRequestData;

    await FireStoreUtils.updateUser(userModel.value);
    Constant.userModel = userModel.value;

    if (Constant.useRedisDriverPresence) {
      if (isOnline) {
        final ok = await DriverRealtimeApi.setDriverPresence();
        if (!ok) {
          log('Redis setDriverPresence failed (Firestore isActive still saved).');
        }
        await updateCurrentLocation();
      } else {
        final ok = await DriverRealtimeApi.clearDriverPresence();
        if (!ok) {
          log('Redis clearDriverPresence failed (Firestore isActive still saved).');
        }
      }
    } else if (isOnline) {
      await updateCurrentLocation();
    }
  }

  double _distanceFilterMeters() {
    final parsed = double.tryParse(Constant.driverLocationUpdate);
    // Keep configured value; fall back to historical default 50m.
    // Do not lower this just because Redis exists (would increase GPS/CF load).
    if (parsed == null || parsed < 0) {
      return 50;
    }
    return parsed;
  }

  bool _isDriverActive() {
    return userModel.value.isActive == true || Constant.userModel?.isActive == true;
  }

  Future<void> _startBackgroundLocationUpdates() async {
    location.enableBackgroundMode(enable: true);
    location.changeSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterMeters(),
    );

    await _locationSubscription?.cancel();
    _locationHeartbeatTimer?.cancel();

    _locationSubscription = location.onLocationChanged.listen((locationData) async {
      log("locationData :: ${locationData.latitude} :: ${locationData.longitude}");
      Constant.locationDataFinal = locationData;

      if (!_isDriverActive()) {
        ShowToastDialog.closeLoader();
        return;
      }

      final double lat = locationData.latitude ?? 0.0;
      final double lng = locationData.longitude ?? 0.0;
      final double heading = locationData.heading ?? 0.0;

      // Local UI always gets the freshest fix (no backend cost).
      userModel.value.location = UserLocation(latitude: lat, longitude: lng);
      userModel.value.rotation = heading;
      if (Constant.userModel != null) {
        Constant.userModel!.location = UserLocation(latitude: lat, longitude: lng);
        Constant.userModel!.rotation = heading;
      }

      if (Constant.useRedisDriverLocation) {
        await _enqueueRedisLocationPublish(
          latitude: lat,
          longitude: lng,
          heading: heading,
        );
        ShowToastDialog.closeLoader();
        return;
      }

      // Rollback path: previous Firestore full-document location write.
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) async {
        if (value != null) {
          userModel.value = value;
          if (userModel.value.isActive == true) {
            userModel.value.location = UserLocation(latitude: lat, longitude: lng);
            userModel.value.rotation = heading;
            await FireStoreUtils.updateUser(userModel.value);
          }
          ShowToastDialog.closeLoader();
        }
      });
    });

    if (Constant.useRedisDriverLocation) {
      _locationHeartbeatTimer = Timer.periodic(_redisHeartbeatInterval, (_) {
        _maybeHeartbeatRedisLocation();
      });
    }
  }

  /// Coalesce + min-interval gate for Redis publishes (Phase 2A).
  Future<void> _enqueueRedisLocationPublish({
    required double latitude,
    required double longitude,
    required double heading,
  }) async {
    _pendingRedisLocation = _PendingLocation(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
    );
    await _flushRedisLocationPublish();
  }

  Future<void> _flushRedisLocationPublish() async {
    if (!Constant.useRedisDriverLocation || !_isDriverActive()) {
      _pendingRedisLocation = null;
      return;
    }
    if (_locationUpdateInFlight) {
      return;
    }

    final pending = _pendingRedisLocation;
    if (pending == null) {
      return;
    }

    final last = _lastRedisPublishAt;
    if (last != null && DateTime.now().difference(last) < _minRedisPublishInterval) {
      // Latest coords stay in _pendingRedisLocation; heartbeat or next tick will flush.
      return;
    }

    _locationUpdateInFlight = true;
    _pendingRedisLocation = null;
    try {
      final ok = await DriverRealtimeApi.updateDriverLocation(
        latitude: pending.latitude,
        longitude: pending.longitude,
        heading: pending.heading,
      );
      if (ok) {
        _lastRedisPublishAt = DateTime.now();
      } else {
        // Keep last known for retry via heartbeat / next GPS event.
        _pendingRedisLocation ??= pending;
        log('Redis location publish failed (Firestore GPS write skipped).');
      }
    } finally {
      _locationUpdateInFlight = false;
      // If newer coords arrived while in-flight, publish them (still subject to min interval).
      if (_pendingRedisLocation != null) {
        await _flushRedisLocationPublish();
      }
    }
  }

  void _maybeHeartbeatRedisLocation() {
    if (!Constant.useRedisDriverLocation || !_isDriverActive()) {
      return;
    }
    final gps = Constant.locationDataFinal;
    if (gps?.latitude == null || gps?.longitude == null) {
      return;
    }

    final last = _lastRedisPublishAt;
    if (last != null && DateTime.now().difference(last) < _redisHeartbeatInterval) {
      return;
    }

    _enqueueRedisLocationPublish(
      latitude: gps!.latitude!,
      longitude: gps.longitude!,
      heading: gps.heading ?? 0.0,
    );
  }
}

class _PendingLocation {
  final double latitude;
  final double longitude;
  final double heading;

  const _PendingLocation({
    required this.latitude,
    required this.longitude,
    required this.heading,
  });
}
