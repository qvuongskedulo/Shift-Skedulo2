public class skedTestDriveHandler {

    public static void afterTestDrivesInsert(List<Test_Drive__c> newTestDrives) {
        string recordIds = '';
        
        for (Test_Drive__c testDrive : newTestDrives) {
            recordIds += testDrive.Id + ';';
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'testdrive');
        }
    }
    
    public static void afterTestDrivesUpdate(Map<Id, Test_Drive__c> oldTestDrives, List<Test_Drive__c> newTestDrives) {
        string recordIds = '';
        Map<Id, Test_Drive__c> mapTestDriveToCancelJobs = new Map<Id, Test_Drive__c>();
        Map<Id, Test_Drive__c> mapTestDriveToUpdateJobNotes = new Map<Id, Test_Drive__c>();
        
        for (Test_Drive__c testDrive : newTestDrives) {
            Test_Drive__c oldData = oldTestDrives.get(testDrive.Id);
            if (testDrive.Location__c != oldData.Location__c 
                && testDrive.GeoLocation__Latitude__s == oldData.GeoLocation__Latitude__s 
                && testDrive.GeoLocation__Longitude__s == oldData.GeoLocation__Longitude__s) {
                    recordIds += testDrive.Id + ';';
                }
            if (testDrive.Canceled__c && testDrive.Canceled__c != oldData.Canceled__c) {
                mapTestDriveToCancelJobs.put(testDrive.Id, testDrive);
            }
            if (testDrive.Customer_Experience_Calendar_Notes__c != oldData.Customer_Experience_Calendar_Notes__c) {
                mapTestDriveToUpdateJobNotes.put(testDrive.Id, testDrive);
            }
        }
        if (mapTestDriveToCancelJobs.size() > 0) {
            skedTriggerUtils.CancelRelatedJobs(mapTestDriveToCancelJobs);
        }
        if (mapTestDriveToUpdateJobNotes.size() > 0) {
            skedTriggerUtils.UpdateJobShiftNotes(mapTestDriveToUpdateJobNotes);
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'testdrive');
        }
    }
    
}