import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class OrderListController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool isLoadingMore = false.obs;
  RxBool hasMore = true.obs;

  static const int pageSize = 20;
  DocumentSnapshot? _lastDoc;

  @override
  void onInit() {
    getOrder(reset: true);
    super.onInit();
  }

  RxList<OrderModel> orderList = <OrderModel>[].obs;

  Future<void> getOrder({bool reset = true}) async {
    if (reset) {
      isLoading.value = true;
      orderList.clear();
      _lastDoc = null;
      hasMore.value = true;
    } else {
      if (!hasMore.value || isLoadingMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      Query query = FireStoreUtils.fireStore
          .collection(CollectionName.restaurantOrders)
          .where('driverID', isEqualTo: Constant.userModel!.id.toString())
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
      if (!reset && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }
      final value = await query.get();
      for (var element in value.docs) {
        orderList.add(OrderModel.fromJson(element.data() as Map<String, dynamic>));
      }
      if (value.docs.isNotEmpty) {
        _lastDoc = value.docs.last;
      }
      if (value.docs.length < pageSize) {
        hasMore.value = false;
      }
    } catch (error) {
      log(error.toString());
    }

    isLoading.value = false;
    isLoadingMore.value = false;
  }

  Future<void> loadMore() => getOrder(reset: false);
}
