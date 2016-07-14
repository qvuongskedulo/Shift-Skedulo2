trigger skedTestDriveTrigger on Test_Drive__c (after insert, after update) {
    if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedTestDriveHandler.afterTestDrivesInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedTestDriveHandler.afterTestDrivesUpdate(Trigger.OldMap, Trigger.New);
        }
    }
}