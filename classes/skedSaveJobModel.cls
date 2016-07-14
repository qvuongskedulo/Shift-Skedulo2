public class skedSaveJobModel {
        public skedBookingGridModel BookingModel {get;set;}

        public DateTime JobStart {get;set;}
        public DateTime JobFinish {get;set;}
        public DateTime EstimateJobStart {get;set;}
        public DateTime EstimateJobFinish {get;set;}
        public string ResourceId {get;set;}
        public string DriverAssistId {get;set;}
        public string SkeduloRegionId {get;set;}

        public Job_Type_Settings__c JobTypeSetting {get;set;}
        public List<Job_Type_Activity_Settings__c> JobTypeActivitySettings {get;set;}

        public Location BookingLocation {get;set;}
        public Location BookingHubLocation {get;set;}
        public string BookingHubAddress {get;set;}

        public Integer JobToHubTravelTime {get;set;}
        public Integer HubToJobTravelTime {get;set;}

        public sked__Job__c PreviousJob {get;set;}
        public List<sked__Job__c> RescheduleJobs {get;set;}
        public Set<Id> RescheduleJobIds {get;set;}

        public sked__Job__c MainJob {get;set;}
        public sked__Job_Allocation__c MainJobAllocation {get;set;}

        public sked__Job__c DriverAssistJob {get;set;}
        public sked__Job_Allocation__c DriverAssistJobAllocation {get;set;}
        
        public List<sked__Activity__c> JobTypeActivities {get;set;}
        public sked__Resource__c SelectedResource {get;set;}

        public skedSaveJobModel(skedBookingGridModel bookingModel, string startTimeString, string resourceId, string driverAssistId) {
            this.ResourceId = resourceId;
            this.DriverAssistId = driverAssistId;
            this.BookingModel = bookingModel;

            sked_Booking_Email_Setting__c bookingSetting = sked_Booking_Email_Setting__c.getOrgDefaults();

            //Load Job's start and finish
            Integer startTimeInMinutes = Integer.valueOf(startTimeString);
            DateTime startOfSelectedDate = DateTime.newInstance(this.BookingModel.SelectedDate, Time.newInstance(0, 0, 0, 0));
            DateTime endOfSelectedDate = startOfSelectedDate.addDays(1);
            startTimeInMinutes = skedUtils.ConvertBetweenTimezones(startTimeInMinutes, this.BookingModel.TimezoneSidId, UserInfo.getTimeZone().getID());
            this.JobStart = startOfSelectedDate.addMinutes(startTimeInMinutes);
            this.JobFinish = this.JobStart.addMinutes(this.BookingModel.Duration);

            //load Skedulo region
            Region__c shiftRegion = [SELECT Id, skedulo_Region_ID__c FROM Region__c WHERE Id = :this.BookingModel.RegionId];
            this.SkeduloRegionId = shiftRegion.skedulo_Region_ID__c;

            //load selected resource
            InitializeSelectedResource();
            
            //get job location and hub location
            this.BookingLocation = Location.newInstance(this.BookingModel.GeoLoc.Latitude, this.BookingModel.GeoLoc.Longitude);

            if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE || this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_DELIVERY || (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP && this.BookingModel.IsPickupBackflow)) {
                this.BookingHubLocation = Location.newInstance(this.BookingModel.HubGeoLoc.Latitude, this.BookingModel.HubGeoLoc.Longitude);
                this.BookingHubAddress = this.BookingModel.HubAddress;
            }
            else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_EVALUATION || (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP && !this.BookingModel.IsPickupBackflow)) {
                if (this.SelectedResource.Staff_Profiles__r != NULL && this.SelectedResource.Staff_Profiles__r.size() > 0) {
                    Staff_Profile__c staffProfile = this.SelectedResource.Staff_Profiles__r.get(0);
                    if (staffProfile.Parking_Lot_ID__r != NULL) {
                        this.BookingHubLocation = staffProfile.Parking_Lot_ID__r.GeoLocation__c;
                        this.BookingHubAddress = staffProfile.Parking_Lot_ID__r.Address__c;
                    }
                }
            }

            this.RescheduleJobs = new List<sked__Job__c>();
            this.RescheduleJobIds = new Set<Id>();
            if (this.BookingModel.IsReschedule) {
                this.RescheduleJobs = skedBookingGridUtils.GetRelatedJobs(this.BookingModel.ObjectType, this.BookingModel.ObjectId);
                for (sked__Job__c jobItem : this.RescheduleJobs) {
                    this.RescheduleJobIds.add(jobItem.Id);
                }
            }

            //find the previous Job
            this.PreviousJob = FindPreviousJob(startOfSelectedDate, endOfSelectedDate, this.resourceId, this.JobStart);

            //initialize travel time
            if (this.JobTypeSetting.Start_from_Hub__c) {
                this.HubToJobTravelTime = this.BookingModel.GetTravelTime(bookingHubLocation, bookingLocation, this.JobStart.addMinutes((-1) * this.BookingModel.Step));
            }
            else {
                this.HubToJobTravelTime = 0;
            }
            if (this.JobTypeSetting.Back_to_Hub__c) {
                this.JobToHubTravelTime = this.BookingModel.GetTravelTime(bookingLocation, bookingHubLocation, this.JobFinish);
            }
            else {
                this.JobToHubTravelTime = 0;
            }

            //Load Job Type Setting
            List<Job_Type_Settings__c> jobTypeResults = [SELECT Name, Job_Type__c, Drivers_Assist__c, Start_from_Hub__c, Back_to_Hub__c
                                                         FROM Job_Type_Settings__c
                                                         WHERE Object_Type__c = :this.BookingModel.ObjectType
                                                         AND Job_Type__c = :this.BookingModel.JobType AND Drivers_Assist__c = :this.BookingModel.DriversAssist];
            
            if (jobTypeResults != NULL && jobTypeResults.size() > 0) {
                this.JobTypeSetting = jobTypeResults.get(0);
            }
            
            //Load Job Type Activity Settings
            this.JobTypeActivitySettings = [SELECT Name, Activity_Type__c, Duration__c, Is_After__c, Is_Before__c
                                            FROM Job_Type_Activity_Settings__c
                                            WHERE Job_Type__c = :this.BookingModel.JobType];
        }

        public void InitializeJob() {
            this.MainJob = new sked__Job__c();
            this.MainJob.sked__Region__c = SkeduloRegionId;
            this.MainJob.Subregion__c = this.BookingModel.SubRegionId;
            this.MainJob.sked__Type__c = this.BookingModel.JobType;
            this.MainJob.sked__Duration__c = this.BookingModel.Duration;
            this.MainJob.sked__Account__c = this.BookingModel.AccountId;
            this.MainJob.sked__Contact__c = this.BookingModel.ContactId;
            this.MainJob.sked__Start__c = jobStart;
            this.MainJob.sked__Estimated_Start__c = jobStart;
            this.MainJob.sked__Finish__c = jobFinish;
            this.MainJob.sked__Estimated_End__c = jobFinish;
            this.MainJob.sked__Job_Status__c = SkeduloConstants.JOB_STATUS_READY;
            this.MainJob.sked__Address__c = this.BookingModel.LocationAddress;
            this.MainJob.sked__GeoLocation__latitude__s = this.BookingModel.GeoLoc.Latitude;
            this.MainJob.sked__GeoLocation__longitude__s = this.BookingModel.GeoLoc.Longitude;
            this.MainJob.Vehicle__c = this.BookingModel.VehicleId;
            this.MainJob.Drivers_Assist__c = this.BookingModel.DriversAssist;
            this.MainJob.Trigger_Email__c = this.BookingModel.TriggerEmail;

            if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE) {
                mainJob.Test_Drive__c = this.BookingModel.ObjectId;
            } else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_EVALUATION) {
                mainJob.Evaluation__c = this.BookingModel.ObjectId;
            } else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_DELIVERY) {
                mainJob.Delivery__c = this.BookingModel.ObjectId;
            } else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP) {
                mainJob.Pick_Up__c = this.BookingModel.ObjectId;
            }
            if (this.PreviousJob == NULL && this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_EVALUATION) {
                if (this.JobTypeSetting.Start_from_Hub__c) {
                    Integer homeToJobTravelTime = this.BookingModel.GetTravelTime(this.SelectedResource.sked__GeoLocation__c, bookingLocation);

                    this.MainJob.Departure_Time__c = this.JobStart.addMinutes((-1) * homeToJobTravelTime);
                    this.MainJob.Hub_to_Job_Travel_Time__c = homeToJobTravelTime;
                    this.MainJob.Start_from_GeoLocation__latitude__s = this.SelectedResource.sked__GeoLocation__Latitude__s;
                    this.MainJob.Start_from_GeoLocation__longitude__s = this.SelectedResource.sked__GeoLocation__Longitude__s;
                    this.MainJob.Start_from_Location__c = this.SelectedResource.sked__Home_Address__c;
                }
            }
            else {
                if (this.JobTypeSetting.Start_from_Hub__c) {
                    this.MainJob.Departure_Time__c = this.JobStart.addMinutes((-1) * this.HubToJobTravelTime);
                    this.MainJob.Hub_to_Job_Travel_Time__c = this.HubToJobTravelTime;
                    this.MainJob.Start_from_GeoLocation__latitude__s = this.BookingModel.HubGeoLoc.Latitude;
                    this.MainJob.Start_from_GeoLocation__longitude__s = this.BookingModel.HubGeoLoc.Longitude;
                    this.MainJob.Start_from_Location__c = this.BookingHubAddress;
                }
            }
            if (this.JobTypeSetting.Back_to_Hub__c) {
                this.MainJob.Job_to_Hub_Travel_Time__c = this.JobToHubTravelTime;
                this.MainJob.Back_to_GeoLocation__latitude__s = this.BookingModel.HubGeoLoc.Latitude;
                this.MainJob.Back_to_GeoLocation__longitude__s = this.BookingModel.HubGeoLoc.Longitude;
                this.MainJob.Back_to_Location__c = this.BookingHubAddress;
            }
            this.MainJobAllocation = new sked__Job_Allocation__c();
            this.MainJobAllocation.sked__Resource__c = this.ResourceId;
            this.MainJobAllocation.sked__Status__c = SkeduloConstants.ALLOCATION_STATUS_CONFIRMED;
            this.MainJobAllocation.sked__Estimated_Travel_Time__c = this.HubToJobTravelTime;

            this.EstimateJobStart = this.MainJob.sked__Start__c.addMinutes((-1) * this.HubToJobTravelTime);
            this.EstimateJobFinish = this.MainJob.sked__Finish__c.addMinutes(this.JobToHubTravelTime);
            
            system.debug('#EstimateJobStart#' + EstimateJobStart.format('hh:mma', this.BookingModel.TimezoneSidId));
            system.debug('#EstimateJobFinish#' + EstimateJobFinish.format('hh:mma', this.BookingModel.TimezoneSidId));
            
            if (this.BookingModel.DriversAssist) {
                InitializeDriverAssistJob();

                this.MainJob.Drivers_Assist_Resource__c = this.DriverAssistId;
            }
            InitializeJobTypeActivities();
        }

        public void InitializeDriverAssistJob() {
            this.DriverAssistJob = new sked__Job__c();
            this.DriverAssistJob.sked__Region__c = this.SkeduloRegionId;
            this.DriverAssistJob.Subregion__c = this.BookingModel.SubRegionId;
            this.DriverAssistJob.sked__Type__c = SkeduloConstants.JOB_TYPE_DRIVERS_ASSIST;
            this.DriverAssistJob.sked__Account__c = this.BookingModel.AccountId;
            this.DriverAssistJob.sked__Contact__c = this.BookingModel.ContactId;
            this.DriverAssistJob.Departure_Time__c = this.JobStart.addMinutes((-1) * (this.JobToHubTravelTime + SkeduloConstants.JOB_DURATION_DRIVERS_ASSIST));
            this.DriverAssistJob.sked__Start__c = this.JobStart.addMinutes((-1) * SkeduloConstants.JOB_DURATION_DRIVERS_ASSIST);
            this.DriverAssistJob.sked__Estimated_Start__c = this.JobStart.addMinutes((-1) * SkeduloConstants.JOB_DURATION_DRIVERS_ASSIST);
            this.DriverAssistJob.sked__Finish__c = this.JobStart;
            this.DriverAssistJob.sked__Estimated_End__c = this.JobStart;
            this.DriverAssistJob.sked__Duration__c = SkeduloConstants.JOB_DURATION_DRIVERS_ASSIST;
            this.DriverAssistJob.sked__Job_Status__c = SkeduloConstants.JOB_STATUS_READY;
            this.DriverAssistJob.sked__Address__c = this.BookingModel.LocationAddress;
            this.DriverAssistJob.sked__GeoLocation__latitude__s = this.BookingModel.GeoLoc.Latitude;
            this.DriverAssistJob.sked__GeoLocation__longitude__s = this.BookingModel.GeoLoc.Longitude;
            this.DriverAssistJob.Vehicle__c = this.BookingModel.VehicleId;
            this.DriverAssistJob.Start_from_GeoLocation__latitude__s = this.BookingModel.HubGeoLoc.Latitude;
            this.DriverAssistJob.Start_from_GeoLocation__longitude__s = this.BookingModel.HubGeoLoc.Longitude;
            this.DriverAssistJob.Start_from_Location__c = this.BookingModel.HubAddress;
            this.DriverAssistJob.Hub_to_Job_Travel_Time__c = this.BookingModel.GetTravelTime(this.BookingHubLocation, this.BookingLocation);
            this.DriverAssistJob.Test_Drive__c = this.BookingModel.ObjectId;
            this.DriverAssistJob.Test_Drive_Resource__c = this.ResourceId;
            this.DriverAssistJob.Trigger_Email__c = this.BookingModel.TriggerEmail;

            if (this.PreviousJob != NULL && this.PreviousJob.sked__Type__c == skeduloConstants.JOB_TYPE_TEST_DRIVE) {
                this.DriverAssistJob.Back_to_GeoLocation__Latitude__s = this.PreviousJob.Vehicle__r.Parking_Lot_ID__r.GeoLocation__Latitude__s;
                this.DriverAssistJob.Back_to_GeoLocation__Longitude__s = this.PreviousJob.Vehicle__r.Parking_Lot_ID__r.GeoLocation__Longitude__s;
                this.DriverAssistJob.Back_to_Location__c = this.PreviousJob.Vehicle__r.Parking_Lot_ID__r.Address__c;
                if (this.PreviousJob.Back_to_GeoLocation__c != NULL) {
                    this.DriverAssistJob.Job_to_Hub_Travel_Time__c = this.BookingModel.GetTravelTime(this.BookingLocation, this.PreviousJob.Back_to_GeoLocation__c);
                }
                else {
                    this.DriverAssistJob.Job_to_Hub_Travel_Time__c = this.BookingModel.GetTravelTime(this.BookingLocation, this.BookingHubLocation);
                }
                this.DriverAssistJob.Assist_From_Job__c = this.PreviousJob.Id;
            }

            this.DriverAssistJobAllocation = new sked__Job_Allocation__c();
            this.DriverAssistJobAllocation.sked__Resource__c = this.DriverAssistId;
            this.DriverAssistJobAllocation.sked__Status__c = SkeduloConstants.ALLOCATION_STATUS_CONFIRMED;
            this.DriverAssistJobAllocation.sked__Estimated_Travel_Time__c = this.JobToHubTravelTime;
        }

        public void SaveJob() {
            sked_Booking_Email_Setting__c bookingSetting = sked_Booking_Email_Setting__c.getOrgDefaults();
            boolean isMainJobDuplicate = CheckDuplicateBooking(this.MainJob, this.ResourceId, this.BookingModel.VehicleId);
            if (isMainJobDuplicate) {
                throw new skedBookingGridException('duplicate');
            }
            
            //if in reschedule mode, need to cancel the related jobs
            if (this.BookingModel.IsReschedule) {
                //if the reschedule is test drive with driver assist, before this job is cancelled, need to find the preivous if exist,
                //update the back to location to that previous one.
                DateTime startOfSelectedDate = DateTime.newInstance(this.BookingModel.SelectedDate, Time.newInstance(0, 0, 0, 0));
                DateTime endOfSelectedDate = startOfSelectedDate.addDays(1);
                for (sked__Job__c jobItem : this.RescheduleJobs) {
                    if (jobItem.Drivers_Assist__c == TRUE) {
                        sked__Job_Allocation__c jobItemAlloc = jobItem.sked__Job_Allocations__r.get(0);
                        sked__Job__c previousJobOfRescheduleJob = FindPreviousJob(startOfSelectedDate, endOfSelectedDate, jobItemAlloc.sked__Resource__c, jobItem.sked__Start__c);

                        if (previousJobOfRescheduleJob != NULL) {
                            if (this.PreviousJob == NULL || (previousJobOfRescheduleJob.Id != this.PreviousJob.Id)
                               || (previousJobOfRescheduleJob.Id == this.PreviousJob.Id && this.BookingModel.DriversAssist == FALSE)) {
                                previousJobOfRescheduleJob.Back_to_Location__c = previousJobOfRescheduleJob.Start_from_Location__c;
                                previousJobOfRescheduleJob.Back_to_GeoLocation__Latitude__s = previousJobOfRescheduleJob.Start_from_GeoLocation__Latitude__s;
                                previousJobOfRescheduleJob.Back_to_GeoLocation__Longitude__s = previousJobOfRescheduleJob.Start_from_GeoLocation__Longitude__s;
                                previousJobOfRescheduleJob.Job_to_Hub_Travel_Time__c = previousJobOfRescheduleJob.Hub_to_Job_Travel_Time__c;
                                update previousJobOfRescheduleJob;
                            }
                        }

                        break;
                    }
                }

                for (sked__Job__c jobItem : this.RescheduleJobs) {
                    jobItem.sked__Job_Status__c = SkeduloConstants.JOB_STATUS_CANCELLED;
                }
                update this.RescheduleJobs;
                
                //need to remove the break activity of the reschedule job's date of reschedule job's resource if there is no other job for that resource on that date.
                sked__Job__c rescheduleJob;
                for (sked__Job__c job : this.RescheduleJobs) {
                    if (job.sked__Type__c != SkeduloConstants.JOB_TYPE_DRIVERS_ASSIST) {
                        rescheduleJob = job;
                        break;
                    }
                }
                Id rescheduleJobResourceId = rescheduleJob.sked__Job_Allocations__r.get(0).sked__Resource__c;
                Date rescheduleJobDate = Date.parse(this.RescheduleJobs.get(0).sked__Start__c.format(SkeduloConstants.DATE_PARSE_FORMAT));
                DateTime startOfRescheduleJobDate = DateTime.newInstance(rescheduleJobDate, Time.newInstance(0, 0, 0, 0));
                DateTime endOfRescheduleJobDate = startOfRescheduleJobDate.addDays(1);
                sked__Resource__c tempResource = [SELECT Id,
                                                  (SELECT Id
                                                   FROM sked__Job_Allocations__r
                                                   WHERE sked__Status__c != 'Deleted' 
                                                   AND sked__Job__r.sked__Job_Status__c != 'Cancelled'
                                                   AND sked__Job__r.sked__Start__c >= :startOfRescheduleJobDate 
                                                   AND sked__Job__r.sked__Start__c < :endOfRescheduleJobDate),
                                                  (SELECT Id
                                                   FROM sked__Activities__r
                                                   WHERE sked__Type__c = :SkeduloConstants.ACTIVITY_TYPE_BREAK
                                                   AND sked__Start__c < :endOfRescheduleJobDate 
                                                   AND sked__End__c > :startOfRescheduleJobDate)
                                                  FROM sked__Resource__c
                                                  WHERE Id = :rescheduleJobResourceId];
                if (tempResource.sked__Job_Allocations__r == NULL || tempResource.sked__Job_Allocations__r.size() == 0) {
                    if (tempResource.sked__Activities__r != NULL && tempResource.sked__Activities__r.size() > 0) {
                        delete tempResource.sked__Activities__r;
                    }
                }
            }
            
            insert this.MainJob;
            this.MainJobAllocation.sked__Job__c = this.MainJob.Id;
            insert this.MainJobAllocation;

            if (this.DriverAssistJob != NULL) {
                //need to update the previous job (if this is test drive) back location to null
                if (this.PreviousJob != NULL) {
                    this.PreviousJob.Back_to_GeoLocation__Latitude__s = NULL;
                    this.PreviousJob.Back_to_GeoLocation__Longitude__s = NULL;
                    this.PreviousJob.Back_to_Location__c = NULL;
                    this.PreviousJob.Job_to_Hub_Travel_Time__c = 0;
                    update this.PreviousJob;
                }
                boolean isDriverAssistJobDuplicate = CheckDuplicateBooking(this.DriverAssistJob, this.DriverAssistId, this.BookingModel.VehicleId);
                if (isDriverAssistJobDuplicate) {
                    throw new skedBookingGridException('duplicate');
                }
                this.DriverAssistJob.Assist_To_Job__c = this.MainJob.Id;
                insert this.DriverAssistJob;
                this.DriverAssistJobAllocation.sked__Job__c = this.DriverAssistJob.Id;
                insert this.DriverAssistJobAllocation;
            }
            //update new location back to Root Record
            sObject rootRecord;
            if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE) {
                rootRecord = new Test_Drive__c();
            } else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_EVALUATION) {
                rootRecord = new Evaluation__c();
            } else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP) {
                rootRecord = new Pick_Up__c();
            } else if (this.BookingModel.ObjectType == SkeduloConstants.OBJECT_TYPE_DELIVERY) {
                rootRecord = new Delivery__c();
            }
            if (rootRecord != NULL) {
                rootRecord.put('Id', this.BookingModel.ObjectId);
                rootRecord.put('Location__c', this.BookingModel.LocationAddress);
                update rootRecord;
            }
            //create activities for booking job
            if (this.JobTypeActivities != NULL && this.JobTypeActivities.size() > 0) {
                sked__Job__c job = [SELECT Id, Name FROM sked__Job__c WHERE Id = :this.MainJob.Id];
                for (sked__Activity__c jobTypeActivity : this.JobTypeActivities) {
                    jobTypeActivity.sked__Notes__c += job.Name;
                    jobTypeActivity.Related_Job__c = this.MainJob.Id;
                }
                insert this.JobTypeActivities;
            }
            
            CreateBreakActivity();
        }
        
        /*************************************************************Private methods******************************************************************/

        void InitializeSelectedResource() {
            DateTime startOfSelectedDate = DateTime.newInstance(this.BookingModel.SelectedDate, Time.newInstance(0, 0, 0, 0));
            DateTime endOfSelectedDate = startOfSelectedDate.addDays(1);
            
            this.SelectedResource = [SELECT Id, sked__Home_Address__c, sked__GeoLocation__c, sked__GeoLocation__Latitude__s, 
                                     sked__GeoLocation__Longitude__s,
                                     
                                     (SELECT Id, Parking_Lot_ID__r.GeoLocation__c, Parking_Lot_ID__r.Address__c
                                      FROM Staff_Profiles__r),
                                     
                                     (SELECT sked__Resource__c, sked__Job__r.Name, sked__Job__r.sked__Start__c, sked__Job__r.sked__Finish__c, 
                                      sked__Job__r.Hub_to_Job_Travel_Time__c, sked__Job__r.Job_to_Hub_Travel_Time__c,
                                      sked__Job__r.Test_Drive__c, sked__Job__r.Evaluation__c, 
                                      sked__Job__r.Delivery__c, sked__Job__r.Pick_Up__c
                                      FROM sked__Job_Allocations__r
                                      WHERE (NOT sked__Job__c IN :this.BookingModel.ExcludeJobIds)
                                      AND sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED
                                      AND sked__Job__r.sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
                                      AND sked__Job__r.sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_COMPLETE
                                      AND sked__Job__r.sked__Start__c < :endOfSelectedDate
                                      AND sked__Job__r.sked__Finish__c >= :startOfSelectedDate
                                      AND (sked__Resource__c = :resourceId OR sked__Job__r.Vehicle__c = :this.BookingModel.VehicleId)
                                      ORDER BY sked__Job__r.sked__Start__c ASC),
                                     
                                     (SELECT Name, sked__Start__c, sked__End__c, sked__Address__c, sked__GeoLocation__c, sked__Type__c
                                      FROM sked__Activities__r
                                      WHERE (NOT Related_Job__c IN :this.BookingModel.ExcludeJobIds)
                                      AND sked__Start__c < :endOfSelectedDate AND sked__End__c > :startOfSelectedDate
                                      ORDER BY sked__Start__c ASC)
                                     
                                     FROM sked__Resource__c
                                     WHERE Id = :this.ResourceId];
        }
        
        boolean CheckDuplicateBooking(sked__Job__c inputJob, string resourceId, string vehicleId) {
            boolean isDuplicate = FALSE;
            
            for (sked__Job_Allocation__c jobAlloc : this.SelectedResource.sked__Job_Allocations__r) {
                DateTime jobStart = jobAlloc.sked__Job__r.sked__Start__c;
                if (jobAlloc.sked__Job__r.Hub_to_Job_Travel_Time__c != NULL) {
                    jobStart = jobStart.addMinutes((-1) * Integer.valueOf(jobAlloc.sked__Job__r.Hub_to_Job_Travel_Time__c));
                }
                DateTime jobFinish = jobAlloc.sked__Job__r.sked__Finish__c;
                if (jobAlloc.sked__Job__r.Job_to_Hub_Travel_Time__c != NULL) {
                    if (this.PreviousJob == NULL || this.PreviousJob.Id != jobAlloc.sked__Job__c) {
                        jobFinish = jobFinish.addMinutes(Integer.valueOf(jobAlloc.sked__Job__r.Job_to_Hub_Travel_Time__c));
                    }
                }
                if (jobStart < this.EstimateJobFinish && jobFinish > this.EstimateJobStart) {
                    isDuplicate = TRUE;
                    break;
                }
            }
            if (!isDuplicate) {
                boolean isAnyOtherJob = false;
                for (sked__Job_Allocation__c jobAlloc : this.SelectedResource.sked__Job_Allocations__r) {
                    if (jobAlloc.sked__Resource__c == this.ResourceId) {
                        isAnyOtherJob = true;
                        break;
                    }   
                }
                for (sked__Activity__c skedActivity : this.SelectedResource.sked__Activities__r) {
                    //in reschedule mode, if there is no other job in selected date, we should ignore the break activity
                    if (!isAnyOtherJob && skedActivity.sked__Type__c == SkeduloConstants.ACTIVITY_TYPE_BREAK) {
                        continue;
                    }
                    if (skedActivity.sked__Start__c < this.EstimateJobFinish && skedActivity.sked__End__c > this.EstimateJobStart) {
                        isDuplicate = TRUE;
                        break;
                    }
                }
            }
            return isDuplicate;
        }

        sked__Job__c FindPreviousJob(DateTime startOfSelectedDate, DateTime endOfSelectedDate, string resourceId, DateTime currentJobStart) {
            sked__Job__c result;
            List<sked__Job_Allocation__c> allocationsInDay = [SELECT Id, sked__Job__c
                                                              FROM sked__Job_Allocation__c
                                                              WHERE sked__Resource__c = :resourceId
                                                              AND sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED
                                                              AND sked__Job__r.sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
                                                              AND sked__Job__r.sked__Start__c >= :startOfSelectedDate
                                                              AND sked__Job__r.sked__Start__c < :endOfSelectedDate];
            Set<Id> jobIdsInDay = new Set<Id>();
            for (sked__Job_Allocation__c jobAlloc : allocationsInDay) {
                if (!this.RescheduleJobIds.contains(jobAlloc.sked__Job__c)) {
                    jobIdsInDay.add(jobAlloc.sked__Job__c);
                }
            }
            List<sked__Job__c> jobsInSelectedDate = [SELECT Id, Name, sked__Start__c, sked__Type__c, Back_to_GeoLocation__c, Vehicle__r.Parking_Lot_ID__r.GeoLocation__c,
                                                     Vehicle__r.Parking_Lot_ID__r.GeoLocation__Latitude__s, Vehicle__r.Parking_Lot_ID__r.GeoLocation__Longitude__s,
                                                     Vehicle__r.Parking_Lot_ID__r.Address__c, sked__GeoLocation__c,
                                                     Start_from_Location__c, Start_from_GeoLocation__c, Start_from_GeoLocation__Latitude__s, Start_from_GeoLocation__Longitude__s,
                                                     Evaluation__c, Test_Drive__c, Pick_Up__c, Delivery__c, Hub_to_Job_Travel_Time__c, Job_to_Hub_Travel_Time__c
                                                     FROM sked__Job__c 
                                                     WHERE Id IN :jobIdsInDay];
            
            DateTime previousJobStart = startOfSelectedDate;
            if (jobsInSelectedDate != NULL && jobsInSelectedDate.size() > 0) {
                for (sked__Job__c jobItem : jobsInSelectedDate) {
                    if (jobItem.sked__Start__c > previousJobStart && jobItem.sked__Start__c < currentJobStart) {
                        result = jobItem;
                        previousJobStart = jobItem.sked__Start__c;
                    }
                }
            }
            return result;
        }
        
        void InitializeJobTypeActivities() {
            this.JobTypeActivities = new List<sked__Activity__c>();
            for (Job_Type_Activity_Settings__c setting : this.JobTypeActivitySettings) {
                Integer activityDuration = Integer.valueOf(setting.Duration__c);
                
                if (setting.Is_Before__c) {
                    sked__Activity__c beforeActivity = new sked__Activity__c(
                        sked__Type__c = setting.Activity_Type__c,
                        sked__Resource__c = this.ResourceId,
                        sked__Start__c = this.MainJob.Departure_Time__c.addMinutes((-1) * activityDuration),
                        sked__End__c = this.MainJob.Departure_Time__c,
                        sked__Timezone__c = this.BookingModel.TimezoneSidId,
                        sked__Notes__c = setting.Activity_Type__c + ' to '
                    );
                    if (this.MainJob.Start_from_GeoLocation__c != NULL) {
                        beforeActivity.sked__Address__c = this.MainJob.Start_from_Location__c;
                        beforeActivity.sked__GeoLocation__Latitude__s = this.MainJob.Start_from_GeoLocation__Latitude__s;
                        beforeActivity.sked__GeoLocation__Longitude__s = this.MainJob.Start_from_GeoLocation__Longitude__s;
                    }
                    else {
                        beforeActivity.sked__Address__c = this.MainJob.sked__Address__c;
                        beforeActivity.sked__GeoLocation__Latitude__s = this.MainJob.sked__GeoLocation__Latitude__s;
                        beforeActivity.sked__GeoLocation__Longitude__s = this.MainJob.sked__GeoLocation__Longitude__s;
                    }
                    this.EstimateJobStart = beforeActivity.sked__Start__c;
                    this.JobTypeActivities.add(beforeActivity);
                }
                
                if (setting.Is_After__c) {
                    sked__Activity__c afterActivity = new sked__Activity__c(
                        sked__Type__c = setting.Activity_Type__c,
                        sked__Resource__c = this.ResourceId,
                        sked__Start__c = this.MainJob.Return_Time__c,
                        sked__End__c = this.MainJob.Return_Time__c.addMinutes(activityDuration),
                        sked__Timezone__c = this.BookingModel.TimezoneSidId,
                        sked__Notes__c = setting.Activity_Type__c + ' to '
                    );
                    if (this.MainJob.Back_to_GeoLocation__c != NULL) {
                        afterActivity.sked__Address__c = this.MainJob.Back_to_Location__c;
                        afterActivity.sked__GeoLocation__Latitude__s = this.MainJob.Back_to_GeoLocation__Latitude__s;
                        afterActivity.sked__GeoLocation__Longitude__s = this.MainJob.Back_to_GeoLocation__Longitude__s;
                    }
                    else {
                        afterActivity.sked__Address__c = this.MainJob.sked__Address__c;
                        afterActivity.sked__GeoLocation__Latitude__s = this.MainJob.sked__GeoLocation__Latitude__s;
                        afterActivity.sked__GeoLocation__Longitude__s = this.MainJob.sked__GeoLocation__Longitude__s;
                    }
                    this.EstimateJobFinish = afterActivity.sked__End__c;
                    this.JobTypeActivities.add(afterActivity);
                }
            }
        }
        
        void CreateBreakActivity() {
            for (skedBookingGridModel.ResourceModel resource : this.BookingModel.ResourceList) {
                if (resource.Id == this.ResourceId) {
                    string selectedDateString = this.BookingModel.SelectedDate.format();
                	skedBookingGridModel.DateSlotModel dateSlot = resource.DateSlots.get(selectedDateString);
                    if (!dateSlot.NeedBreak) {
                        return;
                    }
                    DateTime startOfSelectedDate = DateTime.newInstance(this.BookingModel.SelectedDate, Time.newInstance(0, 0, 0, 0));
                    DateTime endOfSelectedDate = startOfSelectedDate.addDays(1);
                    List<sked__Activity__c> breakActivities = [SELECT Id
                                                               FROM sked__Activity__c
                                                               WHERE sked__Resource__c = :this.ResourceId
                                                               AND sked__Type__c = :SkeduloConstants.ACTIVITY_TYPE_BREAK
                                                               AND sked__Start__c < :endOfSelectedDate
                                                               AND sked__End__C > :startOfSelectedDate];
                    if (breakActivities != NULL && breakActivities.size() > 0) {
                        return; //already has break activity
                    }
                    sked__Activity__c breakActivity = new sked__Activity__c(
                    	sked__Type__c = SkeduloConstants.ACTIVITY_TYPE_BREAK,
                        sked__Resource__c = this.ResourceId,
                        sked__Timezone__c = this.BookingModel.TimezoneSidId
                    );
                    
                    Integer halfWorkingTimeInMinutes = integer.valueOf((dateSlot.EndWorkingTime.getTime() - dateSlot.StartWorkingTime.getTime()) / 60000) / 2;
                    DateTime midPoint = dateSlot.StartWorkingTime.addMinutes(halfWorkingTimeInMinutes);
                    DateTime earlyThreshold = midPoint.addHours(-2);
                    DateTime lateThreshold = midPoint.addHours(2);
                    
                    boolean isBreakBeforeJob;
                    if (this.EstimateJobStart < earlyThreshold) {
                        isBreakBeforeJob = false;
                    }
                    else {
                        if (this.EstimateJobFinish < lateThreshold) {
                            integer earlyThresholdGap = integer.valueOf((this.EstimateJobStart.getTime() - earlyThreshold.getTime()) / 3600000);
                            integer lateThresholdGap = integer.valueOf((lateThreshold.getTime() - this.EstimateJobFinish.getTime()) / 3600000);
                            isBreakBeforeJob = earlyThresholdGap >= lateThresholdGap;
                        }
                        else {
                            isBreakBeforeJob = true;
                        }
                    }
                    
                    if (isBreakBeforeJob) {
                        breakActivity.sked__Start__c = this.EstimateJobStart.addMinutes((-1) * SkeduloConstants.ACTIVITY_BREAK_DURATION);
                        breakActivity.sked__End__c = this.EstimateJobStart;
                        if (this.MainJob.Start_from_GeoLocation__c != NULL) {
                            breakActivity.sked__Address__c = this.MainJob.Start_from_Location__c;
                            breakActivity.sked__GeoLocation__Latitude__s = this.MainJob.Start_from_GeoLocation__Latitude__s;
                            breakActivity.sked__GeoLocation__Longitude__s = this.MainJob.Start_from_GeoLocation__Longitude__s;
                        }
                        else {
                            breakActivity.sked__Address__c = this.MainJob.sked__Address__c;
                            breakActivity.sked__GeoLocation__Latitude__s = this.MainJob.sked__GeoLocation__Latitude__s;
                            breakActivity.sked__GeoLocation__Longitude__s = this.MainJob.sked__GeoLocation__Longitude__s;
                        }
                    }
                    else {
                        breakActivity.sked__Start__c = this.EstimateJobFinish;
                        breakActivity.sked__End__c = this.EstimateJobFinish.addMinutes(SkeduloConstants.ACTIVITY_BREAK_DURATION);
                        if (this.MainJob.Back_to_GeoLocation__c != NULL) {
                            breakActivity.sked__Address__c = this.MainJob.Back_to_Location__c;
                            breakActivity.sked__GeoLocation__Latitude__s = this.MainJob.Back_to_GeoLocation__Latitude__s;
                            breakActivity.sked__GeoLocation__Longitude__s = this.MainJob.Back_to_GeoLocation__Longitude__s;
                        }
                        else {
                            breakActivity.sked__Address__c = this.MainJob.sked__Address__c;
                            breakActivity.sked__GeoLocation__Latitude__s = this.MainJob.sked__GeoLocation__Latitude__s;
                            breakActivity.sked__GeoLocation__Longitude__s = this.MainJob.sked__GeoLocation__Longitude__s;
                        }
                    }
                    insert breakActivity;
                    break;
                }
            }
        }
    }