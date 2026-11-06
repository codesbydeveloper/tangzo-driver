import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class DeliverOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool conformPickup = false.obs;
  RxBool isCompleting = false.obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  RxInt totalQuantity = 0.obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
      for (var element in orderModel.value.products!) {
        totalQuantity.value += (element.quantity ?? 0);
      }
    }
    isLoading.value = false;
  }

  Future<void> completedOrder() async {
    if (isCompleting.value) return;
    isCompleting.value = true;
    ShowToastDialog.showLoader("Please wait");

    try {
      await AudioPlayerService.playSound(false);
      orderModel.value.status = Constant.orderCompleted;
      await FireStoreUtils.setOrder(orderModel.value);

      // Finish wallet / side-effects BEFORE freeing the driver.
      // Freeing early lets cloud functions assign the next order while
      // EasyLoading is still up, which blocks Accept/Reject.
      if (orderModel.value.isFreeDelivery == false) {
        try {
          await FireStoreUtils.updateWallateAmount(orderModel.value);
        } catch (e, s) {
          log('updateWallateAmount failed: $e\n$s');
        }
      }

      if (orderModel.value.cashback?.cashbackValue != null && orderModel.value.cashback?.id != null) {
        try {
          final cashbackValue = double.parse("${orderModel.value.cashback?.cashbackValue ?? 0.0}");
          final transactionModel = WalletTransactionModel(
            id: Constant.getUuid(),
            amount: cashbackValue,
            date: Timestamp.now(),
            paymentMethod: "Cashback Amount",
            transactionUser: "user",
            userId: orderModel.value.author?.id,
            isTopup: true,
            orderId: orderModel.value.id,
            note: "Cashback Amount",
            paymentStatus: "success",
          );
          final added = await FireStoreUtils.setWalletTransaction(transactionModel);
          if (added == true && orderModel.value.author?.id != null) {
            await FireStoreUtils.updateUserWallet(
              amount: cashbackValue.toString(),
              userId: orderModel.value.author!.id.toString(),
            );
          }
        } catch (e, s) {
          log('cashback credit failed: $e\n$s');
        }
      }

      try {
        await SendNotification.sendFcmMessage(
          Constant.driverCompleted,
          orderModel.value.author?.fcmToken ?? '',
          {},
        );
      } catch (e, s) {
        log('completion notification failed: $e\n$s');
      }

      try {
        final isFirst = await FireStoreUtils.getFirestOrderOrNOt(orderModel.value);
        if (isFirst == true) {
          await FireStoreUtils.updateReferralAmount(orderModel.value);
        }
      } catch (e, s) {
        log('referral update failed: $e\n$s');
      }
    } catch (e, s) {
      log('completedOrder failed: $e\n$s');
      ShowToastDialog.showToast("Something went wrong. Please try again.");
      isCompleting.value = false;
      ShowToastDialog.closeLoader();
      return;
    } finally {
      ShowToastDialog.closeLoader();
    }

    // Leave deliver screen first so Accept/Reject is not under the loader.
    Get.back(result: Constant.userModel);

    // Free driver AFTER UI is clear — this may trigger next-order assignment.
    try {
      Constant.userModel?.orderRequestData?.remove(orderModel.value.id);
      Constant.userModel?.inProgressOrderID?.remove(orderModel.value.id);
      if (Constant.userModel != null) {
        await FireStoreUtils.updateUser(Constant.userModel!);
      }
    } catch (e, s) {
      log('free driver after complete failed: $e\n$s');
    }

    isCompleting.value = false;
  }
}
