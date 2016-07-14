public class skedGoogleCalendarSyncTestController {

    public void Cmd_ExecuteManualSync() {
        skedSyncJobToGoogleBatch b = new skedSyncJobToGoogleBatch();
        database.executebatch(b, 50);
    }
    
}