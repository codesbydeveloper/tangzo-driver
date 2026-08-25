import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/preferences.dart';
import 'package:driver/widget/location_disclosure_dialog.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

class DashBoardController extends GetxController {
  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit

    getUser();
    updateDriverOrder();
    getThem();
    super.onInit();
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

  Future<void> _startBackgroundLocationUpdates() async {
    location.enableBackgroundMode(enable: true);
    location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));

    location.onLocationChanged.listen((locationData) async {
      log("locationData :: ${locationData.latitude} :: ${locationData.longitude}");
      Constant.locationDataFinal = locationData;
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) async {
        if (value != null) {
          userModel.value = value;
          if (userModel.value.isActive == true) {
            userModel.value.location = UserLocation(latitude: locationData.latitude ?? 0.0, longitude: locationData.longitude ?? 0.0);
            userModel.value.rotation = locationData.heading;
            await FireStoreUtils.updateUser(userModel.value);
          }
          ShowToastDialog.closeLoader();
        }
      });
    });
  }
}
