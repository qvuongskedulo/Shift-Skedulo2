public class ShiftVehicles {
	static final List<String> CAN_BE_LISTED_STAGE_NAMES = new List<String>{
		ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE,
		ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL
	};

	@TestVisible static final String SUBJECT_POST_LISTINGS_ADD_LINKS = 'Post Listings and Add Links';
	@TestVisible static final String SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS = 'Update Listings with Professional Photos';
	@TestVisible static final String SUBJECT_REMOVE_LISTING_FROM_EBAY = 'Remove Listing from eBay';

	static void updateListingRegions(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> newList) {
		Map<Id, Vehicle__c> changed = new Map<Id, Vehicle__c>();
		for (Vehicle__c v : newList) {
			if (v.Listing_Region_ID__c != oldMap.get(v.Id).Listing_Region_ID__c) {
				changed.put(v.Id, v);
			}
		}
		if (changed.isEmpty()) {
			return;
		}
		Map<Id, Processing_Pipeline__c> pipelines = new Map<Id, Processing_Pipeline__c>([
			SELECT Id, Seller_Opportunity_ID__r.Vehicle_ID__c
			FROM Processing_Pipeline__c
			WHERE Seller_Opportunity_ID__r.Vehicle_ID__c IN :changed.keySet()
		]);
		List<Task> tasks = [
			SELECT Id, WhatId
			FROM Task
			WHERE WhatId IN :pipelines.keySet() AND IsClosed = FALSE
		];
		for (Task t : tasks) {
			Processing_Pipeline__c p = pipelines.get(t.WhatId);
			Vehicle__c v = changed.get(p.Seller_Opportunity_ID__r.Vehicle_ID__c);
			t.Region_ID__c = v.Listing_Region_ID__c;
		}
		update tasks;
	}

	static void updateOpportunityNames(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> newList) {
		Set<Vehicle__c> changed = new Set<Vehicle__c>(newList);
		if (oldMap != null) {
			for (Vehicle__c upd : newList) {
				Vehicle__c prev = oldMap.get(upd.Id);
				Boolean colorsEqual =
					(upd.Exterior_Color__c == null && prev.Exterior_Color__c == null) ||
					(upd.Exterior_Color__c != null && upd.Exterior_Color__c.equals(prev.Exterior_Color__c));
				if (upd.Name.equals(prev.Name) && colorsEqual) {
					changed.remove(upd);
				}
			}
		}
		if (changed.isEmpty()) {
			return;
		}
		update [SELECT Id FROM Opportunity WHERE Vehicle_Id__c IN :changed];
	}

	// We charge a Late Paperwork Fee 30 days after the contract is signed and there's still paperwork missing.
	//
	// SFDC can't fire off triggers at a certain time (and the apex scheduler has limits and may be unreliable?),
	//  so I'm using this convoluted approach:
	//
	// Opportunity.Late_Paperwork_Fee__c is a formula field on Opportunity. The formula controls whether or not 
	//   Paperwork_Fee_Pending__c is applied.
	// This trigger controls the value of Paperwork_Fee_Pending__c. Before 30 days, it can change between 0 <-> fee, 
	//   but after 30 days, it can only increase from 0 -> fee.
	static void updatePaperworkFeePending(Map<Id, Vehicle__c> oldMap,  List<Vehicle__c> newList) {
		Set<Id> changingOpportunityIds = new Set<Id>();
		for (Vehicle__c vehicle : newList) {
			if (vehicle.Paperwork_Missing__c != oldMap.get(vehicle.Id).Paperwork_Missing__c ||
				vehicle.Paperwork_Missing_Reason__c != oldMap.get(vehicle.Id).Paperwork_Missing_Reason__c) {
				changingOpportunityIds.add(vehicle.Seller_Opportunity_ID__c);
			}
		}

		if (changingOpportunityIds.isEmpty()) {
			return;
		}

		Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>([
			SELECT Id, Seller_Contract_Signed_On__c
			FROM Opportunity
			WHERE Id IN :changingOpportunityIds
		]);

		for (Vehicle__c vehicle : newList) {
			if (opportunities.get(vehicle.Seller_Opportunity_ID__c) == null) {
				continue;
			}

			if ((vehicle.Paperwork_Missing__c == ShiftConstants.PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE ||
				vehicle.Paperwork_Missing__c == ShiftConstants.PAPERWORK_MISSING_YES_AVAILABLE_WITHOUT_FINANCING ||
				vehicle.Paperwork_Missing__c == ShiftConstants.PAPERWORK_MISSING_YES_LESS_THAN_7_DAYS_UNAVAILABLE
				) && (
				vehicle.Paperwork_Missing_Reason__c == ShiftConstants.PAPERWORK_MISSING_REASON_PAYOFF_SELLER_UNDERWATER ||
				vehicle.Paperwork_Missing_Reason__c == ShiftConstants.PAPERWORK_MISSING_REASON_PAYOFF_WAITING_STATEMENT ||
				vehicle.Paperwork_Missing_Reason__c == ShiftConstants.PAPERWORK_MISSING_REASON_SELLER_NOT_COOPERATING ||
				vehicle.Paperwork_Missing_Reason__c == ShiftConstants.PAPERWORK_MISSING_REASON_TITLE_SELLER_PROBLEM ||
				vehicle.Paperwork_Missing_Reason__c == ShiftConstants.PAPERWORK_MISSING_REASON_TITLE_OUT_OF_STATE ||
				vehicle.Paperwork_Missing_Reason__c == ShiftConstants.PAPERWORK_MISSING_REASON_TITLE_WAITING_SELLER
				)) {
				vehicle.Paperwork_Fee_Pending__c = ShiftConstants.PAPERWORK_MISSING_FEE;
			} else {
				if (opportunities.get(vehicle.Seller_Opportunity_ID__c).Seller_Contract_Signed_On__c == null ||
					Date.today() < opportunities.get(vehicle.Seller_Opportunity_ID__c).Seller_Contract_Signed_On__c.addDays(30)) {
					// It hasn't been 30 days since the contact was signed.  We can still go from PAPERWORK_MISSING_FEE -> 0.
					vehicle.Paperwork_Fee_Pending__c = 0;
				}
			}
		}
	}

	static void updateVehicleNames(List<Vehicle__c> newList) {
		for (Vehicle__c vehicle : newList) {
			List<string> nameComponents = new List<string>();
			nameComponents.add(String.valueOf(Integer.valueOf(vehicle.Year__c)));
			nameComponents.add(vehicle.Make__c);
			nameComponents.add(vehicle.Model__c);
			if (String.isNotEmpty(vehicle.Trim__c)) {
				nameComponents.add(vehicle.Trim__c);
			}
			vehicle.Name = String.join(nameComponents, ' ').left(ShiftConstants.VEHICLE_NAME_MAX_LENGTH);
		}
	}

	// Guarantees that updates to Seller_Opportunity_ID__c do not result in multiple
	// seller opps pointing at the same vehicle
	static void verifyOneSellerOpportunityPerVehicle(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> newList) {
		Set<Id> newSellerOppIds = new Set<Id>();
		for (Vehicle__c v : newList) {
			Id newSellerOppId = v.Seller_Opportunity_ID__c;
			if (newSellerOppId == null) {
				continue;
			}
			if (!newSellerOppIds.add(newSellerOppId)) {
				v.Seller_Opportunity_ID__c.addError('value conflicts with a previous value in this batch');
			}
			Id curSellerId = null;
			if (oldMap != null) {
				curSellerId = oldMap.get(v.Id).Seller_Opportunity_ID__c;
			}
			if (curSellerId == null || curSellerId.equals(newSellerOppID)) {
				continue;
			}
			v.Seller_Opportunity_ID__c.addError('attempt to reference vehicle from seller opportunity ' +
				newSellerOppId + ' but vehicle is already referenced from ' + curSellerId);
		}
	}

	static void ensureOpportunityTask(List<Vehicle__c> vehicles, String subject) {
		if (vehicles.isEmpty()) {
			return;
		}

		List<Id> sellerOpportunityIds = new List<Id>();
		for (Vehicle__c vehicle : vehicles){
			sellerOpportunityIds.add(vehicle.Seller_Opportunity_ID__c);
		}

		List<Task> existingTasks = [
			SELECT WhatId
			FROM Task
			WHERE 
				Subject = :subject AND
				Status != :ShiftConstants.TASK_STATUS_CANCELED AND
				WhatId IN :sellerOpportunityIds
		];

		List<Task> tasksToCreateForOpportunities = new List<Task>();
		for (Id opportunityId : sellerOpportunityIds) {
			tasksToCreateForOpportunities.add(
				ShiftTasks.createTask(
					new Opportunity(Id = opportunityId),
					subject,
					ShiftConstants.TASK_TEAM_MERCHANDISING)
			);
		}
		ShiftOpportunities.addTasksIfNotExtant(existingTasks, tasksToCreateForOpportunities);
	}

	static List<Vehicle__c> filterVehiclesWherePostListingsAndLinksTaskAreCompleted(List<Vehicle__c> vehicles) {
		if (vehicles.isEmpty()) {
			return vehicles;
		}

		List<Id> sellerOpportunityIds = new List<Id>();
		for (Vehicle__c vehicle : vehicles) {
			sellerOpportunityIds.add(vehicle.Seller_Opportunity_ID__c);
		}

		List<Task> tasks = [
			SELECT WhatId
			FROM Task
			WHERE
				Subject = :SUBJECT_POST_LISTINGS_ADD_LINKS AND
				Status = :ShiftConstants.TASK_STATUS_COMPLETED AND
				WhatId IN :sellerOpportunityIds
		];

		Set<Id> oppIds = new Set<Id>();
		for (Task t : tasks){
			oppIds.add(t.WhatId);
		}
		List<Vehicle__c> filteredVehicles = new List<Vehicle__c>();
		for (Vehicle__c vehicle : vehicles) {
			if (oppIds.contains(vehicle.Seller_Opportunity_ID__c)) {
				filteredVehicles.add(vehicle);
			}
		}
		return filteredVehicles;
	}

	static void addUpdateListingsWithProfessionalPhotosTask(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> vehicles) {
		List<Vehicle__c> vehiclesWithPhotosReadyTrue = new List<Vehicle__c>();
		for (Vehicle__c vehicle : vehicles) {
			if (oldMap != null && oldMap.get(vehicle.Id).Photos_Ready__c) {
				continue;
			}
			if (vehicle.Photos_Ready__c && vehicle.Seller_Opportunity_ID__c != null) {
				vehiclesWithPhotosReadyTrue.add(vehicle);
			}
		}
		List<Vehicle__c> vehiclesWithPhotosReadyAndPostListingsAndLinksTaskClosed = filterVehiclesWherePostListingsAndLinksTaskAreCompleted(vehiclesWithPhotosReadyTrue);
		ensureOpportunityTask(vehiclesWithPhotosReadyAndPostListingsAndLinksTaskClosed, SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);
	}

	static void addRemoveListingFromEbayTask(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> vehicles) {
		List<Vehicle__c> becameSalePending = new List<Vehicle__c>();
		for (Vehicle__c vehicle : vehicles) {
			if (oldMap != null && oldMap.get(vehicle.Id).Sale_Pending__c) {
				continue;
			}
			if (vehicle.Sale_Pending__c && !String.isBlank(vehicle.Ebay_Listing_URL__c)) {
				becameSalePending.add(vehicle);
			}
		}
		ensureOpportunityTask(becameSalePending, SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	static void addPostListingsAndLinksTask (Map<Id, Vehicle__c> oldMap, List<Vehicle__c> vehicles) {
		List<Vehicle__c> vehiclesWithCanBeListedTrue = new List<Vehicle__c>();
		for (Vehicle__c vehicle : vehicles) {
			if (oldMap != null && oldMap.get(vehicle.Id).Can_Be_Listed__c) {
				continue;
			}
			if (vehicle.Can_Be_Listed__c && vehicle.Seller_Opportunity_ID__c != null) {
				vehiclesWithCanBeListedTrue.add(vehicle);
			}
		}
		ensureOpportunityTask(vehiclesWithCanBeListedTrue, SUBJECT_POST_LISTINGS_ADD_LINKS);
	}

	static void updateCanBeListed(Map<Id, Vehicle__c> oldMap, List<Id> vehicleIds) {
		Map<Id, Vehicle__c> vehicles = new Map<Id, Vehicle__c>([
			SELECT Id
			FROM Vehicle__c
			WHERE
				Paperwork_Missing__c != :ShiftConstants.PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE AND
				(Listing_Title__c != NULL AND Listing_Title__c != '') AND
				Seller_Opportunity_ID__c != NULL AND
				Seller_Opportunity_ID__r.Direct_To_Wholesale__c = FALSE AND
				Seller_Opportunity_ID__r.StageName IN :CAN_BE_LISTED_STAGE_NAMES AND
				Id IN :vehicleIds
		]);

		Set<Id> seenVehicleIds = new Set<Id>();
		List<Vehicle__c> toUpdate = new List<Vehicle__c>();
		for (Id vehicleId : vehicleIds) {
			if (seenVehicleIds.contains(vehicleId)) {
				continue;
			}
			seenVehicleIds.add(vehicleId);
			Boolean canBeListed = vehicles.containsKey(vehicleId);
			if (oldMap != null && oldMap.get(vehicleId).Can_Be_Listed__c == canBeListed) {
				continue;
			}
			toUpdate.add(new Vehicle__c(
				Id = vehicleId, 
				Can_Be_Listed__c = canBeListed
			));
		}
		update toUpdate;
	}

	static void updateCanBeListed(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> vehicles) {
		List<Id> ids = new List<Id>();
		for (Vehicle__c vehicle : vehicles) {
			ids.add(vehicle.Id);
		}
		updateCanBeListed(oldMap, ids);
	}

	public static void updateCanBeListed(Map<Id, Opportunity> oldMap, List<Opportunity> opportunities) {
		List<Id> ids = new List<Id>();
		for (Opportunity opportunity : opportunities) {
			ids.add(opportunity.Vehicle_ID__c);
		}
		updateCanBeListed(null, ids);
	}

	static void updateParkingLot(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> newList) {
		List<Vehicle__c> vehiclesInPrepare = [
			SELECT Id, Listing_Region_ID__c
			FROM Vehicle__c
			WHERE
				Id IN :newList AND
				Seller_Opportunity_ID__r.StageName = :ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE
		];
		Set<Id> vehicleIdsInPrepare = new Set<Id>();
		for (Vehicle__c vehicle : vehiclesInPrepare) {
			vehicleIdsInPrepare.add(vehicle.Id);
		}

		List<Vehicle__c> relevantVehicles = new List<Vehicle__c>();
		for (Vehicle__c vehicle : newList) {
			if (!vehicleIdsInPrepare.contains(vehicle.Id)) {
				continue;
			}
			// This is only called before update, so `oldMap` is not null.
			if (vehicle.Listing_Region_ID__c == oldMap.get(vehicle.Id).Listing_Region_ID__c) {
				continue;
			}
			relevantVehicles.add(vehicle);
		}

		Set<Id> relevantRegionIds = new Set<Id>();
		for (Vehicle__c vehicle : relevantVehicles) {
			relevantRegionIds.add(vehicle.Listing_Region_ID__c);
		}
		Map<Id, Id> regionIdToPrimaryParkingLotId = ShiftParkingLots.getRegionIdToPrimaryParkingLotIdMap(relevantRegionIds);

		for (Vehicle__c vehicle : relevantVehicles) {
			Id regionId = vehicle.Listing_Region_ID__c;
			Id primaryParkingLotId = regionIdToPrimaryParkingLotId.get(regionId);
			if (primaryParkingLotId == null) {
				vehicle.addError('No primary parking lot for region ' + regionId);
				continue;
			}
			vehicle.Parking_Lot_ID__c = primaryParkingLotId;
		}
	}

	static void updateFirstListedAt(List<Vehicle__c> newList) {
		Datetime now = Datetime.now();
		for (Vehicle__c v: newList) {
			if (v.First_Listed_At__c == NULL && v.Driveshift_Listing_URL__c != NULL) {
				v.First_Listed_At__c = now;
			}
		}
	}

	public static void beforeInsert(List<Vehicle__c> newList) {
		updateFirstListedAt(newList);
		verifyOneSellerOpportunityPerVehicle(null, newList);
		updateVehicleNames(newList);
	}

	public static void beforeUpdate(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> newList) {
		updateFirstListedAt(newList);
		verifyOneSellerOpportunityPerVehicle(oldMap, newList);
		updatePaperworkFeePending(oldMap, newList);
		updateVehicleNames(newList);
		updateParkingLot(oldMap, newList);
	}

	public static void afterInsert(List<Vehicle__c> newList) {
		updateOpportunityNames(null, newList);
		updateCanBeListed(null, newList);
		addPostListingsAndLinksTask(null, newList);
		addUpdateListingsWithProfessionalPhotosTask(null, newList);
		addRemoveListingFromEbayTask(null, newList);
	}

	public static void afterUpdate(Map<Id, Vehicle__c> oldMap, List<Vehicle__c> newList) {
		updateOpportunityNames(oldMap, newList);
		updateListingRegions(oldMap, newList);
		updateCanBeListed(oldMap, newList);
		addPostListingsAndLinksTask(oldMap, newList);
		addUpdateListingsWithProfessionalPhotosTask(oldMap, newList);
		addRemoveListingFromEbayTask(oldMap, newList);
	}
}