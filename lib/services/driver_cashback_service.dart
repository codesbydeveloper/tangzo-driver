import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/models/driver_cashback_model.dart';
import 'package:driver/models/driver_cashback_redeem_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// Select / attach / clear Tangzo-driver cashback on orders.
class DriverCashbackService {
  DriverCashbackService._();

  /// Inclusive calendar-day window (admin date pickers store midnight timestamps).
  static bool _isWithinOfferDates(Timestamp? start, Timestamp? end, DateTime now) {
    if (start == null || end == null) return false;
    final startDay = DateTime(start.toDate().year, start.toDate().month, start.toDate().day);
    final endDay = DateTime(end.toDate().year, end.toDate().month, end.toDate().day, 23, 59, 59, 999);
    return !now.isBefore(startDay) && !now.isAfter(endDay);
  }

  /// Picks best enabled offer for [driverId] based on delivery charge.
  /// Returns null when inactive or no eligible offer.
  static Future<DriverCashbackModel?> selectBestOffer({
    required OrderModel order,
    required String driverId,
  }) async {
    // Always refresh flag from Firestore (Redis settings bundle may omit this doc).
    final enabled = await FireStoreUtils.refreshDriverCashbackOfferEnabled();
    if (enabled != true) {
      log('driver cashback skipped: settings/driverCashbackOffer.isEnable != true');
      return null;
    }
    if (driverId.isEmpty) return null;

    final deliveryCharge = double.tryParse("${order.deliveryCharge ?? 0}") ?? 0.0;
    final paymentMethod = order.paymentMethod ?? '';
    final now = DateTime.now();

    final offers = await FireStoreUtils.getAllDriverCashbacks();
    final eligible = <DriverCashbackModel>[];

    for (final offer in offers) {
      if (offer.isEnabled != true) continue;
      final withinDateRange = _isWithinOfferDates(offer.startDate, offer.endDate, now);
      final meetsMin = deliveryCharge >= (offer.minimumPurchaseAmount ?? 0);
      final allPayment = offer.allPayment ?? false;
      final paymentMatch =
          allPayment || (offer.paymentMethods ?? []).contains(paymentMethod);
      final allDrivers = offer.allDrivers ?? false;
      final driverMatch =
          allDrivers || (offer.driverIds ?? []).contains(driverId);

      final redeemData =
          await FireStoreUtils.getDriverRedeemedCashbacks(offer.id ?? '', driverId);
      final underLimit = redeemData.length < (offer.redeemLimit ?? 0);

      if (withinDateRange &&
          meetsMin &&
          paymentMatch &&
          driverMatch &&
          underLimit) {
        eligible.add(offer);
      }
    }

    DriverCashbackModel? best;
    double maxValue = 0.0;
    for (final offer in eligible) {
      double value = 0.0;
      if (offer.cashbackType == 'Percent') {
        value = ((offer.cashbackAmount ?? 0.0) / 100.0) * deliveryCharge;
      } else if (offer.cashbackType == 'Fixed') {
        value = offer.cashbackAmount ?? 0.0;
      }
      final maxDiscount = offer.maximumDiscount ?? value;
      if (value > maxDiscount) value = maxDiscount;
      if (value > maxValue) {
        maxValue = value;
        best = offer;
      }
    }

    if (best == null || best.id == null || maxValue <= 0) {
      log(
        'driver cashback: no eligible offer '
        '(offers=${offers.length}, deliveryCharge=$deliveryCharge, payment=$paymentMethod)',
      );
      return null;
    }
    best.cashbackValue = maxValue;
    return best;
  }

  /// Attaches offer + redeem ledger after Tangzo driver accept/assign.
  /// Idempotent when the same driver already has cashback on the order.
  static Future<OrderModel> attachIfEligible({
    required OrderModel order,
    required String driverId,
  }) async {
    if (order.driverCashback?.id != null &&
        order.driverID == driverId &&
        (order.driverCashback?.cashbackValue ?? 0) > 0) {
      return order;
    }

    try {
      final best = await selectBestOffer(order: order, driverId: driverId);
      if (best == null) {
        order.driverCashback = null;
        return order;
      }

      order.driverCashback = best;
      final redeem = DriverCashbackRedeemModel(
        id: Constant.getUuid(),
        cashbackId: best.id,
        userId: driverId,
        orderId: order.id,
        createdAt: Timestamp.now(),
      );
      await FireStoreUtils.setDriverCashbackRedeem(redeem);
      log('driver cashback attached: ${best.id} value=${best.cashbackValue}');
    } catch (e, s) {
      log('driver cashback attach failed: $e\n$s');
    }
    return order;
  }

  /// Clears embed + redeem docs so a later driver can earn a new offer.
  static Future<OrderModel> clearForOrder(OrderModel order) async {
    try {
      await FireStoreUtils.deleteDriverCashbackRedeem(order);
    } catch (_) {}
    order.driverCashback = null;
    return order;
  }
}
