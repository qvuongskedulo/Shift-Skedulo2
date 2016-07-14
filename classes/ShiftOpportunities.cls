public with sharing class ShiftOpportunities {
	// new opportunity subjects
	public static final String SUBJECT_SEND_REMOTE_QUOTE = 'Send Remote Quote';

	// evaluate and pickup subjects
	public static final String SUBJECT_SECONDARY_PRICING_RESEARCH = 'Secondary Pricing Research';
	public static final String SUBJECT_UPLOAD_CARFAX_AUTOCHECK_REPORTS = 'Upload Carfax and AutoCheck Reports';
	public static final String SUBJECT_OBTAIN_RECALL_WARRANTY_SERVICE_INFORMATION = 'Obtain Recall, Warranty, and Service Contract Information';
	public static final String SUBJECT_SEND_SELLER_PROFILE_QUESTIONNAIRE = 'Send Seller Profile Questionnaire';
	public static final String SUBJECT_VERIFY_SIRIUS_COMPATIBILITY = 'Verify Sirius Compatibility';

	public static final String SUBJECT_ADD_DEAL_PROPS_TRACKER_CONDITION_SHEET = 'Add Deal to PrOps Tracker';
	public static final String SUBJECT_CHECK_SELLER_PAPERWORK = 'Check Seller Paperwork';

	// Opportunity name will be appended to this
	public static final String SUBJECT_TRADE_IN_PRICING_PREFIX = 'Determine Trade-In Pricing';

	// sell car subjects
	public static final String SUBJECT_PURCHASE_CARFAX_CIP = 'Purchase Carfax CIP';
	public static final String SUBJECT_CHECK_COMING_SOON_BUYERS = 'Check for Coming Soon Buyers';
	public static final String SUBJECT_UPDATE_SELLER = 'Update Seller';

	// handover subjects
	public static final String SUBJECT_DELETE_CAR_SHIFT_APPLICATION_PULL_DOWN_LISTINGS = 'Delete Car from Shift Application and Pull Down all Listings';
	public static final String SUBJECT_SEND_SELLER_RECEIPT = 'Send Seller Receipt';
	public static final String SUBJECT_SEND_MONEY_SELLER = 'Send Money to Seller';
	public static final String SUBJECT_COMPLETE_DMV_PAPERWORK = 'Complete DMV Paperwork';
	public static final String SUBJECT_CANCEL_SCHEDULED_TEST_DRIVES = 'Cancel Scheduled Test Drives';
	public static final String SUBJECT_CAR_HAS_BEEN_SOLD = 'Car Has Been Sold';
	public static final String SUBJECT_NOTIFY_SELLER_DROP_INSURANCE = 'Notify Seller to Drop Insurance';
	public static final String SUBJECT_FILE_RELEASE_LIABILITY = 'File Release of Liability';
	public static final String SUBJECT_CHECK_PROD_LIST_FINAL_BUYER_CLOSE_OUT_MARK_DND = 'Check ProD List for Final Buyer, Close Out and Mark DnD';
	public static final String SUBJECT_DELETE_AND_RECYCLE_CRAIGSLIST_NUMBER = 'Delete and Recycle Craigslist Phone Number';
	public static final String SUBJECT_EDIT_VEHICLE_PHOTOS = 'Edit Vehicle Photos';
	public static final String SUBJECT_EXECUTE_WHOLESALE = 'Execute Wholesale';
	public static final String SUBJECT_RECYCLE_LISTING_TEXT = 'Recycle Listing Text';

	// sold subjects
	public static final String SUBJECT_SEND_SELLER_BUYER_SURVEYS = 'Send Seller and Buyer Surveys';

	static final Set<String> OUTBOUND_LEAD_SOURCES = new Set<String>{'Craigslist', 'Seller App'};

	// shared subjects
	public static final String SUBJECT_SEND_APPRAISAL_SURVEY = 'Send Appraisal Survey';

	static Set<String> ISR_PROFILE_NAMES = new Set<String>{
			ShiftConstants.PROFILE_NAME_INSIDE_SALES_OUTBOUND,
			ShiftConstants.PROFILE_NAME_INSIDE_SALES_INBOUND
	};

	@TestVisible static final Integer SELLER_NOTIFICATIONS_TO_CREATE = 8;

	static Id cachedBuyerRecordTypeId;
	static Id cachedSellerRecordTypeId;

	static void addSendLostStageAppraisalSurveyTasks(Map<Id, Opportunity> oldMap, List<Opportunity> newList, List<Task> tasks) {
		Set<Id> opportunitiesToCheck = new Set<Id>();
		for (Opportunity opp : newList) {
			if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST) {
				Opportunity oldOpp = oldMap.get(opp.Id);
				if (oldOpp != null && oldOpp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE) {
					opportunitiesToCheck.add(opp.Id);
				}
			}
		}

		List<Evaluation__c> evaluations = [
			SELECT Seller_Opportunity_ID__c
			FROM Evaluation__c
			WHERE
				Seller_Opportunity_ID__c IN :opportunitiesToCheck AND
				Evaluated_At__c != NULL AND
				Canceled__c = FALSE
		];

		Set<Id> opportunitiesToAddTo = new Set<Id>();

		for (Evaluation__c evaluation : evaluations) {
			opportunitiesToAddTo.add(evaluation.Seller_Opportunity_ID__c);
		}

		for (Id oppId : opportunitiesToAddTo) {
			tasks.add(ShiftTasks.createTask(oldMap.get(oppId), SUBJECT_SEND_APPRAISAL_SURVEY, ShiftConstants.TASK_TEAM_USER_HAPPINESS));
		}
	}

	// oldOpp will be null on insert
	static void addStageChangeTasks(Opportunity opp, Opportunity oldOpp, List<Task> tasks) {
		if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE) {
			if (!opp.Gray_Area_Mileage__c && !opp.Auto_Reject__c && !OUTBOUND_LEAD_SOURCES.contains(opp.LeadSource) && opp.Quote_Sent_At__c == null) {
				tasks.add(ShiftTasks.createTask(opp, SUBJECT_SEND_REMOTE_QUOTE, ShiftConstants.TASK_TEAM_PRICING));
			}
		} else if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE) {
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_SECONDARY_PRICING_RESEARCH, ShiftConstants.TASK_TEAM_PRICING));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_UPLOAD_CARFAX_AUTOCHECK_REPORTS, ShiftConstants.TASK_TEAM_PRICING));
		} else if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE) {
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_OBTAIN_RECALL_WARRANTY_SERVICE_INFORMATION, ShiftConstants.TASK_TEAM_PRICING, Date.today() + 1));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_SEND_APPRAISAL_SURVEY, ShiftConstants.TASK_TEAM_USER_HAPPINESS, Date.today() + 1));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_SEND_SELLER_PROFILE_QUESTIONNAIRE, ShiftConstants.TASK_TEAM_USER_HAPPINESS, Date.today() + 1));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_ADD_DEAL_PROPS_TRACKER_CONDITION_SHEET, ShiftConstants.TASK_TEAM_MERCHANDISING));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_VERIFY_SIRIUS_COMPATIBILITY, ShiftConstants.TASK_TEAM_MERCHANDISING));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_CHECK_SELLER_PAPERWORK, ShiftConstants.TASK_TEAM_DOCUMENT_OPERATIONS));
		} else if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL) {
			if (!opp.Direct_To_Wholesale__c) {
				tasks.add(ShiftTasks.createTask(opp, SUBJECT_PURCHASE_CARFAX_CIP, ShiftConstants.TASK_TEAM_MERCHANDISING));
			}
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_CHECK_COMING_SOON_BUYERS, ShiftConstants.TASK_TEAM_USER_HAPPINESS));
			for (Integer i = 1; i <= SELLER_NOTIFICATIONS_TO_CREATE; i++ ) {
				tasks.add(ShiftTasks.createTask(opp, SUBJECT_UPDATE_SELLER, ShiftConstants.TASK_TEAM_USER_HAPPINESS, Date.today() + (i * 7), WORKFLOW_IDENTIFIER_SELLER_NOTIFICATIONS));
			}
		} else if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER) {
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_DELETE_CAR_SHIFT_APPLICATION_PULL_DOWN_LISTINGS, ShiftConstants.TASK_TEAM_MERCHANDISING));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_SEND_SELLER_RECEIPT, ShiftConstants.TASK_TEAM_USER_HAPPINESS));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_SEND_MONEY_SELLER, ShiftConstants.TASK_TEAM_DOCUMENT_OPERATIONS));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_COMPLETE_DMV_PAPERWORK, ShiftConstants.TASK_TEAM_DOCUMENT_OPERATIONS));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_CANCEL_SCHEDULED_TEST_DRIVES, ShiftConstants.TASK_TEAM_CUSTOMER_EXPERIENCE));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_CAR_HAS_BEEN_SOLD, null, opp.OwnerId));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_RECYCLE_LISTING_TEXT, ShiftConstants.TASK_TEAM_MERCHANDISING));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_NOTIFY_SELLER_DROP_INSURANCE, ShiftConstants.TASK_TEAM_USER_HAPPINESS, Date.today() + 8));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_FILE_RELEASE_LIABILITY, ShiftConstants.TASK_TEAM_DOCUMENT_OPERATIONS, Date.today() + 8));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_CHECK_PROD_LIST_FINAL_BUYER_CLOSE_OUT_MARK_DND, ShiftConstants.TASK_TEAM_USER_HAPPINESS));
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_DELETE_AND_RECYCLE_CRAIGSLIST_NUMBER, ShiftConstants.TASK_TEAM_MERCHANDISING));
		} else if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD) {
			tasks.add(ShiftTasks.createTask(opp, SUBJECT_SEND_SELLER_BUYER_SURVEYS, ShiftConstants.TASK_TEAM_USER_HAPPINESS));
		} else if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST) {
			if (oldOpp != null && oldOpp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL) {
				tasks.add(ShiftTasks.createTask(opp, SUBJECT_DELETE_CAR_SHIFT_APPLICATION_PULL_DOWN_LISTINGS, ShiftConstants.TASK_TEAM_MERCHANDISING));
			}
		}
	}

	static void cancelIncompleteSellerNotificationTasks(List<Id> opportunityIds){
		List<Task> incompleteSellerNotificationTasks = [
			SELECT Id
			FROM Task
			WHERE
				Workflow_Identifier__c = :WORKFLOW_IDENTIFIER_SELLER_NOTIFICATIONS AND
				WhatId IN :opportunityIds AND
				IsClosed = FALSE
		];
		ShiftTasks.updateStatus(incompleteSellerNotificationTasks, ShiftConstants.TASK_STATUS_CANCELED);
	}

	static void handleStageChanges(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		List<Task> tasks = new List<Task>();
		List<Id> opportunityIdsToCancelSellerNotificationTasksFor = new List<Id>();
		List<Id> enteringStageSold = new List<Id>();

		for (Opportunity opp : newList) {
			Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;

			if (oldOpp == null || opp.StageName != oldOpp.StageName) {
				addStageChangeTasks(opp, oldOpp, tasks);
				if (opp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD) {
					enteringStageSold.add(opp.Id);
				}
			}

			if (oldOpp != null && oldOpp.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL && opp.StageName != ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL) {
				opportunityIdsToCancelSellerNotificationTasksFor.add(oldOpp.Id);
			}

		}

		if (oldMap != null) {
			addSendLostStageAppraisalSurveyTasks(oldMap, newList, tasks);
		}

		insert tasks;

		cancelIncompleteSellerNotificationTasks(opportunityIdsToCancelSellerNotificationTasksFor);
		if (!enteringStageSold.isEmpty()) {
			processIncentives(enteringStageSold);
		}
	}

	public static void processStageChanges(List<Shift_Stage_Change__c> changes, Map<Id, Opportunity> opportunities) {
		ShiftProcessingPipeline.processStageChanges(changes, opportunities);
	}

	static void addTask(Id objectId, String subject) {
		insert new Task(OwnerId=ShiftUsers.unownedUserId(), WhatId=objectId, Subject=subject, Team__c='User Happiness');
	}

	@TestVisible
	static void cancelTasksForSubject(List<Id> opportunityIds, String subject) {
		List<Task> tasksForSubjectAndOpportunityIds = [
			SELECT Id
			FROM Task
			WHERE
				Subject = :subject AND
				WhatId IN :opportunityIds
		];
		ShiftTasks.updateStatus(tasksForSubjectAndOpportunityIds, ShiftConstants.TASK_STATUS_CANCELED);
	}

	public static Id getBuyerRecordTypeId() {
		if (cachedBuyerRecordTypeId == null) {
			cachedBuyerRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Buyer'].Id;
		}
		return cachedBuyerRecordTypeId;
	}

	public static Id getSellerRecordTypeId() {
		if (cachedSellerRecordTypeId == null) {
			cachedSellerRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id;
		}
		return cachedSellerRecordTypeId;
	}

	public static boolean isBuyerOpportunity(Opportunity opp) {
		return opp.RecordTypeId == getBuyerRecordTypeId();
	}

	public class RecordTypeSplit {
		public final List<Opportunity> buyerOpportunities;
		public final List<Opportunity> sellerOpportunities;

		private RecordTypeSplit(List<Opportunity> opportunities) {
			buyerOpportunities = new List<Opportunity>();
			sellerOpportunities = new List<Opportunity>();
			Id sellerRecordTypeId = getSellerRecordTypeId();
			Id buyerRecordTypeId = getBuyerRecordTypeId();
			for (Opportunity opportunity : opportunities) {
				if (opportunity.RecordTypeId == sellerRecordTypeId) {
					sellerOpportunities.add(opportunity);
				} else if (opportunity.RecordTypeId == buyerRecordTypeId) {
					buyerOpportunities.add(opportunity);
				}
			}
		}
	}

	public static RecordTypeSplit splitByRecordType(List<Opportunity> opportunities) {
		return new RecordTypeSplit(opportunities);
	}

	static void validatePricing(List<Opportunity> newList) {
		for (Opportunity o : newList) {
			if (o.Pricing_Strategy__c == ShiftConstants.PRICING_STRATEGY_SINGLE_PRICE_0_UPSIDE) {
				if (o.Seller_Upside_Percentage__c != 0) {
					o.Seller_Upside_Percentage__c.addError('Seller upside percentage must be 0 for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
			} else if (o.Pricing_Strategy__c == ShiftConstants.PRICING_STRATEGY_SPECIFIC_CAR_SEARCH) {
				if (o.Seller_Upside_Percentage__c != 0) {
					o.Seller_Upside_Percentage__c.addError('Seller upside percentage must be 0 for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
			} else if (o.Pricing_Strategy__c == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT) {
				if (o.Seller_Upside_Percentage__c != 100) {
					o.Seller_Upside_Percentage__c.addError('Seller upside percentage must be 100 for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
				if (o.Flat_Fee__c == null) {
					o.Flat_Fee__c.addError('Flat Fee field must be populated for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
				if (o.Flat_Fee_Percent__c != null) {
					o.Flat_Fee_Percent__c.addError('Flat Fee - Percent field must not be populated for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
			} else if (o.Pricing_Strategy__c == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT) {
				if (o.Seller_Upside_Percentage__c != 100) {
					o.Seller_Upside_Percentage__c.addError('Seller upside percentage must be 100 for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
				if (o.Flat_Fee_Percent__c == null) {
					o.Flat_Fee_Percent__c.addError('Flat Fee - Percent field must be populated for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
				if (o.Flat_Fee__c != null) {
					o.Flat_Fee__c.addError('Flat Fee field must not be populated for pricing strategy: ' + o.Pricing_Strategy__c);
					continue;
				}
			}
		}
	}

	static void validateSpecificCarSearchOnHandoverOrSold(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		List<Vehicle_Order__c> purchaseVehicleOrdersWithSpecificCarSearchFee = [
			SELECT Vehicle_ID__r.Seller_Opportunity_ID__c
			FROM Vehicle_Order__c
			WHERE
				Vehicle_ID__r.Seller_Opportunity_ID__c IN :newList AND
				Vehicle_Purchased__c = TRUE AND
				Vehicle_Returned__c = FALSE AND
				Buyer_Opportunity_ID__r.Specific_Car_Search_Fee__c != null
		];

		Set<Id> sellerOpportunityIdsWithFees = new Set<Id>();
		for (Vehicle_Order__c vehicleOrder : purchaseVehicleOrdersWithSpecificCarSearchFee) {
			sellerOpportunityIdsWithFees.add(vehicleOrder.Vehicle_ID__r.Seller_Opportunity_ID__c);
		}

		for (Opportunity o : newList) {
			if (oldMap != null && oldMap.get(o.Id).StageName == o.StageName) {
				continue;
			}
			if (o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER || o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD) {
				if (o.Specific_Car_Search__c && !sellerOpportunityIdsWithFees.contains(o.Id)) {
					o.StageName.addError('Cannot change to stage ' + o.StageName + '; Specific Car Search is true but the buyer opportunity does not have a Specific Car Search Fee');
				}
				if (!o.Specific_Car_Search__c && sellerOpportunityIdsWithFees.contains(o.Id)) {
					o.StageName.addError('Cannot change to stage ' + o.StageName + '; Specific Car Search is false but the buyer opportunity has a Specific Car Search Fee');
				}
			}
		}
	}

	// TODO(max.woghiren): Create a method or class to handle stage change validation
	// boilerplate (https://shift.phacility.com/T2081).
	static void validateStageChangeToHandover(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		List<Vehicle_Order__c> vehicleOrdersWithSaleComplete = [
			SELECT Vehicle_ID__c
			FROM Vehicle_Order__c
			WHERE
				Vehicle_ID__r.Seller_Opportunity_ID__c IN :newList AND
				Vehicle_Sale_Complete__c = TRUE
		];

		Set<Id> vehicleIdsWithSaleComplete = new Set<Id>();
		for (Vehicle_Order__c vehicleOrder : vehicleOrdersWithSaleComplete) {
			vehicleIdsWithSaleComplete.add(vehicleOrder.Vehicle_ID__c);
		}

		for (Opportunity o : newList) {
			Boolean previousStageWasHandover = oldMap != null && oldMap.get(o.Id).StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER;
			if (!previousStageWasHandover && o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER && !vehicleIdsWithSaleComplete.contains(o.Vehicle_ID__c)) {
				o.StageName.addError('Cannot change to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER + ': vehicle does not have a completed sale');
			}
		}
	}

	// TODO(max.woghiren): Create a method or class to handle stage change validation
	// boilerplate (https://shift.phacility.com/T2081).
	static void validateStageChangeToSell(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		List<Vehicle_Order__c> vehicleOrdersWithReturn = [
			SELECT Vehicle_ID__c
			FROM Vehicle_Order__c
			WHERE
				Vehicle_ID__r.Seller_Opportunity_ID__c IN :newList AND
				Vehicle_Returned__c = TRUE
		];

		Set<Id> vehicleIdsWithReturn = new Set<Id>();
		for (Vehicle_Order__c vehicleOrder : vehicleOrdersWithReturn) {
			vehicleIdsWithReturn.add(vehicleOrder.Vehicle_ID__c);
		}

		for (Opportunity o : newList) {
			Boolean previousStageWasHandoverOrSold = oldMap != null && (oldMap.get(o.Id).StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER || oldMap.get(o.Id).StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD);
			if (previousStageWasHandoverOrSold && o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL && !vehicleIdsWithReturn.contains(o.Vehicle_ID__c)) {
				o.StageName.addError('Cannot change from stage ' + oldMap.get(o.Id).StageName + ' to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL + ': vehicle has not been returned');
			}
		}
	}

	static void validateStageChangeToPrepareCarForSale(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		for (Opportunity o : newList) {
			Boolean previousStageWasNotPrepare = oldMap != null && oldMap.get(o.Id).StageName != ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
			if (previousStageWasNotPrepare && o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE && o.Seller_Contract_Signed_On__c == null) {
				o.StageName.addError('Cannot change to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE + ': Seller Contract Signed On cannot be empty');
			}
		}
	}

	static void validatePublicIds(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		for (Opportunity o : newList) {
			if (oldMap.get(o.Id).Public_ID__c != null && o.Public_ID__c != oldMap.get(o.Id).Public_ID__c) {
				o.addError('Attempt to change Public_ID__c from ' + oldMap.get(o.Id).Public_ID__c + ' to ' + o.Public_ID__c);
			}
		}
	}

	static void updateSellerContracts(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		List<Shift_Contract__c> contractsToUpdate = new List<Shift_Contract__c>();
		for (Opportunity o : newList) {
			Boolean previousStageWasPrepare = (oldMap != null && oldMap.get(o.Id).StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE);
			if (o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE && !previousStageWasPrepare) {
				if (o.Seller_Contract_ID__c == null || o.Days_Guaranteed__c == null) {
					addTask(o.Id, ShiftConstants.TASK_SUBJECT_INPUT_CONTRACT_EXPIRATION_DATE);
					continue;
				}
				contractsToUpdate.add(new Shift_Contract__c(
					Id = o.Seller_Contract_ID__c,
					Expires_On__c = Date.today().addDays(Integer.valueOf(o.Days_Guaranteed__c))));
			} else if (o.StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL && previousStageWasPrepare) {
				if (o.Seller_Contract_ID__c == null || o.Days_Guaranteed__c == null) {
					addTask(o.Id, ShiftConstants.TASK_SUBJECT_REVIEW_CONTRACT_EXPIRATION_DATE);
					continue;
				}
				if (o.Entered_Stage_Prepare_Car_For_Sale__c.addDays(7) > DateTime.now()) {
					continue;
				}
				contractsToUpdate.add(new Shift_Contract__c(
					Id = o.Seller_Contract_ID__c,
					Expires_On__c = Date.today().addDays(Integer.valueOf(o.Days_Guaranteed__c))));
			}
		}
		update contractsToUpdate;
	}

	static void createTradeInPricingTasks(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		List<Task> tasks = new List<Task>();
		for (Opportunity o: newList) {
			Boolean previousTradeIn = (oldMap != null && oldMap.get(o.Id).Trade_In__c);
			Boolean currentTradeIn = o.Trade_In__c;
			if (currentTradeIn && !previousTradeIn) {
				String subject = SUBJECT_TRADE_IN_PRICING_PREFIX + o.Name;
				tasks.add(ShiftTasks.createTask(o, subject, ShiftConstants.TASK_TEAM_PRICING, ShiftUsers.vehicleValuationUserId()));
			}
		}
		Database.DMLOptions dmlOptions = new Database.DMLOptions();
		dmlOptions.EmailHeader.TriggerUserEmail = TRUE;
		Database.insert(tasks, dmlOptions);
	}

	static void advanceBuyerStages(List<Opportunity> newList) {
		List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
		for (Opportunity o : newList) {
			if (o.LeadSource == ShiftConstants.LEAD_SOURCE_DRIVESHIFT && o.StageName == ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS) {
				Opportunity opportunityToUpdate = new Opportunity(Id = o.Id, StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED);
				opportunitiesToUpdate.add(opportunityToUpdate);
			}
		}
		update opportunitiesToUpdate;
	}

	public static void addTasksIfNotExtant(List<Task> existingTasks, List<Task> tasksToCreateForOpportunities) {
		Set<Id> opportunityIdsWithExisitingTasks = new Set<Id>();
		for (Task task : existingTasks) {
			opportunityIdsWithExisitingTasks.add(task.WhatId);
		}

		List<Task> tasks = new List<Task>();
		for (Task task : tasksToCreateForOpportunities) {
			if (!opportunityIdsWithExisitingTasks.contains(task.WhatId)) {
				tasks.add(task);
			}
		}
		insert tasks;
		}
	static void updatePrice(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		Map <Id, Double> vehicleIdToPriceAdjustmentMap = new Map<Id, Double>();
		for (Opportunity o : newList) {
			Opportunity oldOpp = oldMap.get(o.Id);
			if (oldOpp.Evaluation_Price_Adjustment__c == o.Evaluation_Price_Adjustment__c) {
				continue;
			}
			Decimal priceAdjustmentDiff = o.Evaluation_Price_Adjustment__c;
			if (oldOpp.Evaluation_Price_Adjustment__c != null) {
				priceAdjustmentDiff -= oldOpp.Evaluation_Price_Adjustment__c;
			}
			o.Guaranteed_Price__c += priceAdjustmentDiff;
			o.Quoted_Sale_Price__c += priceAdjustmentDiff;
			vehicleIdToPriceAdjustmentMap.put(o.Vehicle_ID__c, priceAdjustmentDiff);
		}
		List <Vehicle__c> vehicles = [
			SELECT Id, List_Price__c
			FROM Vehicle__c
			WHERE
				Id IN :vehicleIdToPriceAdjustmentMap.keySet()
		];
		for (Vehicle__c v: vehicles) {
			v.List_Price__c += vehicleIdToPriceAdjustmentMap.get(v.Id);
		}
		update vehicles;
	}

	static void updateParkingLots(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		Set<Id> vehicleIds = new Set<Id>();
		for (Opportunity o : newList) {
			vehicleIds.add(o.Vehicle_ID__c);
		}
		Map<Id, Vehicle__c> vehicleMap = new Map<Id, Vehicle__c>([
			SELECT Id, Parking_Lot_ID__c, Listing_Region_ID__c
			FROM Vehicle__c
			WHERE Id IN :vehicleIds
		]);
		Set<Id> relevantRegionIds = new Set<Id>();
		for (Opportunity o : newList) {
			Vehicle__c vehicle = vehicleMap.get(o.Vehicle_ID__c);
			if (vehicle == null) {
				continue;
			}
			relevantRegionIds.add(vehicle.Listing_Region_ID__c);
		}
		Map<Id, Id> regionIdToPrimaryParkingLotId = ShiftParkingLots.getRegionIdToPrimaryParkingLotIdMap(relevantRegionIds);

		List<Vehicle__c> vehiclesToUpdate = new List<Vehicle__c>();
		for (Opportunity o : newList) {
			Boolean previousStageWasPrepare = (oldMap != null && oldMap.get(o.Id).StageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE);
			if (previousStageWasPrepare || o.StageName != ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE) {
				continue;
			}
			Vehicle__c vehicle = vehicleMap.get(o.Vehicle_ID__c);
			if (vehicle == null) {
				continue;
			}
			Id regionId = vehicle.Listing_Region_ID__c;
			Id primaryParkingLotId = regionIdToPrimaryParkingLotId.get(regionId);
			if (primaryParkingLotId == null) {
				o.addError('No primary parking lot for region ' + regionId);
				continue;
			}
			vehiclesToUpdate.add(new Vehicle__c(
				Id = o.Vehicle_ID__c,
				Parking_Lot_ID__c = primaryParkingLotId
			));
		}
		update vehiclesToUpdate;
	}

	@TestVisible
	static void updateInsideSalesRep(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		String profileName;
		Set<Id> changedOwnerIds = new Set<Id>();
		for (Opportunity o : newList) {
			if (oldMap == null || oldMap.get(o.Id).OwnerId != o.OwnerId) {
				changedOwnerIds.add(o.OwnerId);
			}
		}
		if (changedOwnerIds.isEmpty()) {
			return;
		}
		Map<Id, User> users = new Map<Id, User>([SELECT ID, Profile.Name FROM User Where Id IN :changedOwnerIds]);

		for (Opportunity o : newList) {
			if (changedOwnerIds.contains(o.OwnerId)) {
				profileName = users.get(o.OwnerId).Profile.Name;
				if (ISR_PROFILE_NAMES.contains(profileName)) {
					o.Inside_Sales_Representative__c = o.OwnerId;
				}
			}
		}
	}

	static List<Id> getBuyerOpportunityIdsForSellerOpportunityIds(List<Id> opportunityIds) {
		List<Vehicle_Order__c> orders = [
			SELECT Buyer_Opportunity_ID__c
			FROM Vehicle_Order__c
			WHERE Vehicle_ID__r.Seller_Opportunity_ID__c IN :opportunityIds
		];
		List<Id> buyerOpportunityIds = new List<Id>();
		for (Vehicle_Order__c o : orders) {
			buyerOpportunityIds.add(o.Buyer_Opportunity_ID__c);
		}
		return buyerOpportunityIds;
	}

	static void calculateAndSetSellerFinancials(List<Opportunity> opportunities) {
		List<ID> vehicleIDs = new List<ID>();
		for (Opportunity co : opportunities) {
			vehicleIDs.add(co.Vehicle_ID__c);
		}

		Map<ID, Vehicle__c> vehicles = new Map<ID, Vehicle__c>([SELECT ID, Paperwork_Fee_Pending__c, List_Price__c, Purchased_Vehicle_Order_ID__r.Final_Sale_Price__c
																FROM Vehicle__c WHERE ID IN :vehicleIDs]);
		for (Opportunity co : opportunities) {
			Vehicle__c cv = vehicles.get(co.Vehicle_ID__c);
			ShiftPayments.calculateSellerOpportunityFinancials(co, cv);
		}
	}

	@future
	static void processIncentives(List<Id> opportunityIds) {
		// TODO (bradley): When buyer stage changes are automated, query directly on the buyer stage change.
		opportunityIds.addAll(getBuyerOpportunityIdsForSellerOpportunityIds(opportunityIds));

		List<Applied_Incentive__c> appliedIncentives = [
			SELECT Incentive_ID__c, Incentive_ID__r.Incentive_Program_ID__c, Opportunity_ID__c
			FROM Applied_Incentive__c
			WHERE Opportunity_ID__c IN :opportunityIds
		];

		if (appliedIncentives.isEmpty()) {
			return;
		}

		List<Id> incentiveProgramIds = new List<Id>();
		for (Applied_Incentive__c a : appliedIncentives) {
			incentiveProgramIds.add(a.Incentive_ID__r.Incentive_Program_ID__c);
		}

		Map<Id, Incentive_Program__c> incentivePrograms = new Map<Id, Incentive_Program__c>([
			SELECT Id, Payout__c, Payout_Method__c, Referrer_Payout__c, Referrer_Payout_Method__c
			FROM Incentive_Program__c
			WHERE Id IN :incentiveProgramIds
		]);
		
		Map<Id, Id> opportunityIdToIncentiveId = new Map<Id, Id>();
		Map<Id, Incentive_Program__c> opportunityIdToIncentiveProgram = new Map<Id, Incentive_Program__c>();
		Map<Id, Applied_Incentive__c> opportunityIdToPaidAppliedIncentive = new Map<Id, Applied_Incentive__c>();
		for (Applied_Incentive__c a : appliedIncentives) {
			if (!opportunityIdToIncentiveProgram.containsKey(a.Opportunity_ID__c) ||
				a.Incentive_ID__r.Incentive_Program_Payout__c > opportunityIdToIncentiveProgram.get(a.Opportunity_ID__c).Payout__c) {
				opportunityIdToIncentiveProgram.put(a.Opportunity_ID__c, incentivePrograms.get(a.Incentive_ID__r.Incentive_Program_ID__c));
				opportunityIdToIncentiveId.put(a.Opportunity_ID__c, a.Incentive_ID__c);
				opportunityIdToPaidAppliedIncentive.put(a.Opportunity_ID__c, a);
			}
		}

		Map<Id, Incentive__c> incentives = new Map<Id, Incentive__c>([
			SELECT Id, Email__c, Completed_Sales__c, Incentive_Program_ID__r.Referrer_Payout__c, Incentive_Program_ID__r.Referrer_Payout_Method__c
			FROM Incentive__c
			WHERE Id IN :opportunityIdToIncentiveId.values()
		]);

		List<Contact> referrerContacts = [SELECT Id, Email, FirstName, Incentive_Token__c FROM Contact WHERE Incentive_ID__c IN :opportunityIdToIncentiveId.values()];
		Map<String, Contact> emailToContact = new Map<String, Contact>();
		for (Contact c : referrerContacts) {
			emailToContact.put(c.Email, c);
		}

		List<Contact> refereeContacts = [
			SELECT
			Id, Email, AccountId, FirstName, Incentive_Token__c
			FROM Contact
			WHERE AccountId IN
				(
					SELECT AccountId
					FROM Opportunity
					WHERE Id IN :opportunityIdToIncentiveProgram.keySet()
				)
		];

		Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();
		for (Contact c : refereeContacts) {
			accountIdToContact.put(c.AccountId, c);
		}

		Map<Id, Opportunity> refereeOpportunities = new Map<Id, Opportunity>([
			SELECT
			Id, RecordTypeId, Account_Email__c, AccountId, Marketing_Cost__c
			FROM Opportunity
			WHERE Id IN :opportunityIdToIncentiveProgram.keySet()
		]);

		List<Task> tasks = new List<Task>();
		for (Opportunity opp : refereeOpportunities.values()) {
			Incentive_Program__c incentiveProgram = opportunityIdToIncentiveProgram.get(opp.Id);
			Contact referrer = emailToContact.get(incentives.get(opportunityIdToIncentiveId.get(opp.Id)).Email__c);
			Contact referee = accountIdToContact.get(opp.AccountId);
			String transactionType = 'seller';
			if (isBuyerOpportunity(opp)) {
				transactionType = 'buyer';
			}

			if (incentiveProgram.Referrer_Payout__c > 0) {
				String referrerTaskDescription = 'Pay $' + incentiveProgram.Referrer_Payout__c + ' to ' + referrer.Email +
					'\n\nPayout Method: ' + incentiveProgram.Referrer_Payout_Method__c +
					'\nE-mail type: Referrer' +
					'\nReferee name: ' + referee.FirstName +
					'\nSale type: ' +  transactionType +
					'\nIncentive token: ' + referrer.Incentive_Token__c;

				tasks.add(ShiftTasks.createTask(referrer, 'Pay referrer bonus', ShiftConstants.TASK_TEAM_USER_HAPPINESS, referrerTaskDescription));
			}

			if (incentiveProgram.Payout__c > 0) {
				String refereeTaskDescription = 'Pay $' + incentiveProgram.Payout__c + ' to ' + referee.Email +
					'\n\nPayout Method: ' + incentiveProgram.Payout_Method__c +
					'\nE-mail type: Was referred' +
					'\nReferrer name: ' + referrer.FirstName +
					'\nSale type: ' +  transactionType +
					'\nIncentive token: ' + referee.Incentive_Token__c;

				tasks.add(ShiftTasks.createTask(referee, 'Pay referee bonus', ShiftConstants.TASK_TEAM_USER_HAPPINESS, refereeTaskDescription));
			}

			if (opp.Marketing_Cost__c == null) {
			  opp.Marketing_Cost__c = incentiveProgram.Payout__c + incentiveProgram.Referrer_Payout__c;
			} else {
			  opp.Marketing_Cost__c += incentiveProgram.Payout__c + incentiveProgram.Referrer_Payout__c;
			}
		}
		insert tasks;
		update refereeOpportunities.values();

		for (Id id : opportunityIdToIncentiveId.values()) {
			Incentive__c incentive = incentives.get(id);
			if (incentive.Completed_Sales__c == null) {
				incentive.Completed_Sales__c = 1;
			} else {
				incentive.Completed_Sales__c = incentive.Completed_Sales__c + 1;
			}

			incentives.put(id, incentive);
		}
		update incentives.values();

		for (Applied_Incentive__c a : opportunityIdToPaidAppliedIncentive.values()) {
			a.Was_Sent_For_Payment__c = TRUE;
		}
		update opportunityIdToPaidAppliedIncentive.values();
	}

	public static void beforeInsert(List<Opportunity> newList) {
		RecordTypeSplit split = splitByRecordType(newList);
		if (!split.sellerOpportunities.isEmpty()) {
			validatePricing(split.sellerOpportunities);
			validateSpecificCarSearchOnHandoverOrSold(null, split.sellerOpportunities);
			validateStageChangeToHandover(null, split.sellerOpportunities);
			validateStageChangeToSell(null, split.sellerOpportunities);
			validateStageChangeToPrepareCarForSale(null, split.sellerOpportunities);
			updateInsideSalesRep(null, split.sellerOpportunities);
			calculateAndSetSellerFinancials(split.sellerOpportunities);
		}
	}

	public static void beforeUpdate(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		validatePublicIds(oldMap, newList);
		RecordTypeSplit split = splitByRecordType(newList);
		if (!split.sellerOpportunities.isEmpty()) {
			validatePricing(split.sellerOpportunities);
			validateSpecificCarSearchOnHandoverOrSold(oldMap, split.sellerOpportunities);
			validateStageChangeToHandover(oldMap, split.sellerOpportunities);
			validateStageChangeToSell(oldMap, split.sellerOpportunities);
			validateStageChangeToPrepareCarForSale(oldMap, split.sellerOpportunities);
			updatePrice(oldMap, split.sellerOpportunities);
			updateInsideSalesRep(oldMap, split.sellerOpportunities);
			calculateAndSetSellerFinancials(split.sellerOpportunities);
		}
	}

	public static void afterInsert(List<Opportunity> newList) {
		RecordTypeSplit split = splitByRecordType(newList);
		if (!split.sellerOpportunities.isEmpty()) {
			handleStageChanges(null, split.sellerOpportunities);
			updateSellerContracts(null, split.sellerOpportunities);
			createTradeInPricingTasks(null, split.sellerOpportunities);
			ShiftVehicles.updateCanBeListed(null, split.sellerOpportunities);
			updateParkingLots(null, split.sellerOpportunities);
		}
		if (!split.buyerOpportunities.isEmpty()) {
			advanceBuyerStages(split.buyerOpportunities);
		}
	}

	public static void afterUpdate(Map<Id, Opportunity> oldMap, List<Opportunity> newList) {
		RecordTypeSplit split = splitByRecordType(newList);
		if (!split.sellerOpportunities.isEmpty()) {
			handleStageChanges(oldMap, split.sellerOpportunities);
			updateSellerContracts(oldMap, split.sellerOpportunities);
			createTradeInPricingTasks(oldMap, split.sellerOpportunities);
			ShiftVehicles.updateCanBeListed(oldMap, split.sellerOpportunities);
			updateParkingLots(oldMap, split.sellerOpportunities);
		}
	}

	public static final String WORKFLOW_IDENTIFIER_SELLER_NOTIFICATIONS = 'Seller Notifications';
	class SellerNotificationsWorkflow extends ShiftWorkflow.AbstractInstance {
		public SellerNotificationsWorkflow() {
			super(Opportunity.class, WORKFLOW_IDENTIFIER_SELLER_NOTIFICATIONS, 1);
		}
	}

	// This workflow is just a placeholder right now, and we place it here until
	// there is reason to create its own toplevel class. We create its single
	// task right now from within the props pipeline (see
	// ShiftProcessingPipeline) but don't have any actual workflow logic for it
	// yet.
	public static final String WORKFLOW_IDENTIFIER_WHOLESALING = 'Wholesaling';

	class WholesalingWorkflow extends ShiftWorkflow.AbstractInstance {
		public WholesalingWorkflow() {
			super(Opportunity.class, WORKFLOW_IDENTIFIER_WHOLESALING, 1);
		}
	}

	public static void loadWorkflows() {
		ShiftWorkflow.registerInstanceType(WORKFLOW_IDENTIFIER_WHOLESALING, WholesalingWorkflow.class);
		ShiftWorkflow.registerInstanceType(WORKFLOW_IDENTIFIER_SELLER_NOTIFICATIONS, SellerNotificationsWorkflow.class);
	}
}