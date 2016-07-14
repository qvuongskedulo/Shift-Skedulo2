public with sharing class BluewolfTestDriveRequestServices {
    public static Boolean byPassTrigger = false;

    @testVisible private static String RESCHEDULE_NEXT_STEP = 'CX - Schedule Another Test Drive';
    @testVisible private static String PAID_IN_FULL = 'Purchased Car - Paid In Full';

    @testVisible private static String CASE_OWNER_NAME = 'unowned';

    @testVisible private static String DRIVE_REQUEST_TYPE = 'Car Enthusiast Test Drive Request';
    @testVisible private static String FOLLOWUP_TYPE = 'Cancellation Follow Up';
    @testVisible private static String AVAILABLE_TYPE = 'Vehicle Available - Schedule Test Drives';
    @testVisible private static String UNAVAILABLE_TYPE = 'Vehicle Unavailable - Cancel Test Drives';

    @testVisible private static List<String> NO_RESCHEDULE_REASONS = new List<String> {
        'Customer bought another car (with Shift)',
        'Customer bought another car (not with Shift)',
        'Switched interest to another Shift car'
    };

    @testVisible
    private static Id caseOwnerId {
        get {
            if (caseOwnerId == null) {
                caseOwnerId = [SELECT Id FROM User WHERE Shift_Key__c = :CASE_OWNER_NAME].Id;
            }
            return caseOwnerId;
        }
        private set;
    }

    private static Select.Filter getRescheduledFilter() {
        return Select.Field.hasChanged(Test_Drive__c.Next_Steps__c).andx(
               Select.Field.isEqual(Test_Drive__c.Next_Steps__c, RESCHEDULE_NEXT_STEP)
        );
    }

    private static Select.Filter getCanceledFilter() {
        return Select.Field.hasChanged(Test_Drive__c.Canceled__c).andx(
            Select.Field.isEqual(Test_Drive__c.Canceled__c, true)
        ).andx(
            Select.Field.notIn(Test_Drive__c.Canceled_Reason__c, NO_RESCHEDULE_REASONS)
        );
    }
    private static List<Vehicle__c> newVehicles;
    private static Map<Id, Boolean> depositeReturnReasonMap;
    public static void requestDriveIfCanceled(List<Test_Drive__c> drives, Map<Id, Test_Drive__c> oldDrives) {
        if(byPassTrigger) return;
        
        List<Test_Drive__c> drivesRescheduled = getRescheduledFilter().filter(drives, oldDrives);
        List<Test_Drive__c> drivesCanceled = getCanceledFilter().filter(drives, oldDrives);

        List<Test_Drive__c> drivesToRequest = new List<Test_Drive__c>();
        drivesToRequest.addAll(drivesCanceled);
        drivesToRequest.addAll(drivesRescheduled);

        if (drivesToRequest.isEmpty()) {
            return;
        }

        Map<Id, Vehicle_Interest__c> vehicleInterestMap = new Map<Id, Vehicle_Interest__c>([
            SELECT Buyer_Opportunity_ID__c
            FROM   Vehicle_Interest__c
            WHERE  Id IN :BluewolfPluck.Ids(Test_Drive__c.Vehicle_Interest_ID__c, drivesToRequest)
        ]);

        List<Case> casesToCreate = new List<Case>();

        for (Test_Drive__c drive : drivesRescheduled) {
            casesToCreate.add(new Case(
                OwnerId = caseOwnerId,
                Case_Type__c = DRIVE_REQUEST_TYPE,
                Test_Drive_Notes__c = drive.Notes__c,
                Opportunity_ID__c = vehicleInterestMap.get(drive.Vehicle_Interest_ID__c).Buyer_Opportunity_ID__c,
                Test_Drive__c = drive.Id
            ));
        }
        for (Test_Drive__c drive : drivesCanceled) {
            casesToCreate.add(new Case(
                OwnerId = caseOwnerId,
                Case_Type__c = FOLLOWUP_TYPE,
                Test_Drive_Notes__c = drive.Notes__c,
                Opportunity_ID__c = vehicleInterestMap.get(drive.Vehicle_Interest_ID__c).Buyer_Opportunity_ID__c,
                Test_Drive__c = drive.Id
            ));
        }

        try {
            insert casesToCreate;
        } catch (DmlException ex) {
            for (Test_Drive__c drive : drives) {
                drive.addError(ex);
            }
        }
    }

    /* Update */
    public static void requestDriveIfAvailabilityChanges(List<Vehicle__c> vehicles, Map<Id, Vehicle__c> oldVehicles) {
        if(byPassTrigger) return;

        if(newVehicles == null) newVehicles = [SELECT Id, Sale_Pending__c, Going_To_Auction__c, Hold_For_Financing__c, Hold_For_Trade_In__c, On_Deposit__c, Needs_Repairs__c, In_Transit__c, Paperwork_Missing__c, Photos_Ready__c, Seller_Opportunity_Id__r.StageName FROM Vehicle__c WHERE Id =: vehicles];
        vehicles = (newVehicles == null || newVehicles.isEmpty()) ? vehicles: newVehicles;
        List<Case> casesToCreate = new List<Case>();
        Set<Id> vehiclesUnavailable = new Set<Id>();
        if(depositeReturnReasonMap == null) depositeReturnReasonMap = getDepositReturnReasonMap(vehicles);
        for (Vehicle__c vehicle : vehicles) {
            Vehicle__c oldVehicle = oldVehicles.get(vehicle.Id);
            Boolean currentComingSoon = getComingSoon(vehicle);
            Boolean currentSalePending = getSalePending(vehicle);
            Boolean currentReason = depositeReturnReasonMap.get(vehicle.Id);
            currentReason = currentReason == null? false: currentReason;
            if(oldVehicle != null){
                if (currentComingSoon != oldVehicle.Coming_Soon__c || currentSalePending != oldVehicle.Sale_Pending__c) {
                    Case createdCase = new Case(
                        OwnerId = caseOwnerId,
                        Vehicle_ID__c = vehicle.Id
                    );
    
                    Boolean currentSwitch = currentComingSoon != oldVehicle.Coming_Soon__c ? currentComingSoon : currentSalePending;
                    if (currentSwitch) {
                        createdCase.Case_Type__c = UNAVAILABLE_TYPE;
                        vehiclesUnavailable.add(vehicle.Id);
                    } else {
                        createdCase.Case_Type__c = AVAILABLE_TYPE;
                    }
                    system.debug(currentSalePending + '-' + oldVehicle.Sale_Pending__c + '-' + currentReason + '-' + createdCase);
                    if(currentSalePending == oldVehicle.Sale_Pending__c || (currentSalePending || !currentReason))
                        casesToCreate.add(createdCase);
                }
            }
        }

        //if (!vehiclesUnavailable.isEmpty()) {
        //    casesToCreate.addAll(createTestDriveCases(vehiclesUnavailable));
        //}

        if (casesToCreate.isEmpty()) {
            return;
        }

        try {
            insert casesToCreate;
        } catch (DMLException ex) {
            for (Vehicle__c vehicle : vehicles) {
                vehicle.addError(ex);
            }
        }
    }

    /* Update */
    public static void requestDriveIfSoldOrReturned(List<Vehicle_Order__c> orders, Map<Id, Vehicle_Order__c> oldOrders) {
        if(byPassTrigger) return;
    
        Map<Id, Case> casesByVehicle = new Map<Id, Case>();
        Set<Id> vehiclesUnavailable = new Set<Id>();

        for (Vehicle_Order__c order : orders) {
            Vehicle_Order__c oldOrder = oldOrders.get(order.Id);

            if (nowUnavailable(order, oldOrder)) {
                casesByVehicle.put(order.Vehicle_ID__c, new Case(
                    OwnerId = caseOwnerId,
                    Case_Type__c = UNAVAILABLE_TYPE,
                    Vehicle_ID__c = order.Vehicle_ID__c
                ));
                vehiclesUnavailable.add(order.Vehicle_ID__c);
            } else if (nowAvailable(order, oldOrder)) {
                casesByVehicle.put(order.Vehicle_ID__c, new Case(
                    OwnerId = caseOwnerId,
                    Case_Type__c = AVAILABLE_TYPE,
                    Vehicle_ID__c = order.Vehicle_ID__c
                ));
            }
        }

        List<Case> casesToCreate = new List<Case>(casesByVehicle.values());

        //if (!vehiclesUnavailable.isEmpty()) {
        //    casesToCreate.addAll(createTestDriveCases(vehiclesUnavailable));
        //}

        if (casesByVehicle.isEmpty()) {
            return;
        }

        try {
            insert casesByVehicle.values();
        } catch (DMLException ex) {
            for (Vehicle_Order__c order : orders) {
                order.addError(ex);
            }
        }
    }
    
    private static List<Case> createTestDriveCases(Set<Id> vehicleIds) {
        List<Case> casesToCreate = new List<Case>();

        List<Test_Drive__c> drivesToReschedule = [
            SELECT Id
            FROM   Test_Drive__c
            WHERE  Vehicle_Interest_ID__r.Vehicle_ID__c IN :vehicleIds
               AND Scheduled_For__c >= :DateTime.now()
        ];

        for (Test_Drive__c drive : drivesToReschedule) {
            casesToCreate.add(new Case(
                OwnerId = caseOwnerId,
                Case_Type__c = UNAVAILABLE_TYPE,
                Test_Drive__c = drive.Id
            ));
        }
        return casesToCreate;
    }

    private static Boolean getComingSoon(Vehicle__c vehicle) {
        
        Boolean result = vehicle.Needs_Repairs__c || vehicle.In_Transit__c || vehicle.Paperwork_Missing__c ==  'Yes - Less Than 7 Days Unavailable' || vehicle.Paperwork_Missing__c == 'Yes - More Than 7 Days Unavailable' || !vehicle.Photos_Ready__c;
        if(vehicle.Seller_Opportunity_Id__r.StageName == null || vehicle.Seller_Opportunity_Id__r.StageName != 'Prepare Car for Sale'){
            return result;
        }
        else{
            return true;
        }
        
    }

     private static Boolean nowAvailable(Vehicle_Order__c order, Vehicle_Order__c oldOrder) {
        if (order.Returned_On__c != null && oldOrder.Returned_On__c == null)
            return true;

        return false;
    }

    private static Boolean nowUnavailable(Vehicle_Order__c order, Vehicle_Order__c oldOrder) {
        Vehicle_Order__c calculatedOrder = new Vehicle_Order__c(
            Final_Sale_Price__c = order.Final_Sale_Price__c,
            Taxes_And_Registration__c = order.Taxes_And_Registration__c,
            Payment_Method__c = order.Payment_Method__c,
            Vehicle_Sale_Complete__c = order.Vehicle_Sale_Complete__c
        );
        calculatedOrder.recalculateFormulas();

        if (calculatedOrder.Vehicle_Purchased__c && !oldOrder.Vehicle_Purchased__c)
            return true;
        return false;
    }
    
    private static Boolean getSalePending(Vehicle__c vehicle) {
        // recalculateFormulas() is very broken, and doesn't work well
        // if more fields than whats needed are selected (such as a lookup or created date).
        Vehicle__c temp = new Vehicle__c(
            On_Deposit__c = vehicle.On_Deposit__c,
            Going_To_Auction__c = vehicle.Going_To_Auction__c,
            Hold_For_Financing__c = vehicle.Hold_For_Financing__c ,
            Hold_For_Trade_In__c = vehicle.Hold_For_Trade_In__c
        );
        temp.recalculateFormulas();
        return temp.Sale_Pending__c;
    }
    
    private static Map<Id, Boolean> getDepositReturnReasonMap(List<Vehicle__c> vehicles){
        Map<Id, Boolean> resultMap = new Map<Id, Boolean> ();
        
        Map<Id, List<Vehicle_Order__c>> vehicleInterestMap = BluewolfGroupBy.ids('Vehicle_Id__c', [SELECT Vehicle_Id__c, Deposit_Returned_Reason__c FROM Vehicle_Order__c WHERE Vehicle_ID__c = :vehicles ORDER BY LastModifiedDate]);
        for(Id vehicleId : vehicleInterestMap.keySet()){
            
            List<Vehicle_Order__c> orders = vehicleInterestMap.get(vehicleId);
            if(orders != null && !orders.isEmpty()){
                if(orders[0].Deposit_Returned_Reason__c == PAID_IN_FULL){
                    resultMap.put(vehicleId, true);
                }
                else{
                    resultMap.put(vehicleId, false);
                }
            }
            else{
                resultMap.put(vehicleId, false);
            }
        }
        
        return resultMap;
    }
    
     /* Insert */
    public static void requestDriveIfSoldOrReturned(List<Vehicle_Order__c> orders) {
        if(byPassTrigger) return;

        List<Case> casesToCreate = new List<Case>();

        for (Vehicle_Order__c order : orders) {
            if (nowUnavailable(order)) {
                casesToCreate.add(new Case(
                    OwnerId = caseOwnerId,
                    Case_Type__c = UNAVAILABLE_TYPE,
                    Vehicle_ID__c = order.Vehicle_ID__c
                ));
            }
        }

        if (casesToCreate.isEmpty()) {
            return;
        }

        try {
            insert casesToCreate;
        } catch (DMLException ex) {
            for (Vehicle_Order__c order : orders) {
                order.addError(ex);
            }
        }
    }
    
    private static Boolean nowUnavailable(Vehicle_Order__c order) {
        Vehicle_Order__c calculatedOrder = new Vehicle_Order__c(
            Final_Sale_Price__c = order.Final_Sale_Price__c,
            Taxes_And_Registration__c = order.Taxes_And_Registration__c,
            Payment_Method__c = order.Payment_Method__c,
            Vehicle_Sale_Complete__c = order.Vehicle_Sale_Complete__c
        );
        calculatedOrder.recalculateFormulas();

        return calculatedOrder.Vehicle_Purchased__c || order.Deposit_Accepted_On__c != null;
    }    
}