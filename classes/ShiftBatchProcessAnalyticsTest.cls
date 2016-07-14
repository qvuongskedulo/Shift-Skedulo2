@isTest private class ShiftBatchProcessAnalyticsTest {
    // We use this to avoid the case in which the first test that runs
    // ShiftBatchProcessAnalytics.start() after setup() does so in the same time
    // granularity as setup() itself. In that case :endTime will be equal to the
    // the value of Shift_Stage_Change__c.Changed_At__c, causing the batch to
    // return zero rows. Since test order and execution time between setup() and
    // the first test are undefined, testing without using this method can lead
    // to nondeterministic test failures.
    private static void backdateStageChangesSeconds(Id oppId, Integer numSeconds) {
        List<Shift_Stage_Change__c> stageChanges = [
            SELECT Id, Changed_At__c 
            FROM Shift_Stage_Change__c 
            WHERE Opportunity_ID__c = :oppId
        ];
        for (Shift_Stage_Change__c stageChange : stageChanges) {
            stageChange.Changed_At__c = stageChange.Changed_At__c.addSeconds(-numSeconds);
        }
        update stageChanges;
    }

    @testSetup private static void setup() {
        ShiftTesting.setup();
        ShiftTesting.SellerTestContext sc = ShiftTesting.createAndInsertSeller();
        sc.contact.Analytics_ID__c = 'thisisananalyticsID';
        update sc.contact;
        sc.opportunity.StageName = 'Sell Car';
        update sc.opportunity;
        backdateStageChangesSeconds(sc.opportunity.Id, 1);
    }

    static void executeBatch(Integer fakeResponseCode) {
        ShiftBatchProcessAnalytics batch = new ShiftBatchProcessAnalytics(0, fakeResponseCode);
        Database.executeBatch(batch);
    }

    @isTest
    static void testSuccess() {
        Test.startTest();
        executeBatch(200);
        Test.stopTest();
    }

    @isTest
    static void testFailure() {
        Test.startTest();
        try {
            executeBatch(403);
            Test.stopTest();
            System.assert(false, 'expected batch execution failure');
        } catch (Exception e) {
            // Verify that the last completion time is not updated on failure.
            List<Key_Value__c> kvs = [
                    SELECT Id FROM Key_Value__c
                    WHERE Key__c = :ShiftConstants.KEY_BATCH_PROCESS_ANALYTICS_LAST_EXECUTION_TIME
            ];
            System.assertEquals(0, kvs.size());
        }
    }

    @isTest
    static void testNoChanges() {
        Key_Value__c kv = new Key_Value__c(
                Key__c = ShiftConstants.KEY_BATCH_PROCESS_ANALYTICS_LAST_EXECUTION_TIME,
                Value__c = String.valueOf(Datetime.now().addDays(1).getTime())
        );
        insert kv;

        Test.startTest();
        executeBatch(200);
        Test.stopTest();
    }
}