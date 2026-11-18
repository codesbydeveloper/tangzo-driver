import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/driver_cashback_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class HomeScreenMultipleOrderController extends GetxController {
  Rx<UserModel> driverModel = Constant.userModel!.obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  @override
  void onInit() {
    // TODO: implement onInt
    getDriver();
    super.onInit();
  }

  Future<void> getDriver() async {
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = driverModel.value;
          newOrder.clear();
          activeOrder.clear();
          if (driverModel.value.orderRequestData != null) {
            for (var element in driverModel.value.orderRequestData!) {
              newOrder.add(element);
            }
          }

          if (driverModel.value.inProgressOrderID != null) {
            for (var element in driverModel.value.inProgressOrderID!) {
              activeOrder.add(element);
            }
          }
          if (driverModel.value.vendorID?.isEmpty == true) {
            if (newOrder.isEmpty == true) {
              await AudioPlayerService.playSound(false);
            } else {
              await AudioPlayerService.playSound(true);
            }
          }
        }
      },
    );
    isLoading.value = false;
  }

  Future<void> acceptOrder(OrderModel currentOrder) async {
    ShowToastDialog.showLoader("Please wait");
    await AudioPlayerService.playSound(false);

    final orderId = currentOrder.id;
    if (orderId == null || orderId.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Order already assigned");
      return;
    }
    final fresh = await FireStoreUtils.getOrderById(orderId);
    if (fresh == null ||
        fresh.status == Constant.noRiderAvailable ||
        fresh.status == Constant.orderCancelled ||
        fresh.status == Constant.orderRejected ||
        (fresh.driverID != null &&
            fresh.driverID!.isNotEmpty &&
            fresh.driverID != driverModel.value.id)) {
      driverModel.value.orderRequestData?.remove(orderId);
      driverModel.value.inProgressOrderID?.remove(orderId);
      await FireStoreUtils.updateUser(driverModel.value);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Order already assigned");
      return;
    }

    driverModel.value.inProgressOrderID ?? [];
    driverModel.value.orderRequestData?.remove(currentOrder.id);
    driverModel.value.inProgressOrderID?.add(currentOrder.id);

    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.status = Constant.driverAccepted;
    currentOrder.driverID = driverModel.value.id;
    currentOrder.driver = driverModel.value;
    final withCashback = await DriverCashbackService.attachIfEligible(
      order: currentOrder,
      driverId: driverModel.value.id ?? '',
    );
    await FireStoreUtils.setOrder(withCashback);
    await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.author!.fcmToken.toString(), {});
    await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.vendor!.fcmToken.toString(), {});
    ShowToastDialog.closeLoader();
    final cb = withCashback.driverCashback?.cashbackValue ?? 0;
    if (cb > 0) {
      ShowToastDialog.showToast(
        "You'll get ${Constant.amountShow(amount: cb.toString())} cashback",
      );
    }
  }

  Future<void> rejectOrder(OrderModel currentOrder) async {
    ShowToastDialog.showLoader("Please wait");
    await AudioPlayerService.playSound(false);
    currentOrder.rejectedByDrivers?.add(driverModel.value.id);
    // currentOrder.status = Constant.driverRejected;
    final cleared = await DriverCashbackService.clearForOrder(currentOrder);
    await FireStoreUtils.setOrder(cleared);
    driverModel.value.orderRequestData?.remove(currentOrder.id);
    await FireStoreUtils.updateUser(driverModel.value);
    ShowToastDialog.closeLoader();
  }
}
