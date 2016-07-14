public class ShiftVehicleOrders {

    @TestVisible static final String VEHICLE_SALE_CANNOT_COMPLETE_ERROR = 'Vehicle sale can only be complete if both of "Final Sale Price", and "Taxes And Registration" are specified and there is at least one payment';

	// An "open vehicle" is a vehicle with an order that has a non-returned deposit or purchase.
	private static Set<Id> getOpenVehicleIDs(List<Vehicle_Order__c> excludedVehicleOrders) {
		// First, extract vehicle order IDs and vehicle IDs into their own collections.
		List<Id> excludedVehicleOrderIDs = new List<Id>();
		Set<Id> vehicleIDs = new Set<Id>();
		for (Vehicle_Order__c vo : excludedVehicleOrders) {
			excludedVehicleOrderIDs.add(vo.Id);
			vehicleIDs.add(vo.Vehicle_ID__c);
		}

		// Next, get a list of all open vehicle orders associated with
		// the given list of vehicle orders. Orders in the given list are excluded.
		List<Vehicle_Order__c> openVehicleOrders = new List<Vehicle_Order__c>(
			[SELECT Vehicle_ID__c
				FROM Vehicle_Order__c
				WHERE
					Vehicle_ID__c IN :vehicleIDs AND
					Id NOT IN :excludedVehicleOrderIDs AND
					((Deposit__c = TRUE AND Deposit_Returned__c = FALSE AND Deposit_Expired__c = FALSE) OR (Vehicle_Purchased__c = TRUE AND Vehicle_Returned__c = FALSE))
		]);

		// Finally, extract the vehicle IDs from the open orders.
		Set<Id> openVehicleIDs = new Set<Id>();
		for (Vehicle_Order__c vo : openVehicleOrders) {
			openVehicleIDs.add(vo.Vehicle_ID__c);
		}
		return openVehicleIDs;
	}

	private static void validateOpenVehicleOrders(List<Vehicle_Order__c> vehicleOrders) {
		Set<Id> openVehicleIDs = getOpenVehicleIDs(vehicleOrders);
		Map<Id, Vehicle_Order__c> completedOrders = new Map<Id, Vehicle_Order__c>();
		for (Vehicle_Order__c vo : vehicleOrders) {
			// Ensure that the vehicle order doesn't have an invalid field configuration.
			if (vo.Deposit_Returned__c && vo.Deposit_Expired__c) {
				vo.Deposit_Returned__c.addError('Cannot insert vehicle order with deposit returned and deposit expired, only one can apply');
				continue;
			}

			if (vo.Deposit_Returned__c && !vo.Deposit__c) {
				vo.Deposit_Returned__c.addError('Cannot insert vehicle order with deposit returned but no deposit');
				continue;
			}

			if (vo.Deposit_Expired__c && !vo.Deposit__c) {
				vo.Deposit_Expired__c.addError('Cannot insert vehicle order with deposit expired but no deposit');
				continue;
			}

			if (vo.Vehicle_Returned__c && !vo.Vehicle_Purchased__c) {
				vo.Vehicle_Returned__c.addError('Cannot insert vehicle order with vehicle returned but no vehicle purchased');
				continue;
			}

			// If this vehicle order has an open deposit or an open purchase,
			// no other vehicle orders can.	Prevent the operation if one does.
			Boolean hasOpenDeposit = (vo.Deposit__c && !vo.Deposit_Returned__c && !vo.Deposit_Expired__c);
			Boolean hasOpenPurchase = (vo.Vehicle_Purchased__c && !vo.Vehicle_Returned__c);
			if (openVehicleIDs.contains(vo.Vehicle_ID__c) && (hasOpenDeposit || hasOpenPurchase)) {
				vo.addError('Vehicle already has an open order; cannot add another vehicle order with an open order');
				continue;
			}

			// Ensure that the vehicle order has both or neither
			// of the following fields set.
			Integer nullSaleFields = 0;
			if (vo.Final_Sale_Price__c == null) {
				nullSaleFields++;
			}
			if (vo.Taxes_And_Registration__c == null) {
				nullSaleFields++;
			}
			if (nullSaleFields > 0 && nullSaleFields < 2) {
				vo.addError('Vehicle order must have both or neither of \"Sale Price\", and \"Taxes And Registration\"');
				continue;
			}

			if (vo.Vehicle_Sale_Complete__c) {
				if (nullSaleFields > 0) {
					vo.Vehicle_Sale_Complete__c.addError(VEHICLE_SALE_CANNOT_COMPLETE_ERROR);
					continue;
				}
				if (vo.Payment_Method__c == null) {
					completedOrders.put(vo.Id, vo);
				}
			}
		}
		List<Payment__c> payments = [
			SELECT Vehicle_Order_ID__c
			FROM Payment__c
			WHERE
				Vehicle_Order_ID__c IN :completedOrders.keySet()
		];
		for (Payment__c p: payments) {
			completedOrders.remove(p.Vehicle_Order_ID__c);
		}
		for (Vehicle_Order__c vo : completedOrders.values()) {
			vo.Vehicle_Sale_Complete__c.addError(VEHICLE_SALE_CANNOT_COMPLETE_ERROR);
		}
	}

	private static void validateReturnedVehicleOrders(List<Vehicle_Order__c> vehicleOrders) {
		for (Vehicle_Order__c vo : vehicleOrders) {
			if (vo.Returned_On__c == null && vo.Returned_Reason__c != null) {
				vo.Returned_On__c.addError('If Returned Reason is specified, Returned On must also be specified');
				continue;
			}
			if (vo.Returned_On__c != null && vo.Returned_Reason__c == null) {
				vo.Returned_On__c.addError('If Returned On is specified, Returned Reason must also be specified');
				continue;
			}
			if (vo.Returned_On__c != null && vo.Deposit__c) {
				vo.Deposit_Returned_On__c = vo.Returned_On__c;
				vo.Deposit_Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_DEPOSIT_RETURNED_REASON_CAR_RETURNED;
			}
		}
	}

	private static void processHandoversAndReturns(Map<Id, Vehicle_Order__c> oldVehicleOrders, List<Vehicle_Order__c> vehicleOrders) {
		// We need to create a map from vehicle order ID to seller opportunity ID,
		// so that we can update the opportunity's stage, if necessary.
		List<Vehicle_Order__c> vehicleOrdersWithSellerOpportunityIds = [
			SELECT Id, Vehicle_ID__r.Seller_Opportunity_ID__c
			FROM Vehicle_Order__c
			WHERE Id IN :vehicleOrders
		];
		Map<Id, Id> vehicleOrderIdToOpportunityId = new Map<Id, Id>();
		for (Vehicle_Order__c vo : vehicleOrdersWithSellerOpportunityIds) {
			vehicleOrderIdToOpportunityId.put(vo.Id, vo.Vehicle_ID__r.Seller_Opportunity_ID__c);
		}

		List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
		List<Vehicle_Order__c> vehicleOrdersToUpdate = new List<Vehicle_Order__c>();
		for (Vehicle_Order__c vo : vehicleOrders) {
			// If the order newly reflects a sale, do some validation.
			Boolean isVehicleOrderAlreadyPurchased = oldVehicleOrders != null && oldVehicleOrders.get(vo.Id).Vehicle_Purchased__c;
			if (!isVehicleOrderAlreadyPurchased && vo.Vehicle_Purchased__c) {
				if (vo.Vehicle_Returned__c) {
					vo.addError('A vehicle order cannot be newly sold and also returned');
					continue;
				}
				if (vo.Handover_Date__c != null) {
					vo.addError('A vehicle order cannot be newly sold with an existing handover date');
					continue;
				}
			}

			// If the order newly reflects a completed sale, update the opportunity stage and
			// handover date.
			if (!isVehicleOrderAlreadyPurchased && vo.Vehicle_Purchased__c && !vo.Vehicle_Returned__c) {
				Id sellerOpportunityId = vehicleOrderIdToOpportunityId.get(vo.Id);
				if (sellerOpportunityId != null) {
					opportunitiesToUpdate.add(new Opportunity(Id = sellerOpportunityId, StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER));
				}
				vehicleOrdersToUpdate.add(new Vehicle_Order__c(Id = vo.Id, Handover_Date__c = Date.today()));
			}

			// If the order newly reflects a return, update the opportunity stage.
			Boolean isVehicleOrderAlreadyReturned = oldVehicleOrders != null && oldVehicleOrders.get(vo.Id).Vehicle_Returned__c;
			if (!isVehicleOrderAlreadyReturned && vo.Vehicle_Returned__c) {
				Id sellerOpportunityId = vehicleOrderIdToOpportunityId.get(vo.Id);
				System.assert(sellerOpportunityId != null, 'vehicle ' + vo.Vehicle_ID__c + ' does not have a seller opportunity');
				opportunitiesToUpdate.add(new Opportunity(Id = sellerOpportunityId, StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL));
			}
		}
		update opportunitiesToUpdate;
		update vehicleOrdersToUpdate;
	}

	private static void assignPurchaseVehicleOrdersToVehicles(List<Vehicle_Order__c> vehicleOrders) {
		// Lookup references aren't populated in Trigger.new objects, so we need to fetch
		// the vehicles associated with the given vehicle orders.
		Set<Id> vehicleIds = new Set<Id>();
		for (Vehicle_Order__c vehicleOrder : vehicleOrders) {
			vehicleIds.add(vehicleOrder.Vehicle_ID__c);
		}
		Map<Id, Vehicle__c> vehicleIdToVehicle = new Map<Id, Vehicle__c>([
			SELECT Purchased_Vehicle_Order_ID__c FROM Vehicle__c WHERE Id IN :vehicleIds
		]);

		// Another approach might be to iterate over all relevant vehicles and
		// determine its Purchased Vehicle Order anew by looking through all of its vehicle orders.
		// The approach taken here is less expensive, but requires more precise bookkeeping.
		List<Vehicle__c> vehiclesToUpdate = new List<Vehicle__c>();
		for (Vehicle_Order__c vehicleOrder : vehicleOrders) {
			Id existingPurchasedVehicleOrderId = vehicleIdToVehicle.get(vehicleOrder.Vehicle_ID__c).Purchased_Vehicle_Order_ID__c;
			if (vehicleOrder.Vehicle_Returned__c && existingPurchasedVehicleOrderId == vehicleOrder.Id) {
				vehiclesToUpdate.add(new Vehicle__c(Id = vehicleOrder.Vehicle_ID__c, Purchased_Vehicle_Order_ID__c = null));
				continue;
			}
			Boolean isVehicleOrderPurchasedAndNotReturned = vehicleOrder.Vehicle_Purchased__c && !vehicleOrder.Vehicle_Returned__c;
			if (isVehicleOrderPurchasedAndNotReturned && existingPurchasedVehicleOrderId == null) {
				vehiclesToUpdate.add(new Vehicle__c(Id = vehicleOrder.Vehicle_ID__c, Purchased_Vehicle_Order_ID__c = vehicleOrder.Id));
				continue;
			}
			if (isVehicleOrderPurchasedAndNotReturned && existingPurchasedVehicleOrderId != vehicleOrder.Id) {
				vehicleOrder.addError('Cannot complete a vehicle order while its vehicle has another completed order');
				continue;
			}
		}

		update vehiclesToUpdate;
	}

	private static void updateOnDeposit(List<Vehicle_Order__c> vehicleOrders) {
		Set<ID> vehicleIds = new Set<ID>();
		for (Vehicle_Order__c vo : vehicleOrders) {
			vehicleIds.add(vo.Vehicle_ID__c);
		}

		Map<ID, Vehicle__c> vehiclesByID = new Map<ID, Vehicle__c>([SELECT ID, On_Deposit__c FROM Vehicle__c WHERE Id IN :vehicleIds]);
		List<Vehicle__c> vehiclesToUpdate = new List<Vehicle__c>();

		for (Vehicle_Order__c vo : vehicleOrders) {
			Vehicle__c currentVehicle = vehiclesByID.get(vo.Vehicle_ID__c);
			Boolean hasOpenDeposit = (vo.Deposit_Accepted_On__c != null) && !vo.Deposit_Returned__c && !vo.Deposit_Expired__c;
			if (hasOpenDeposit != currentVehicle.On_Deposit__c) {
				currentVehicle.On_Deposit__c = hasOpenDeposit;
				vehiclesToUpdate.add(currentVehicle);
			}
		}
		update vehiclesToUpdate;
	}

	public static void beforeInsert(List<Vehicle_Order__c> newList) {
		validateOpenVehicleOrders(newList);
		validateReturnedVehicleOrders(newList);
	}

	public static void beforeUpdate(Map<Id, Vehicle_Order__c> oldMap, List<Vehicle_Order__c> newList) {
		validateOpenVehicleOrders(newList);
		validateReturnedVehicleOrders(newList);
	}

	public static void afterInsert(List<Vehicle_Order__c> newList) {
		processHandoversAndReturns(null, newList);
		assignPurchaseVehicleOrdersToVehicles(newList);
		updateOnDeposit(newList);
	}

	public static void afterUpdate(Map<Id, Vehicle_Order__c> oldMap, List<Vehicle_Order__c> newList) {
		processHandoversAndReturns(oldMap, newList);
		assignPurchaseVehicleOrdersToVehicles(newList);
		updateOnDeposit(newList);
	}
}