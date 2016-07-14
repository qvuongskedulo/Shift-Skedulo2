global class skedBookingEmailController {    
    public string JobId;
    
    public string getJobId() {
        return this.JobId;
    }
    
    public void setJobId (String inputJobId) {
        LoadJobData(inputJobId);
    }
    
    public string VehicleName {get;set;}
    public string BuyerFirstName {get;set;}
    public string SellerFirstName {get;set;}
    public string AppointmentDate {get;set;}
    public string AppointmentTime {get;set;}
    public string LocationAddress {get;set;}
    public string ResourceName {get;set;}
    public string ResourcePhone {get;set;}
    public string ResourceEmail {get;set;}
    public string CarEnthusiastName {get;set;}
    public string CarEnthusiastEmail {get;set;}
    public string CarConciergeName {get;set;}
    public string CarConciergeEmail {get;set;}
    public string CarActivityURL {get;set;}

    public skedBookingEmailController() {
    }
    
    private void LoadJobData(string inputJobId) {
        List<sked__Job__c> jobResults = [SELECT Id, sked__Type__c, sked__Start__c, Timezone_Adjusted_Start__c, sked__Address__c, sked__Contact__r.FirstName, 
                                         Vehicle__r.Name, Evaluation__c, Test_Drive__c, Delivery__c, Delivery__r.Vehicle_Interest__c, 
                                         Pick_Up__r.Vehicle_Interest_ID__c, Pick_Up__c, Pick_Up__r.Evaluation_ID__c, 
                                         Vehicle__r.Seller_Opportunity_ID__r.Car_Activity_URL__c,
                                         (SELECT sked__Resource__r.Name, sked__Resource__r.sked__Mobile_Phone__c, sked__Resource__r.sked__Email__c
                                          FROM sked__Job_Allocations__r
                                          WHERE sked__Status__c != 'Deleted')
                                         FROM sked__Job__c
                                         WHERE Id = :inputJobId
                                         AND sked__Job_Status__c != 'Cancelled'];
        if (jobResults != NULL && jobResults.size() > 0) {
            sked__Job__c appointment = jobResults.get(0);
            if (appointment.Vehicle__r != NULL) {
                this.VehicleName = appointment.Vehicle__r.Name;
                this.CarActivityURL = appointment.Vehicle__r.Seller_Opportunity_ID__r.Car_Activity_URL__c;
            }
            if (appointment.sked__Contact__r != NULL) {
                this.BuyerFirstName = appointment.sked__Contact__r.FirstName;
                this.SellerFirstName = appointment.sked__Contact__r.FirstName;
            }
            this.LocationAddress = appointment.sked__Address__c;
            this.AppointmentDate = appointment.Timezone_Adjusted_Start__c.format('EEEE, MMM. d, yyyy');
            this.AppointmentTime = appointment.Timezone_Adjusted_Start__c.format('hh:mm a');
            if (appointment.sked__Job_Allocations__r != NULL && appointment.sked__Job_Allocations__r.size() > 0) {
                sked__Job_Allocation__c allocation = appointment.sked__Job_Allocations__r.get(0);
                this.ResourceName = allocation.sked__Resource__r.Name;
                this.ResourcePhone = allocation.sked__Resource__r.sked__Mobile_Phone__c;
                this.ResourceEmail = allocation.sked__Resource__r.sked__Email__c;
            }
            
            string appointmentType = appointment.sked__Type__c.toLowerCase();
        
            /*for delivery notification only*/
            if (appointmentType.contains('delivery')) {
                List<sked__Job__c> testDriveJobs = [SELECT Id,
                                                    (SELECT sked__Resource__r.Name, sked__Resource__r.sked__Mobile_Phone__c, sked__Resource__r.sked__Email__c
                                                     FROM sked__Job_Allocations__r
                                                     WHERE sked__Status__c != 'Deleted')
                                                    FROM sked__Job__c
                                                    WHERE Test_Drive__c != NULL
                                                    AND Test_Drive__r.Canceled__c = FALSE
                                                    AND Test_Drive__r.Vehicle_Interest_ID__c = :appointment.Delivery__r.Vehicle_Interest__c
                                                    AND sked__Job_Status__c != 'Cancelled'
                                                    AND sked__Type__c = 'Test Drive'];
                if (testDriveJobs != NULL && testDriveJobs.size() > 0) {
                    sked__job__c testDriveJob = testDriveJobs.get(0);
                    if (testDriveJob.sked__Job_Allocations__r != NULL && testDriveJob.sked__Job_Allocations__r.size() > 0) {
                        sked__Job_Allocation__c allocation = testDriveJob.sked__Job_Allocations__r.get(0);
                        this.CarEnthusiastName = allocation.sked__Resource__r.Name;
                        this.CarEnthusiastEmail = allocation.sked__Resource__r.sked__Email__c;
                    }
                }
            }
            /*end - delivery notification only*/
        
            /*for pickup*/
            if (appointmentType.contains('pickup')) {
                if (appointmentType.contains('buyer')) {
                    List<sked__Job__c> testDriveJobs = [SELECT Id,
                                                        (SELECT sked__Resource__r.Name, sked__Resource__r.sked__Mobile_Phone__c, sked__Resource__r.sked__Email__c
                                                         FROM sked__Job_Allocations__r
                                                         WHERE sked__Status__c != 'Deleted')
                                                        FROM sked__Job__c
                                                        WHERE Test_Drive__c != NULL
                                                        AND Test_Drive__r.Canceled__c = FALSE
                                                        AND Test_Drive__r.Vehicle_Interest_ID__c = :appointment.Pick_Up__r.Vehicle_Interest_ID__c
                                                        AND sked__Job_Status__c != 'Cancelled'
                                                        AND sked__Type__c = 'Test Drive'];
                    if (testDriveJobs != NULL && testDriveJobs.size() > 0) {
                        sked__job__c testDriveJob = testDriveJobs.get(0);
                        if (testDriveJob.sked__Job_Allocations__r != NULL && testDriveJob.sked__Job_Allocations__r.size() > 0) {
                            sked__Job_Allocation__c allocation = testDriveJob.sked__Job_Allocations__r.get(0);
                            this.CarEnthusiastName = allocation.sked__Resource__r.Name;
                            this.CarEnthusiastEmail = allocation.sked__Resource__r.sked__Email__c;
                        }
                    }
                }
                else {
                    List<sked__Job__c> evaluationJobs = [SELECT Id, sked__Type__c,
                                                         (SELECT sked__Resource__r.Name, sked__Resource__r.sked__Mobile_Phone__c, sked__Resource__r.sked__Email__c
                                                          FROM sked__Job_Allocations__r
                                                          WHERE sked__Status__c != 'Deleted')
                                                         FROM sked__Job__c
                                                         WHERE Evaluation__c != NULL
                                                         AND Evaluation__c = :appointment.Pick_Up__r.Evaluation_ID__c
                                                         AND Evaluation__r.Canceled__c = FALSE
                                                         AND sked__Job_Status__c != 'Cancelled'];
                    if (evaluationJobs != NULL && evaluationJobs.size() > 0) {
                        for (sked__Job__c evaluationJob : evaluationJobs) {
                            if (!evaluationJob.sked__Type__c.toLowerCase().contains('evaluation')) {
                                continue;
                            }
                            if (evaluationJob.sked__Job_Allocations__r != NULL && evaluationJob.sked__Job_Allocations__r.size() > 0) {
                                sked__Job_Allocation__c allocation = evaluationJob.sked__Job_Allocations__r.get(0);
                                this.CarConciergeName = allocation.sked__Resource__r.Name;
                                this.CarConciergeEmail = allocation.sked__Resource__r.sked__Email__c;
                            }
                        }
                    }
                }
            }
            /*end - pickup only*/
        }
    }
}