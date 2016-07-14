@isTest
private class BluewolfTestDriveRequestServicesTest {
    static final Integer BULK_COUNT = /*Limits.getLimitQueries() + */1;

    static Id sellerRecordTypeId {
        get {
            if (sellerRecordTypeId == null) {
                sellerRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id;
            }
            return sellerRecordTypeId;
        }
        private set;
    }

    static testmethod void requestDriveIfCanceled() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;    
        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Canceled__c, false)
            .put(Test_Drive__c.Notes__c, BluewolfSObjectFactory.provideUniqueString())
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Test_Drive__c> oldMap = new Map<Id, Test_Drive__c>(testDrives.deepClone(true /*Preserve Ids*/));
        for (Test_Drive__c testDrive : testDrives) {
            testDrive.Canceled__c = true;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfCanceled(testDrives, oldMap);
        Test.stopTest();

        Map<Id, Vehicle_Interest__c> interestMap = new Map<Id, Vehicle_Interest__c>(testInterests);
        Map<Id, Test_Drive__c> testDriveMap = new Map<Id, Test_Drive__c>(testDrives);

        List<Case> actualCases = [
            SELECT Opportunity_ID__c, Case_Type__c, Test_Drive_Notes__c,
                   Test_Drive__c, OwnerId
            FROM   Case
        ];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each test drive should get a case');

        for (Case actualCase : actualcases) {
            System.assertEquals(true, testDriveMap.containsKey(actualCase.Test_Drive__c), 'the case should be related to a test drive');
            Test_Drive__c drive = testDriveMap.get(actualCase.Test_Drive__c);

            Id opportunityId = interestMap.get(drive.Vehicle_Interest_ID__c).Buyer_Opportunity_ID__c;
            System.assertEquals(opportunityId, actualCase.Opportunity_ID__c, 'the opportunity id should be set correctly');

            System.assertEquals(drive.Notes__c, actualCase.Test_Drive_Notes__c, 'the notes should be copied over correctly');
            System.assertEquals(BluewolfTestDriveRequestServices.FOLLOWUP_TYPE, actualCase.Case_Type__c, 'the case type should be set correctly');
            System.assertEquals(testUser.Id, actualCase.OwnerId, 'the owner id should be set correctly');
        }
    }

    static testmethod void requestDriveIfCanceled_AlreadyCanceled() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Canceled__c, true)
            .put(Test_Drive__c.Notes__c, BluewolfSObjectFactory.provideUniqueString())
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Test_Drive__c> oldMap = new Map<Id, Test_Drive__c>(testDrives.deepClone(true /*Preserve Ids*/));

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfCanceled(testDrives, oldMap);
        Test.stopTest();

        List<Case> actualCases = [SELECT Opportunity_ID__c, Case_Type__c, Test_Drive_Notes__c, Test_Drive__c, OwnerId FROM Case];
        System.assertEquals(new List<Case>(), actualCases, 'there should be no cases');
    }

    static testmethod void requestDriveIfCanceled_RescheduleNextStep() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Canceled__c, true)
            .put(Test_Drive__c.Notes__c, BluewolfSObjectFactory.provideUniqueString())
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Test_Drive__c> oldMap = new Map<Id, Test_Drive__c>(testDrives.deepClone(true /*Preserve Ids*/));

        for (Test_Drive__c testDrive : testDrives) {
            testDrive.Next_Steps__c = BluewolfTestDriveRequestServices.RESCHEDULE_NEXT_STEP;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfCanceled(testDrives, oldMap);
        Test.stopTest();

        Map<Id, Vehicle_Interest__c> interestMap = new Map<Id, Vehicle_Interest__c>(testInterests);
        Map<Id, Test_Drive__c> testDriveMap = new Map<Id, Test_Drive__c>(testDrives);

        List<Case> actualCases = [
            SELECT Opportunity_ID__c, Case_Type__c, Test_Drive_Notes__c,
                   Test_Drive__c, OwnerId
            FROM   Case
        ];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each test drive should get a case');

        for (Case actualCase : actualcases) {
            System.assertEquals(true, testDriveMap.containsKey(actualCase.Test_Drive__c), 'the case should be related to a test drive');
            Test_Drive__c drive = testDriveMap.get(actualCase.Test_Drive__c);

            Id opportunityId = interestMap.get(drive.Vehicle_Interest_ID__c).Buyer_Opportunity_ID__c;
            System.assertEquals(opportunityId, actualCase.Opportunity_ID__c, 'the opportunity id should be set correctly');

            System.assertEquals(drive.Notes__c, actualCase.Test_Drive_Notes__c, 'the notes should be copied over correctly');
            System.assertEquals(BluewolfTestDriveRequestServices.DRIVE_REQUEST_TYPE, actualCase.Case_Type__c, 'the case type should be set correctly');
            System.assertEquals(testUser.Id, actualCase.OwnerId, 'the owner id should be set correctly');
        }
    }

    static testmethod void requestDriveIfCanceled_InvalidReason() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        final String CANCEL_REASON_INVALID = new List<String>(BluewolfTestDriveRequestServices.NO_RESCHEDULE_REASONS)[0];

        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Canceled__c, false)
            .put(Test_Drive__c.Notes__c, BluewolfSObjectFactory.provideUniqueString())
            .put(Test_Drive__c.Canceled_Reason__c, CANCEL_REASON_INVALID)
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Test_Drive__c> oldMap = new Map<Id, Test_Drive__c>(testDrives.deepClone(true /*Preserve Ids*/));

        for (Test_Drive__c testDrive : testDrives) {
            testDrive.Canceled__c = true;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfCanceled(testDrives, oldMap);
        Test.stopTest();

        List<Case> actualCases = [SELECT Opportunity_ID__c, Case_Type__c, Test_Drive_Notes__c, Test_Drive__c, OwnerId FROM Case];
        System.assertEquals(new List<Case>(), actualCases, 'there should be no cases');
    }

    static testmethod void requestDriveIfCanceled_Trigger() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Canceled__c, false)
            .put(Test_Drive__c.Notes__c, BluewolfSObjectFactory.provideUniqueString())
            .count(BULK_COUNT).create().getRecords();

        for (Test_Drive__c testDrive : testDrives) {
            testDrive.Canceled__c = true;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testDrives;
        Test.stopTest();

        Map<Id, Vehicle_Interest__c> interestMap = new Map<Id, Vehicle_Interest__c>(testInterests);
        Map<Id, Test_Drive__c> testDriveMap = new Map<Id, Test_Drive__c>(testDrives);

        List<Case> actualCases = [
            SELECT Opportunity_ID__c, Case_Type__c, Test_Drive_Notes__c,
                   Test_Drive__c, OwnerId
            FROM   Case
        ];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each test drive should get a case');

        for (Case actualCase : actualcases) {
            System.assertEquals(true, testDriveMap.containsKey(actualCase.Test_Drive__c), 'the case should be related to a test drive');
            Test_Drive__c drive = testDriveMap.get(actualCase.Test_Drive__c);

            Id opportunityId = interestMap.get(drive.Vehicle_Interest_ID__c).Buyer_Opportunity_ID__c;
            System.assertEquals(opportunityId, actualCase.Opportunity_ID__c, 'the opportunity id should be set correctly');

            System.assertEquals(drive.Notes__c, actualCase.Test_Drive_Notes__c, 'the notes should be copied over correctly');
            System.assertEquals(BluewolfTestDriveRequestServices.FOLLOWUP_TYPE, actualCase.Case_Type__c, 'the case type should be set correctly');
            System.assertEquals(testUser.Id, actualCase.OwnerId, 'the owner id should be set correctly');
        }
    }

    static testmethod void requestDriveIfCanceled_Trigger_AlreadyCanceled() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Canceled__c, true)
            .put(Test_Drive__c.Notes__c, BluewolfSObjectFactory.provideUniqueString())
            .count(BULK_COUNT).create().getRecords();

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testDrives;
        Test.stopTest();

        List<Case> actualCases = [SELECT Opportunity_ID__c, Case_Type__c, Test_Drive_Notes__c, Test_Drive__c, OwnerId FROM Case];
        System.assertEquals(new List<Case>(), actualCases, 'there should be no cases');
    }

    static testmethod void requestDriveIfAvailabilityChanges_ComingSoon() {
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Scheduled_For__c, DateTime.now().addDays(1))
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle__c> oldVehicles = new Map<Id, Vehicle__c>(testVehicles.deepClone(true/*preserve Ids*/));
        for (Vehicle__c vehicle : oldVehicles.values()) {
            vehicle.recalculateFormulas();
        }

        for (Vehicle__c vehicle : testVehicles) {
            vehicle.In_Transit__c = true;
        }

        update testVehicles;
        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;
        
        BluewolfVehicleTriggerHandler.bypassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfAvailabilityChanges(testVehicles, oldVehicles);
        Test.stopTest();

        List<Case> allCases = [SELECT Vehicle_ID__c, Case_Type__c, Test_Drive__c, OwnerId FROM Case];
        List<Case> vehicleCases = Select.Field.notNull(Case.Vehicle_ID__c).filter(allCases);

        System.assertEquals(BULK_COUNT, vehicleCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, vehicleCases), 'each vehicle should get a case');

        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.UNAVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, allCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, allCases), 'each case should have the correct owner');
    }
    static testmethod void requestDriveIfAvailabilityChanges_ComingSoon_PreviousDrives() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        List<Vehicle_Interest__c> testInterests = new BluewolfSObjectBuilder(Vehicle_Interest__c.sObjectType)
            .put(Vehicle_Interest__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .put(Vehicle_Interest__c.Buyer_Opportunity_ID__c, BluewolfSObjectFactory.provideParents(testOpportunities))
            .count(BULK_COUNT).create().getRecords();

        List<Test_Drive__c> testDrives = new BluewolfSObjectBuilder(Test_Drive__c.sObjectType)
            .put(Test_Drive__c.Vehicle_Interest_ID__c, BluewolfSObjectFactory.provideParents(testInterests))
            .put(Test_Drive__c.Scheduled_For__c, DateTime.now().addDays(-1))
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle__c> oldVehicles = new Map<Id, Vehicle__c>(testVehicles.deepClone(true/*preserve Ids*/));
        for (Vehicle__c vehicle : oldVehicles.values()) {
            vehicle.recalculateFormulas();
        }

        for (Vehicle__c vehicle : testVehicles) {
            vehicle.In_Transit__c = true;
        }
        update testVehicles;
        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;
        BluewolfVehicleTriggerHandler.bypassTrigger = false;
        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfAvailabilityChanges(testVehicles, oldVehicles);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.UNAVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }

    static testmethod void requestDriveIfAvailabilityChanges_NoChange() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle__c> oldVehicles = new Map<Id, Vehicle__c>(testVehicles.deepClone(true /*preserve Ids*/));
        for (Vehicle__c vehicle : oldVehicles.values()) {
            vehicle.recalculateFormulas();
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfAvailabilityChanges(testVehicles, oldVehicles);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(new List<Case>(), actualCases, 'no cases should be created');
    }

    static testmethod void requestDriveIfAvailabilityChanges_ComingSoon_Trigger_Update() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        for (Vehicle__c vehicle : testVehicles) {
            vehicle.In_Transit__c = true;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testVehicles;
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.UNAVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }
      
    static testmethod void requestDriveIfAvailabilityChanges_NotComingSoon_Trigger() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, true)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        for (Vehicle__c vehicle : testVehicles) {
            vehicle.In_Transit__c = false;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testVehicles;
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.AVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }

    static testmethod void requestDriveIfAvailabilityChanges_NoChange_Trigger() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testVehicles;
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(new List<Case>(), actualCases, 'no cases should be created');
    }

    static testmethod void requestDriveIfSoldOrReturned_Available() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .put(Vehicle_Order__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle_Order__c> oldOrders = new Map<Id, Vehicle_Order__c>(testOrders.deepClone(true/*preserve Ids*/));

        for (Vehicle_Order__c order : testOrders) {
            order.Returned_On__c = Date.today();
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfSoldOrReturned(testOrders, oldOrders);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.AVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }

    static testmethod void requestDriveIfSoldOrReturned_PaidInFull() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .put(Vehicle_Order__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle_Order__c> oldOrders = new Map<Id, Vehicle_Order__c>(testOrders.deepClone(true/*preserve Ids*/));

        for (Vehicle_Order__c order : testOrders) {
            order.Deposit_Returned_Reason__c = BluewolfTestDriveRequestServices.PAID_IN_FULL;
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfSoldOrReturned(testOrders, oldOrders);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(0, actualCases.size(), 'no cases should be created');
    }

    static testmethod void requestDriveIfSoldOrReturned_SameVehicle() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle_Order__c> oldOrders = new Map<Id, Vehicle_Order__c>(testOrders.deepClone(true/*preserve Ids*/));

        for (Vehicle_Order__c order : testOrders) {
            order.Returned_On__c = Date.today();
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfSoldOrReturned(testOrders, oldOrders);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(1, actualCases.size(), 'there should only be one case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.AVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }

    static testmethod void requestDriveIfSoldOrReturned_NoChange() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        Map<Id, Vehicle_Order__c> oldOrders = new Map<Id, Vehicle_Order__c>(testOrders.deepClone(true/*preserve Ids*/));

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfSoldOrReturned(testOrders, oldOrders);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(new List<Case>(), actualCases, 'no cases should be created');
    }

    static /*testmethod*/ void requestDriveIfSoldOrReturned_Available_Trigger() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        // We're having trouble getting the data to set up correctly.
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        List<Opportunity> sellerOpportunities = new BluewolfSObjectBuilder(Opportunity.sObjectType)
            .put(Opportunity.RecordTypeId, sellerRecordTypeId)
            .put(Opportunity.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .count(BULK_COUNT).create().getRecords();

        for (Integer n = 0; n < BULK_COUNT; n++) {
            testVehicles[n].Seller_Opportunity_ID__c = sellerOpportunities[n].Id;
        }
        update testVehicles;

        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .put(Vehicle_Order__c.Final_Sale_Price__c, 3.50)
            .put(Vehicle_Order__c.Taxes_And_Registration__c, 3.50)
            .put(Vehicle_Order__c.Payment_Method__c, 'Poultry')
            .put(Vehicle_Order__c.Vehicle_Sale_Complete__c, true)
            .put(Vehicle_Order__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .put(Vehicle_Order__c.Deposit_Accepted_On__c, Date.today())
            .count(BULK_COUNT).create().getRecords();

        for (Vehicle_Order__c order : testOrders) {
            order.Returned_On__c = Date.today();
            order.Returned_Reason__c = 'yes';
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testOrders;
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.AVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }

    static testmethod void requestDriveIfSoldOrReturned_Unavailable_Trigger_Update() {
        BluewolfTestDriveRequestServices.byPassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .put(Vehicle_Order__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .count(BULK_COUNT).create().getRecords();

        for (Vehicle_Order__c order : testOrders) {
            order.Deposit_Accepted_On__c = Date.today();
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfTestDriveRequestServices.byPassTrigger = false;
        Test.startTest();
            update testOrders;
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.UNAVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }
    
    static testmethod void requestDriveIfAvailabilityChanges_SalePending() {
        
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.On_Deposit__c, false)
            .put(Vehicle__c.Going_To_Auction__c, false)
            .put(Vehicle__c.Hold_For_Financing__c, false)
            .put(Vehicle__c.Hold_For_Trade_In__c, false)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);


        Map<Id, Vehicle__c> oldVehicles = new Map<Id, Vehicle__c>(testVehicles.deepClone(true/*preserve Ids*/));
        for (Vehicle__c vehicle : oldVehicles.values()) {
            vehicle.recalculateFormulas();
        }

        for (Vehicle__c vehicle : testVehicles) {
            vehicle.Hold_For_Financing__c = true;
        }
        update testVehicles;
        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;
        BluewolfVehicleTriggerHandler.bypassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfAvailabilityChanges(testVehicles, oldVehicles);
        Test.stopTest();

        List<Case> allCases = [SELECT Vehicle_ID__c, Case_Type__c, Test_Drive__c, OwnerId FROM Case];
        List<Case> vehicleCases = Select.Field.notNull(Case.Vehicle_ID__c).filter(allCases);

        System.assertEquals(BULK_COUNT, vehicleCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, vehicleCases), 'each vehicle should get a case');

        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.UNAVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, allCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, allCases), 'each case should have the correct owner');
    }
    
    static testmethod void requestDriveIfAvailabilityChanges_NotSalePending() {
        
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.On_Deposit__c, false)
            .put(Vehicle__c.Going_To_Auction__c, false)
            .put(Vehicle__c.Hold_For_Financing__c, true)
            .put(Vehicle__c.Hold_For_Trade_In__c, false)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(BULK_COUNT).create().getRecords();

        List<Opportunity> testOpportunities = BluewolfSObjectFactory.create(BULK_COUNT, Opportunity.sObjectType);

        Map<Id, Vehicle__c> oldVehicles = new Map<Id, Vehicle__c>(testVehicles.deepClone(true/*preserve Ids*/));
        for (Vehicle__c vehicle : oldVehicles.values()) {
            vehicle.recalculateFormulas();
        }

        for (Vehicle__c vehicle : testVehicles) {
            vehicle.Hold_For_Financing__c = false;
        }

        update testVehicles;
        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;
        BluewolfVehicleTriggerHandler.bypassTrigger = false;
        Test.startTest();
            BluewolfTestDriveRequestServices.requestDriveIfAvailabilityChanges(testVehicles, oldVehicles);
        Test.stopTest();

        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.AVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }
    
    static testmethod void requestDriveIfSoldOrReturned_Unavailable_Trigger_Insert() {
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        BluewolfVehicleOrderTriggerHandler.bypassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .count(BULK_COUNT).create().getRecords();

        List<Vehicle_Order__c> testOrders = new BluewolfSObjectBuilder(Vehicle_Order__c.sObjectType)
            .put(Vehicle_Order__c.Vehicle_ID__c, BluewolfSObjectFactory.provideParents(testVehicles))
            .count(BULK_COUNT).build().getRecords();

        for (Vehicle_Order__c order : testOrders) {
            order.Deposit_Accepted_On__c = Date.today();
        }

        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfTestDriveRequestServices.caseOwnerId = testUser.Id;

        BluewolfVehicleOrderTriggerHandler.bypassTrigger = false;
        Test.startTest();
            insert testOrders;
        Test.stopTest();
        BluewolfVehicleTriggerHandler.bypassTrigger = false;
        List<Case> actualCases = [SELECT Vehicle_ID__c, Case_Type__c, OwnerId FROM Case];
        System.assertEquals(BULK_COUNT, actualCases.size(), 'each vehicle should get a case');
        System.assertEquals(BluewolfPluck.Ids(testVehicles), BluewolfPluck.Ids(Case.Vehicle_ID__c, actualCases), 'each vehicle should get a case');
        System.assertEquals(new Set<String> { BluewolfTestDriveRequestServices.UNAVAILABLE_TYPE }, BluewolfPluck.Strings(Case.Case_Type__c, actualCases), 'the cases should be the correct type');
        System.assertEquals(new Set<Id> { testUser.Id }, BluewolfPluck.Ids(Case.OwnerId, actualCases), 'each case should have the correct owner');
    }    
   
}