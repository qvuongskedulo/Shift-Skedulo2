global class skedBookingGridController {

    boolean needToUpdateGeoLocation;

    /**********************************************************Properties****************************************************/
    public string ObjectId {get;set;}
    public string ObjectType {get;set;}
    public string OutputMessage {get;set;}
    public boolean QuoteExpired {get;set;}
    public string PopupMessage {get;set;}
    public skedBookingGridModel Model {get;set;}

    public skedBookingGridController() {
        this.ObjectId = ApexPages.currentPage().getParameters().get('id');
        this.ObjectType = ApexPages.currentPage().getParameters().get('type');
        this.OutputMessage = '';
        string modeParam = ApexPages.currentPage().getParameters().get('mode');
        needToUpdateGeoLocation = FALSE;

        if (string.isBlank(this.ObjectId) || string.isBlank(this.ObjectType)) {
            return;
        }
        try {
 
            this.Model = InitializeskedBookingGridModelForGrid(this.ObjectId, this.ObjectType, modeParam);
        }
        catch (Exception ex) {
            this.Model = new skedBookingGridModel();
            this.OutputMessage = ex.getMessage();
            system.debug('#message#' + ex.getMessage());
            system.debug('#trace#' + ex.getStackTraceString());
        }
    }

    /**********************************************************Public Methods****************************************************/

    public void Cmd_JobTypeChanged() {
        string selectedJobType = ApexPages.currentPage().getParameters().get('selectedJobType');
        if (this.Model == NULL || string.isBlank(selectedJobType)) {
            return;
        }
        this.Model.SetJobType(selectedJobType);
    }

    public void Cmd_RegionChanged() {
        this.Model.LoadMatchedResources();
    }

    public void Cmd_DurationChanged() {
        string durationParam = ApexPages.currentPage().getParameters().get('duration');
        Integer duration = Integer.valueOf(durationParam);
        this.Model.SetDuration(duration);
    }

    public void Cmd_DriversAssistChanged() {
        this.Model.LoadMatchedResources();
    }

    public void Cmd_LoadDriversAssist() {
        string jobStartTimeParam = ApexPages.currentPage().getParameters().get('jobStartTime');
        Integer jobStartTime = Integer.valueOf(jobStartTimeParam);
        string bookedResourceId = ApexPages.currentPage().getParameters().get('bookedResourceId');
        
        this.Model.LoadMatchedDriversAssist(jobStartTime, bookedResourceId);
    }

    public void Cmd_LocationAddressChanged() {
        this.OutputMessage = '';
        this.Model.LoadSubRegions();
        this.Model.LoadMatchedResources();
    }

    public void Cmd_SelectedDateChanged() {
        string selectedDate = ApexPages.currentPage().getParameters().get('selectedDate');
        if (this.Model == NULL || string.isBlank(selectedDate)) {
            return;
        }

        Date dateValue = skedUtils.ConvertToDateValue(selectedDate);
        this.Model.SetSelectedDate(dateValue);
    }

    public void Cmd_UpdateGeoLocationToRootRecord() {
        if (needToUpdateGeoLocation) {
            sObject recordToUpdate;
            if (Model.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE) {
                recordToUpdate = new Test_Drive__c();
            } else if (Model.ObjectType == SkeduloConstants.OBJECT_TYPE_EVALUATION) {
                recordToUpdate = new Evaluation__c();
            } else if (Model.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP) {
                recordToUpdate = new Pick_Up__c();
            } else if (Model.ObjectType == SkeduloConstants.OBJECT_TYPE_DELIVERY) {
                recordToUpdate = new Delivery__c();
            }
            if (recordToUpdate != NULL) {
                recordToUpdate.put('Id', Model.ObjectId);
                recordToUpdate.put('GeoLocation__latitude__s', model.GeoLoc.Latitude);
                recordToUpdate.put('GeoLocation__longitude__s', model.GeoLoc.Longitude);
                update recordToUpdate;
            }
        }
    }

    public void Cmd_SaveBooking() {
        string startTimeString = ApexPages.currentPage().getParameters().get('startTime');
        string resourceId = ApexPages.currentPage().getParameters().get('resourceId');
        string driverAssistId = ApexPages.currentPage().getParameters().get('driverAssistId');

        skedSaveJobModel saveJobModel = new skedSaveJobModel(this.Model, startTimeString, resourceId, driverAssistId);
        saveJobModel.InitializeJob();

        Savepoint sp = Database.setSavepoint();
        try {
            this.PopupMessage = '';
            saveJobModel.SaveJob();

            //send sms to resources
            skedSkeduloApiManager.sendDispatchNotification(saveJobModel.MainJob.Id, saveJobModel.MainJobAllocation.sked__Resource__c);
            if (this.Model.DriversAssist) {
                skedSkeduloApiManager.sendDispatchNotification(saveJobModel.DriverAssistJob.Id, saveJobModel.DriverAssistJobAllocation.sked__Resource__c);
            }
        }
        catch (Exception ex) {
            this.OutputMessage = ex.getMessage();
            if (ex.getMessage() == 'duplicate') {
                this.OutputMessage = '';
                this.PopupMessage = 'The timeslot you selected is no longer available. Please select a new time.';
            }
            system.debug('#message#' + ex.getMessage());
            system.debug('#trace#' + ex.getStackTraceString());

            Database.rollback(sp);
        }
    }

    /**********************************************************Private Methods****************************************************/
    skedBookingGridModel InitializeskedBookingGridModelForGrid(string objectId, string objectType, string modeParam) {
        skedBookingGridModel model = new skedBookingGridModel();
        model.TimezoneSidId = UserInfo.getTimeZone().getID();
        model.ObjectId = objectId;
        model.ObjectType = objectType;
        model.VehicleVisible = objectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE;
        model.MinDate = model.SelectedDate = system.now().date();

        if (!string.isBlank(modeParam)) {
            model.IsReschedule = modeParam == 'reschedule';
        }
        
        model.LoadJobTypeSettings();
        
        if (model.JobTypeOptions != NULL && model.JobTypeOptions.size() > 0) {
            model.SetJobType(model.JobTypeOptions.get(0).getValue());
        }

        //Load Account, Vehicle
        if (objectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE) {
            LoadDataFromTestDrive(objectId, model);
        }
        else if (objectType == SkeduloConstants.OBJECT_TYPE_EVALUATION) {
            LoadDataFromEvaluation(objectId, model);
        }
        else if (objectType == SkeduloConstants.OBJECT_TYPE_DELIVERY) {
            LoadDataFromDelivery(objectId, model);
        }
        else if (objectType == SkeduloConstants.OBJECT_TYPE_PICKUP) {
            LoadDataFromPickup(objectId, model);
        }

        //if in reschedule mode, default date should be the original job's date
        if (model.IsReschedule == TRUE) {
            List<sked__Job__c> relatedJobs = skedBookingGridUtils.GetRelatedJobs(model.ObjectType, model.ObjectId);
            if (relatedJobs.size() > 0) {
                DateTime originalJobStart;
                if (model.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE) {
                    for (sked__Job__c relatedJob : relatedJobs) {
                        if (relatedJob.sked__Type__c == SkeduloConstants.JOB_TYPE_TEST_DRIVE) {
                            originalJobStart = relatedJob.sked__Start__c;
                            break;
                        }
                    }
                } else {
                    originalJobStart = relatedJobs.get(0).sked__Start__c;
                }
                if (originalJobStart != NULL) {
                    DateTime originalJobStartInRegionTimezone = skedUtils.ConvertBetweenTimezones(originalJobStart, model.TimezoneSidId, UserInfo.getTimeZone().getID());
                    if (originalJobStartInRegionTimezone.date() > model.SelectedDate) {
                        model.SelectedDate = originalJobStartInRegionTimezone.date();
                    }
                }
            }
            for (sked__Job__c job : relatedJobs) {
                model.ExcludeJobIds.add(job.Id);
            }
        }
        else if (model.RequestedTime != NULL && model.RequestedTime.date() >= model.SelectedDate) {
            model.SelectedDate = model.RequestedTime.date();
        }

        model.PopulateAccountContact(model.AccountId);

        if (string.isBlank(model.RegionId)) {
            this.OutputMessage = 'Region is missing on Opportunity or Region is not linked to Skedulo Region';
            return model;
        }
        if (objectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE || objectType == SkeduloConstants.OBJECT_TYPE_DELIVERY || (objectType == SkeduloConstants.OBJECT_TYPE_PICKUP && model.IsPickupBackflow)) {
            if (string.isBlank(model.HubAddress)) {
                this.OutputMessage = 'Parking lot is missing on Vehicle.';
                return model;
            }
        }

        if (!string.isBlank(model.LocationAddress) && (model.GeoLoc.Latitude == NULL || model.GeoLoc.Longitude == NULL)) {
            Location geoLocation = skedLocationService.getAddressGeoLocation(model.LocationAddress);
            if (Test.isRunningTest()) {
                geoLocation = Location.newInstance(37.788288, -122.431223);
            }
            if (geoLocation != NULL) {
                model.GeoLoc.Latitude = geoLocation.getLatitude();
                model.GeoLoc.Longitude = geoLocation.getLongitude();
                needToUpdateGeoLocation = TRUE;
            }
            else {
                this.OutputMessage = 'The location address is invalid. Cannot populate the geocoding for this address.';
                return model;
            }
        }
        
        model.LoadSubRegions();
        
        if (model.SubRegionOptions == NULL || model.SubRegionOptions.size() == 0) {
            this.OutputMessage = 'There is no sub region which is matched with the zipcode.';
            return model;
        }
                
        model.LoadMatchedResources();
        
        return model;
    }

    void LoadDataFromTestDrive(string objectId, skedBookingGridModel model) {
        List<Test_Drive__c> testDriveResults = [SELECT Id, Location__c, Original_Time_Requested__c, Vehicle_Interest_ID__r.Vehicle_ID__r.Transmission__c, 
                                                Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.AccountId, Vehicle_Interest_ID__r.Vehicle_ID__c,
                                                Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.Region_ID__c,
                                                GeoLocation__latitude__s, GeoLocation__longitude__s
                                                FROM Test_Drive__c
                                                WHERE Id = :objectId];
        if (testDriveResults == NULL || testDriveResults.isEmpty()) {
            this.OutputMessage = 'The test drive does not exist.';
            return;
        }
        Test_Drive__c testDrive = testDriveResults.get(0);
        model.LocationAddress = testDrive.Location__c;
        model.ZipCode = skedBookingGridUtils.GetZipCodeFromAddress(model.LocationAddress);
        model.AccountId = testDrive.Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.AccountId;
        if (!string.isBlank(testDrive.Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.Region_ID__c)) {
            model.RegionId = testDrive.Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.Region_ID__c;
        }
        model.RequestedTime = testDrive.Original_Time_Requested__c;
        if (testDrive.GeoLocation__latitude__s != NULL && testDrive.GeoLocation__longitude__s != NULL) {
            model.GeoLoc.Latitude = testDrive.GeoLocation__latitude__s;
            model.GeoLoc.Longitude = testDrive.GeoLocation__longitude__s;
        }

        if (testDrive.Vehicle_Interest_ID__r.Vehicle_ID__r != NULL && !string.isBlank(testDrive.Vehicle_Interest_ID__r.Vehicle_ID__r.Transmission__c)) {
            model.ManualTransmission = testDrive.Vehicle_Interest_ID__r.Vehicle_ID__r.Transmission__c == 'Manual';
        }

        //populate vehicle
        string vehicleId = testDrive.Vehicle_Interest_ID__r.Vehicle_ID__c;
        model.PopulateVehicle(vehicleId);
    }

    void LoadDataFromDelivery(string objectId, skedBookingGridModel model) {
        List<Delivery__c> deliveryResults = [SELECT Id, Location__c, Vehicle_Interest__r.Vehicle_ID__r.Transmission__c, 
                                             Vehicle_Interest__r.Buyer_Opportunity_ID__r.AccountId, Vehicle_Interest__r.Vehicle_ID__c,
                                             Vehicle_Interest__r.Buyer_Opportunity_ID__r.Region_ID__c,
                                             GeoLocation__latitude__s, GeoLocation__longitude__s, Original_Time_Requested__c
                                             FROM Delivery__c
                                             WHERE Id = :objectId];
        if (deliveryResults == NULL || deliveryResults.isEmpty()) {
            this.OutputMessage = 'The delivery does not exist.';
            return;
        }
        Delivery__c delivery = deliveryResults.get(0);
        model.LocationAddress = delivery.Location__c;
        model.ZipCode = skedBookingGridUtils.GetZipCodeFromAddress(model.LocationAddress);
        model.AccountId = delivery.Vehicle_Interest__r.Buyer_Opportunity_ID__r.AccountId;
        if (!string.isBlank(delivery.Vehicle_Interest__r.Buyer_Opportunity_ID__r.Region_ID__c)) {
            model.RegionId = delivery.Vehicle_Interest__r.Buyer_Opportunity_ID__r.Region_ID__c;
        }
        model.RequestedTime = delivery.Original_Time_Requested__c;
        if (delivery.GeoLocation__latitude__s != NULL && delivery.GeoLocation__longitude__s != NULL) {
            model.GeoLoc.Latitude = delivery.GeoLocation__latitude__s;
            model.GeoLoc.Longitude = delivery.GeoLocation__longitude__s;
        }

        if (delivery.Vehicle_Interest__r.Vehicle_ID__r != NULL && !string.isBlank(delivery.Vehicle_Interest__r.Vehicle_ID__r.Transmission__c)) {
            model.ManualTransmission = delivery.Vehicle_Interest__r.Vehicle_ID__r.Transmission__c == 'Manual';
        }

        //populate vehicle
        string vehicleId = delivery.Vehicle_Interest__r.Vehicle_ID__c;
        model.PopulateVehicle(vehicleId);
    }

    void LoadDataFromEvaluation(string objectId, skedBookingGridModel model) {
        List<Evaluation__c> evaluationResults = [SELECT Id, Location__c, Pickup_Probability__c, Originally_Requested_At__c,
                                                 Seller_Opportunity_ID__r.AccountId, Seller_Opportunity_ID__r.Region_ID__c, 
                                                 Seller_Opportunity_ID__r.Vehicle_ID__c,
                                                 Seller_Opportunity_ID__r.Quote_Sent_At__c,
                                                 Seller_Opportunity_ID__r.Last_Quoted_At__c,
                                                 GeoLocation__latitude__s, GeoLocation__longitude__s
                                                 FROM Evaluation__c
                                                 WHERE Id = :objectId];
        if (evaluationResults == NULL || evaluationResults.isEmpty()) {
            this.OutputMessage = 'The evaluation does not exist.';
            return;
        }
        Evaluation__c evaluation = evaluationResults.get(0);
 
        if (evaluation.Seller_Opportunity_ID__r.Last_Quoted_At__c != NULL) {
            model.LastQuotedAt = evaluation.Seller_Opportunity_ID__r.Last_Quoted_At__c;
        } else {
            // We have to maintain backwards compatibility for before Last_Quoted_At__c was used.
            // In this case, Quote_Sent_At__c will be the fallback.
            model.LastQuotedAt = evaluation.Seller_Opportunity_ID__r.Quote_Sent_At__c;
        }
 
        model.LocationAddress = evaluation.Location__c;
        model.ZipCode = skedBookingGridUtils.GetZipCodeFromAddress(model.LocationAddress);
        model.AccountId = evaluation.Seller_Opportunity_ID__r.AccountId;
        if (!string.isBlank(evaluation.Seller_Opportunity_ID__r.Region_ID__c)) {
            model.RegionId = evaluation.Seller_Opportunity_ID__r.Region_ID__c;
        }
        model.RequestedTime = evaluation.Originally_Requested_At__c;
        if (evaluation.GeoLocation__latitude__s != NULL && evaluation.GeoLocation__longitude__s != NULL) {
            model.GeoLoc.Latitude = evaluation.GeoLocation__latitude__s;
            model.GeoLoc.Longitude = evaluation.GeoLocation__longitude__s;
        }

        //populate vehicle
        string vehicleId = evaluation.Seller_Opportunity_ID__r.Vehicle_ID__c;
        model.PopulateVehicle(vehicleId);
    }

    void LoadDataFromPickup(string objectId, skedBookingGridModel model) {
        List<Pick_Up__c> pickupResults = [SELECT Id, Location__c, Evaluation_ID__r.Seller_Opportunity_ID__r.AccountId, Original_Time_Requested__c,
                                          GeoLocation__latitude__s, GeoLocation__longitude__s, Evaluation_ID__r.Seller_Opportunity_ID__r.Vehicle_ID__c,
                                          Evaluation_ID__r.Seller_Opportunity_ID__r.Region_ID__c,
                                          Vehicle_Interest_ID__r.Vehicle_ID__r.Transmission__c, 
                                          Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.AccountId, Vehicle_Interest_ID__r.Vehicle_ID__c,
                                          Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.Region_ID__c,
                                          RecordTypeId
                                          FROM Pick_Up__c
                                          WHERE Id = :objectId];
        if (pickupResults == NULL || pickupResults.isEmpty()) {
            this.OutputMessage = 'The pick up does not exist.';
            return;
        }
        Pick_Up__c pickup = pickupResults.get(0);
        model.LocationAddress = pickup.Location__c;
        model.ZipCode = skedBookingGridUtils.GetZipCodeFromAddress(model.LocationAddress);
        
        string vehicleId;
        if (pickup.Evaluation_ID__r != NULL) {
            model.AccountId = pickup.Evaluation_ID__r.Seller_Opportunity_ID__r.AccountId;
            if (!string.isBlank(pickup.Evaluation_ID__r.Seller_Opportunity_ID__r.Region_ID__c)) {
                model.RegionId = pickup.Evaluation_ID__r.Seller_Opportunity_ID__r.Region_ID__c;
            }
            vehicleId = pickup.Evaluation_ID__r.Seller_Opportunity_ID__r.Vehicle_ID__c;
        }
        else if (pickup.Vehicle_Interest_ID__r != NULL) {
            model.AccountId = pickup.Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.AccountId;
            if (!string.isBlank(pickup.Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.Region_ID__c)) {
                model.RegionId = pickup.Vehicle_Interest_ID__r.Buyer_Opportunity_ID__r.Region_ID__c;
            }
            model.IsPickupBackflow = TRUE;
            vehicleId = pickup.Vehicle_Interest_ID__r.Vehicle_ID__c;
        }

        model.RequestedTime = pickup.Original_Time_Requested__c;
        if (pickup.GeoLocation__latitude__s != NULL && pickup.GeoLocation__longitude__s != NULL) {
            model.GeoLoc.Latitude = pickup.GeoLocation__latitude__s;
            model.GeoLoc.Longitude = pickup.GeoLocation__longitude__s;
        }

        //populate vehicle
        model.PopulateVehicle(vehicleId);
        
        PreselectPickupJobType(pickup.RecordTypeId, model);
    }

    void PreselectPickupJobType(string recordTypeId, skedBookingGridModel model) {
        if (model == NULL || string.isBlank(recordTypeId)) {
            return;
        }
        List<RecordType> pickupTypeResults = [SELECT Id, Name FROM RecordType WHERE Id = :recordTypeId];
        if (pickupTypeResults != NULL && pickupTypeResults.size() > 0) {
            RecordType pickupType = pickupTypeResults.get(0);
            if (pickupType.Name == 'Seller') {
                model.SetJobType(SkeduloConstants.JOB_TYPE_PICKUP_ONLY);
            }
            else if (pickupType.Name == 'Buyer') {
                model.SetJobType(SkeduloConstants.JOB_TYPE_BUYER_PICKUP);
            }
        }
    }

    /**********************************************************Global Action Methods****************************************************/

    @remoteAction
    global static List<skedBookingGridUtils.SearchResult> GetDriversAssist(string regionTimezone, string subRegionId, string dateString, Integer startTime, Integer duration) {
        Date dateValue = skedUtils.ConvertToDateValue(dateString);
        DateTime jobStart = DateTime.newInstance(dateValue, time.newInstance(0, 0, 0, 0));
        jobStart = skedUtils.ConvertBetweenTimezones(jobStart, regionTimezone, UserInfo.getTimeZone().getID());
        jobStart = jobStart.addMinutes(startTime);
        List<skedBookingGridUtils.SearchResult> results = skedBookingGridUtils.GetDriversAssist(regionTimezone, subRegionId, jobStart, duration);
        return results;
    }

}