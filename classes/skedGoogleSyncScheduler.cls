global class skedGoogleSyncScheduler implements Schedulable{
   global void execute(SchedulableContext sc) {
      skedGoogleSyncBatch b = new skedGoogleSyncBatch(); 
      database.executebatch(b, 50);
   }
}