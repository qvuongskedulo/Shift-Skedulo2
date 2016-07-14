global class skedBookingGridModel {

	Integer bufferTime = 60;
	Integer defaultVelocity = 60; //km/h
    Integer millisecondsInMinute = 60000;
    public Decimal PreferredScoreVersion = 1.0;

	public Integer NumDaysToDisplay {get;set;}
	public String ObjectId {get;set;}
	public String ObjectType {get;set;}
	public boolean IsReschedule {get;set;}
    public boolean IsSelfScheduledByAPI {get;set;}
	public String AccountName {get;set;}
	public String AccountId {get;set;}
	public String ContactName {get;set;}
	public String ContactId {get;set;}
	public String VehicleName {get;set;}
	public String VehicleId {get;set;}
	public boolean VehicleVisible {get;set;}
	public boolean ManualTransmission {get;set;}
	public String LocationAddress {get;set;}
	public GeoLocation GeoLoc {get;set;}
	public String HubAddress {get;set;}
	public GeoLocation HubGeoLoc {get;set;}
	public Integer Velocity {get;set;} //km/h
	public String ZipCode {get;set;}
	public String JobType {get;set;}
	public Set<string> JobTypes {get;set;}
	public List<SelectOption> JobTypeOptions {get;set;}
	public Map<string, Job_Type_Settings__c> MapJobType {get;set;}
	public Map<string, string> JobType_ResourceTag {get;set;}
	public Map<string, Integer> JobType_Duration {get;set;}
    public Buffer_For_Job_Scheduling__c BufferForJobScheduling {get;set;}
	public List<SelectOption> SubRegionOptions {get;set;}
	public String SubRegionId {get;set;}
	public String RegionId {get;set;}
	public Date SelectedDate {get;set;}
	public Date MinDate {get;set;}
	public Integer MinHour {get;set;}
	public Integer MaxHour {get;set;}
	public List<ResourceModel> ResourceList {get;set;}
	public List<ResourceModel> DriversAssistList {get;set;}
	public String TimezoneSidId {get;set;}
	public String TimezoneShortName {get;set;}
	public DateTime RequestedTime {get;set;}
	public boolean DriversAssist {get;set;}
	public Set<string> DriverAssistJobTypes {get;set;}
	public boolean IsPickupBackflow {get;set;}
    public DateTime LastQuotedAt {get;set;}
    public Date QuoteExpiredDate {
        get {
            if (this.ObjectType != SkeduloConstants.OBJECT_TYPE_EVALUATION || this.TimezoneSidId == NULL || this.LastQuotedAt == NULL) {
                return null;
            }
            // Convert to beginning of day in the region's timezone
            DateTime lastQuotedAtInRegionTz = skedUtils.ConvertBetweenTimezones(this.LastQuotedAt, UserInfo.getTimeZone().getID(), this.TimezoneSidId);
            Date lastQuotedAtDayOfRegion = lastQuotedAtInRegionTz.date();
            return lastQuotedAtDayOfRegion.addDays(SkeduloConstants.EVALUATION_QUOTE_EXPIRED_DAYS);
        }
    }
    public String QuotedExpirationDateFormatted {
        get {
            if (this.QuoteExpiredDate == NULL) {
                return '';
            }
            return this.QuoteExpiredDate.format();
        }
    }
	public boolean DriversAssistVisibility {
		get {
			if (this.DriverAssistJobTypes != NULL && this.DriverAssistJobTypes.size() > 0) {
				return this.DriverAssistJobTypes.contains(this.JobType);
			}
			return FALSE;
		}
	}
	public Integer Duration {get;set;}
	public String ResourceTag {
		get {
			if (this.JobType_ResourceTag != NULL && this.JobType_ResourceTag.containsKey(JobType)) {
				String key = this.JobType;
				if (this.DriversAssist != NULL && this.DriversAssist) {
					key += '_DriversAssist';
				}
				return this.JobType_ResourceTag.get(key);
			}
			return '';
		}
	}
	public List<string> TimeAxisList {
		get {
			List<string> results = new List<string>();
			Integer temp = this.MinHour;
			while (temp <= this.MaxHour) {
				results.add(GetTimeString(temp));
				temp = temp + this.Step;
			}
			return results;
		}
	}
	public Integer Step {
		get {
			return 30;
		}
	}
	public Map<string, Integer> TravelTimeList {get;set;}
	public boolean TriggerEmail {get;set;}
	public Set<Id> ExcludeJobIds {get;set;}
	public boolean NoOTherJobs {get;set;}

	public skedBookingGridModel() {
		this.NumDaysToDisplay = 1;
		this.JobTypes = new Set<string>();
		this.JobTypeOptions = new List<SelectOption>();
		this.SubRegionOptions = new List<SelectOption>();
		this.MapJobType = new Map<string, Job_Type_Settings__c>();
		this.JobType_ResourceTag = new Map<string, string>();
		this.JobType_Duration = new Map<string, Integer>();
		this.ResourceList = new List<ResourceModel>();
		this.DriversAssistList = new List<ResourceModel>();
		this.GeoLoc = new GeoLocation();
		this.HubGeoLoc = new GeoLocation();
		this.Velocity = defaultVelocity;
		this.DriverAssistJobTypes = new Set<string>();
		this.DriversAssist = FALSE;
		this.ManualTransmission = FALSE;
		this.TravelTimeList = new Map<string, Integer>();
		this.IsReschedule = FALSE;
        this.IsSelfScheduledByAPI = FALSE;
		this.IsPickupBackflow = FALSE;
		this.TriggerEmail = TRUE;
		this.ExcludeJobIds = new Set<Id>();
	}

	public void SetJobType(String selectedJobType) {
		this.JobType = selectedJobType;
		LoadDefaultDuration();
		LoadMatchedResources();
	}

	public void SetDuration(Integer inputDuration) {
		this.Duration = inputDuration;
		LoadMatchedResources();
	}

	public void SetSelectedDate(Date d) {
		this.SelectedDate = d;
		LoadMatchedResources();
	}

	public void LoadDefaultDuration() {
		if (this.JobType_Duration != NULL && this.JobType_Duration.containsKey(JobType)) {
			String key = this.JobType;
			if (this.DriversAssist != NULL && this.DriversAssist) {
				key += '_DriversAssist';
			}
			this.Duration = this.JobType_Duration.get(key);
		}
		else {
			this.Duration = 0;
		}
	}

	public void PopulateVehicle(String vehicleId) {
		if (string.isBlank(vehicleId)) {
			return;
		}
		List<Vehicle__c> vehicleResults = [SELECT Id, Name, Parking_Lot_ID__r.Address__c, Parking_Lot_ID__r.GeoLocation__latitude__s, Parking_Lot_ID__r.GeoLocation__longitude__s
		FROM Vehicle__c
		WHERE Id = :vehicleId];
		if (!vehicleResults.isEmpty()) {
			Vehicle__c vehicle = vehicleResults.get(0);
			this.VehicleName = vehicle.Name;
			this.VehicleId = vehicle.Id;

			if (vehicle.Parking_Lot_ID__r != NULL && vehicle.Parking_Lot_ID__r.GeoLocation__latitude__s != NULL && vehicle.Parking_Lot_ID__r.GeoLocation__longitude__s != NULL) {
				this.HubGeoLoc.Latitude = vehicle.Parking_Lot_ID__r.GeoLocation__latitude__s;
				this.HubGeoLoc.Longitude = vehicle.Parking_Lot_ID__r.GeoLocation__longitude__s;
				this.HubAddress = vehicle.Parking_Lot_ID__r.Address__c;
			}
		}
	}
 
    public void PopulateAccountContact(string accountId) {
        if (string.isBlank(accountId)) {
            return;
        }
        Account account = [
            SELECT
                Id,
                Name,
                Primary_Contact_ID__c,
                Primary_Contact_ID__r.Name,
                Primary_Contact_ID__r.Is_Blacklisted__c
            FROM Account
            WHERE Id = :accountId
        ];
        this.AccountId = account.Id;
        this.AccountName = account.Name;
        if (account.Primary_Contact_ID__c != NULL) {
            if (account.Primary_Contact_ID__r.Is_Blacklisted__c == TRUE) {
                throw skedExceptions.newCustomerBlacklistedException(account.Primary_Contact_ID__c);
            }
            this.ContactId = account.Primary_Contact_ID__c;
            this.ContactName = account.Primary_Contact_ID__r.Name;
        }
    }

	public void LoadSubRegions() {
		if (string.isBlank(this.ZipCode) || string.isBlank(this.RegionId)) {
			return;
		}
		List<Region__c> regionResults = [
			SELECT Id, Timezone__c, (SELECT Id, Name, ZIP_Code_List_String__c FROM Regions__r)
			FROM Region__c
			WHERE Id = :this.RegionId
		];

		boolean isZipCodeExisted = FALSE;
		List<SelectOption> subRegionOptions = new List<SelectOption>();
		this.SubRegionId = '';
		this.SubRegionOptions = new List<SelectOption>();

		if (!regionResults.isEmpty()) {
			Region__c region = regionResults.get(0);
			if (!string.isBlank(region.Timezone__c)) {
				this.TimezoneSidId = region.Timezone__c;
				this.TimezoneShortName = system.now().format('z', region.Timezone__c);
			}
			for (Subregion__c subRegion : region.Regions__r) {
				subRegionOptions.add(new SelectOption(subRegion.Id, subRegion.Name));
				if (string.isBlank(this.SubRegionId) && subRegion.ZIP_Code_List_String__c.contains(this.ZipCode)) {
					this.SubRegionId = subRegion.Id;
					isZipCodeExisted = TRUE;
				}
			}
			if (isZipCodeExisted) {
				this.SubRegionOptions = subRegionOptions;
			}
		}
	}

	public void LoadJobTypeSettings() {
		if (string.isBlank(this.ObjectType)) {
			return;
		}
		List<Job_Type_Settings__c> jobTypeSettings = [
			SELECT
				Job_Type__c,
				Resource_Tag__c,
				Duration__c,
				Start_from_Hub__c,
				Back_to_Hub__c,
				Object_Type__c,
				Drivers_Assist__c,
				Not_Show__c
			FROM Job_Type_Settings__c
			WHERE Object_Type__c = :this.ObjectType
			ORDER BY NAME ASC
		];
		for (Job_Type_Settings__c setting : jobTypeSettings) {
			if (!this.JobTypes.contains(setting.Job_Type__c)) {
				this.JobTypes.add(setting.Job_Type__c);
				if (!setting.Not_Show__c) {
					this.JobTypeOptions.add(new SelectOption(setting.Job_Type__c, setting.Job_Type__c));
				}
			}
			String key = setting.Job_Type__c;
			if (setting.Drivers_Assist__c) {
				key += '_DriversAssist';
				this.DriverAssistJobTypes.add(setting.Job_Type__c);
			}
			this.MapJobType.put(key, setting);
			this.JobType_ResourceTag.put(key, setting.Resource_Tag__c);
			this.JobType_Duration.put(key, Integer.valueOf(setting.Duration__c));
		}
 
        List<Buffer_For_Job_Scheduling__c> buffersForJobScheduling = [SELECT
                                                                          Buffer_Time_Minutes__c,
                                                                          Cancel_Buffer_Time_Minutes__c,
                                                                          Reschedule_Buffer_Time_Minutes__c,
                                                                          Earliest_Time_Allowed_Minutes__c,
                                                                          Max_Hour__c,
                                                                          Min_Hour__c
                                                                      FROM Buffer_For_Job_Scheduling__c
                                                                      WHERE Object_Type__c = :this.ObjectType
                                                                      AND Is_Activated__c = TRUE];
        if (buffersForJobScheduling.isEmpty()) {
            return;
        }
        if (buffersForJobScheduling.size() > 1) {
            System.debug(String.valueOf(buffersForJobScheduling.size()) + ' different Buffer_For_Job_Scheduling__c active for object type ' + this.ObjectType);
            return;
        }
        this.BufferForJobScheduling = buffersForJobScheduling.get(0);
    }

	public void LoadMatchedResources() {
		if (string.isBlank(this.JobType) || string.isBlank(this.SubRegionId)) {
            this.ResourceList = new List<ResourceModel>();
			return;
		}

		List<sked__Resource__c> matchedResource = new List<sked__Resource__c>();
		List<string> settingRoles = this.ResourceTag.split(',');
		Set<string> roles = new Set<string>();
		for (String role : settingRoles) {
			roles.add(role);
		}
		Set<string> skills = new Set<string>();
		if (this.ManualTransmission != NULL && this.ManualTransmission) {
			skills.add(SkeduloConstants.RESOURCE_TAG_DRIVE_MANUAL);
		}
		matchedResource.addAll(skedBookingGridUtils.GetResourceByTags(this.SubRegionId, this.SelectedDate, roles, skills));
		
		if (matchedResource.size() == 0) {
			this.ResourceList = new List<ResourceModel>();
			return;
		}

		//get booking location, booking start from location, booking back to location
		String bookingJobTypeKey = this.JobType;
		if (this.DriversAssist != NULL && this.DriversAssist) {
			bookingJobTypeKey += '_DriversAssist';
		}

		Job_Type_Settings__c bookingSetting = this.MapJobType.get(bookingJobTypeKey);
		Location bookingStartFromLoc, bookingBackToLoc, bookingLoc;
		bookingLoc = bookingStartFromLoc = bookingBackToLoc = Location.newInstance(this.GeoLoc.Latitude, this.GeoLoc.Longitude);

		if (ShouldHaveHubAddress()) {
			if (bookingSetting.Start_from_Hub__c) {
				bookingStartFromLoc = Location.newInstance(this.HubGeoLoc.Latitude, this.HubGeoLoc.Longitude);
			}
			if (bookingSetting.Back_to_Hub__c) {
				bookingBackToLoc = Location.newInstance(this.HubGeoLoc.Latitude, this.HubGeoLoc.Longitude);
			}
		}

		Map<string, Location> mapLocation = new Map<string, Location>();
		mapLocation.put('startfrom', bookingStartFromLoc);
		mapLocation.put('location', bookingLoc);
		mapLocation.put('backto', bookingBackToLoc);

		Map<Id, ResourceModel> mapResource = CalculateResourceAvailability(matchedResource, mapLocation, false);
		this.ResourceList = mapResource.values();

		RemoveUnavailableResources(this.ResourceList);
	}

	public void LoadMatchedDriversAssist(Integer jobStartTime, String bookedResourceId) {
		List<sked__Resource__c> matchedResource = new List<sked__Resource__c>();
		Set<string> roles = new Set<string>();
		roles.add(SkeduloConstants.RESOURCE_TAG_DOS);
		Set<string> skills = new Set<string>();
		if (this.ManualTransmission != NULL && this.ManualTransmission) {
			skills.add(SkeduloConstants.RESOURCE_TAG_DRIVE_MANUAL);
		}
		matchedResource.addAll(skedBookingGridUtils.GetResourceByTags(this.SubRegionId, this.SelectedDate, roles, skills));

		for (Integer i = matchedResource.size() - 1; i >= 0; i--) {
			sked__Resource__c skedResource = matchedResource.get(i);
			if (skedResource.Id == bookedResourceId) {
				matchedResource.remove(i);
			}
		}

		if (matchedResource.size() == 0) {
			this.DriversAssistList = new List<ResourceModel>();
			return;
		}

		//driver assist starts from booking hub and back to CE's previous job's hub
		DateTime selectedDateStart, bookingTime;
		selectedDateStart = DateTime.newInstance(this.SelectedDate, Time.newInstance(0, 0, 0, 0));
		selectedDateStart = skedUtils.ConvertBetweenTimezones(selectedDateStart, UserInfo.getTimeZone().getID(), this.TimezoneSidId);

		bookingTime = selectedDateStart.addMinutes(jobStartTime);

		List<sked__Job_Allocation__c> cePreviousAllocations = [SELECT Id, sked__Job__r.Back_to_GeoLocation__c
															   FROM sked__Job_Allocation__c
															   WHERE sked__Resource__c = :bookedResourceId
															   AND (NOT sked__Job__c IN :this.ExcludeJobIds)
															   AND sked__Job__r.sked__Start__c >= :selectedDateStart
															   AND sked__Job__r.sked__Finish__c <= :bookingTime
															   ORDER BY sked__Job__r.sked__Start__c DESC];

		Location bookingStartFromLoc, bookingBackToLoc, bookingLoc;
		bookingLoc = Location.newInstance(this.GeoLoc.Latitude, this.GeoLoc.Longitude);
		bookingStartFromLoc = Location.newInstance(this.HubGeoLoc.Latitude, this.HubGeoLoc.Longitude);
		bookingBackToLoc = bookingStartFromLoc;
		if (cePreviousAllocations != NULL && cePreviousAllocations.size() > 0) {
			sked__Job_Allocation__c mostRecentAllocation = cePreviousAllocations.get(0);
			bookingBackToLoc = mostRecentAllocation.sked__Job__r.Back_to_GeoLocation__c;
		}

		Map<string, Location> mapLocation = new Map<string, Location>();
		mapLocation.put('startfrom', bookingStartFromLoc);
		mapLocation.put('location', bookingLoc);
		mapLocation.put('backto', bookingBackToLoc);

		Map<Id, ResourceModel> mapResource = CalculateResourceAvailability(matchedResource, mapLocation, true);
		this.DriversAssistList = mapResource.values();

		DateTime driversAssistJobStart = bookingTime.addMinutes((-1) * SkeduloConstants.JOB_DURATION_DRIVERS_ASSIST);

		for (Integer i = this.DriversAssistList.size() - 1; i >= 0; i--) {
			ResourceModel resource = this.DriversAssistList.get(i);
			for (TimeSlotModel timeslot : resource.Timeslots) {
				if (timeslot.TimeSlotStart <= driversAssistJobStart && driversAssistJobStart <= timeSlot.TimeSlotEnd) {
					if (timeSlot.IsAvailable == false) {
						this.DriversAssistList.remove(i);
					}
					break;
				}
			}
		}
	}

	public Map<Id, ResourceModel> CalculateResourceAvailability(List<sked__Resource__c> skedResources, Map<string, Location> mapLocation, boolean isLoadingDriversAssist) {
		List<Date> dateList = new List<Date>();
		for (Integer i = 0; i < this.NumDaysToDisplay; i++) {
			dateList.add(this.SelectedDate.addDays(i));
		}
		Set<Id> skedResourceIds = new Set<Id>();
		for (sked__Resource__c skedResource : skedResources) {
			skedResourceIds.add(skedResource.Id);
		}

		Map<Id, ResourceModel> mapResource = InitializeResourceList(skedResources, skedResourceIds, dateList);
		LoadWorkingTime(mapResource, skedResourceIds);

		ResourceModel firstResource = mapResource.values().get(0);
		DateTime startTime, endTime;
		for (DateSlotModel dateSlot : firstResource.DateSlots.values()) {
			if (startTime == NULL || startTime > dateSlot.DateSlotStart) {
				startTime = dateSlot.DateSlotStart;
			}
			if (endTime == NULL || endTime < dateSlot.DateSlotEnd) {
				endTime = dateSlot.DateSlotEnd;
			}
		}
		LoadVehicleEvents(mapResource, skedResourceIds, startTime, endTime);
		LoadResourceEvents(mapResource, skedResourceIds, startTime, endTime);

		//sort all the resource's events ascending by start time
		for (Id resourceId : skedResourceIds) {
			ResourceModel resource = mapResource.get(resourceId);
			for (DateSlotModel dateSlot : resource.DateSlots.values()) {
				dateSlot.Events.sort();
			}
		}
		GetMinMaxDisplayHour(mapResource);
		GenerateTimeslots(mapResource, mapLocation, isLoadingDriversAssist);
		ApplyFilteringRulesToTimeSlots(mapResource);

		return mapResource;
	}

	public Integer GetTravelTime(Location location1, Location location2, DateTime departureTime) {
		long departureTimeEpoc = departureTime.getTime() / 1000;
		if (departureTime >= system.now()) {
			return GetTravelTime(location1, location2, departureTimeEpoc);
		}
		else {
			return GetTravelTime(location1, location2);
		}
	}

	public Integer GetTravelTime(Location location1, Location location2) {
		return GetTravelTime(location1, location2, 0);
	}

	public Integer GetTravelTime(Location location1, Location location2, long departureTime) {
		string loc1String = string.valueOf(location1.getLatitude()) + ',' + string.valueOf(location1.getLongitude());
		string loc2String = string.valueOf(location2.getLatitude()) + ',' + string.valueOf(location2.getLongitude());
		if (loc1String == loc2String) {
			return 0;
		}
		string key = loc1String + '|' + loc2String;
		if (departureTime > 0) {
			key += '|';
			key += departureTime;
		}
		Integer result;

		if (this.TravelTimeList.containsKey(key)) {
			result = this.TravelTimeList.get(key);
		}
		else {
			if (!Test.isRunningTest()) {
				skedGoogleData.DirectionCalloutResult directionCalloutResult = skedGoogleMapCallouts.getDirections(location1, location2, departureTime);
				if (directionCalloutResult == NULL || directionCalloutResult.HasError == TRUE) {
					//TODO: Handle exception
					if (directionCalloutResult != NULL) {
						system.debug('#Google Maps Direction Error: #' + directionCalloutResult.ErrorMessage);
					}
				}
				result = skedGoogleMapCallouts.getDurationInMinutes(directionCalloutResult);
			}
			if (result == NULL) {
				result = skedBookingGridUtils.getTravelTime(location1, location2, this.Velocity);
			}

			this.TravelTimeList.put(key, result);
		}
		return result;
	}
 
    public Boolean ShouldHaveHubAddress() {
        return this.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE || this.ObjectType == SkeduloConstants.OBJECT_TYPE_DELIVERY || (this.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP && this.IsPickupBackflow);
    }
    
    public Boolean ShouldHaveBufferTime() {
        return this.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE || this.ObjectType == SkeduloConstants.OBJECT_TYPE_DELIVERY || (this.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP && this.IsPickupBackflow);
    }

	/*********************************************************Methods*******************************************************/

	Map<Id, ResourceModel> InitializeResourceList(List<sked__Resource__c> skedResources, Set<Id> skedResourceIds, List<Date> dateList) {
		Map<Id, ResourceModel> mapResource = new Map<Id, ResourceModel>();

		Map<Id, Staff_Profile__c> map_ResourceId_StaffProfile = new Map<Id, Staff_Profile__c>();
		List<Staff_Profile__c> staffProfiles = [SELECT Id, Parking_Lot_ID__r.GeoLocation__c, Skedulo_Resource_ID__c, Parking_Lot_ID__r.Address__c,
												Parking_Lot_ID__r.GeoLocation__latitude__s, Parking_Lot_ID__r.GeoLocation__longitude__s
												FROM Staff_Profile__c
												WHERE Skedulo_Resource_ID__c IN :skedResourceIds];
		for (Staff_Profile__c staffProfile : staffProfiles) {
			map_ResourceId_StaffProfile.put(staffProfile.Skedulo_Resource_ID__c, staffProfile);
		}

		for (Integer i = 0; i < skedResources.size(); i++) {
			sked__Resource__c skedResource = skedResources.get(i);
			ResourceModel resource = new ResourceModel();
			resource.Id = skedResource.Id;
			resource.Name = skedResource.Name;
			resource.Title = skedResource.sked__User__r.Title;
			resource.Email = skedResource.sked__Email__c;
			resource.Phone = skedResource.sked__Primary_Phone__c;
			resource.PhotoUrl = skedResource.sked__User__r.SmallPhotoUrl;
            resource.NoBreaks = skedResource.No_Breaks__c;
			resource.DisplayOrder = i + 1;

			Staff_Profile__c staffProfile = map_ResourceId_StaffProfile.get(skedResource.Id);
			if (staffProfile != NULL && staffProfile.Parking_Lot_ID__c != NULL) {
				resource.ParkingLot = new GeoLocation();
				resource.ParkingLot.Latitude = staffProfile.Parking_Lot_ID__r.GeoLocation__latitude__s;
				resource.ParkingLot.Longitude = staffProfile.Parking_Lot_ID__r.GeoLocation__longitude__s;
			}

			for (Date dateValue : dateList) {
				DateTime dayStart = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
				DateSlotModel dateSlot = new DateSlotModel();
				dateSlot.DateValue = dateValue;
				dateSlot.DateString = dateValue.format();
				dateSlot.Weekday = dayStart.format('E').toUpperCase();

				dateSlot.DateSlotStart = skedUtils.ConvertBetweenTimezones(dayStart, this.TimezoneSidId, UserInfo.getTimeZone().getID());
				dateSlot.DateSlotEnd = dateSlot.DateSlotStart.addDays(1);

				dateSlot.AddEvent(dateSlot.DateSlotStart, dateSlot.DateSlotEnd, 'non-working', false);

				resource.DateSlots.put(dateSlot.DateString, dateSlot);
			}

			mapResource.put(skedResource.Id, resource);
		}

		return mapResource;
	}

	void LoadWorkingTime(Map<Id, ResourceModel> mapResource, Set<Id> skedResourceIds) {
        List<sked__Availability_Template_Resource__c> templateResourceList = [SELECT sked__Resource__c, sked__Availability_Template__c
                                                                              FROM sked__Availability_Template_Resource__c
                                                                              WHERE sked__Resource__c IN :skedResourceIds
                                                                              AND (sked__Availability_Template__r.sked__Start__c = NULL 
                                                                                   OR sked__Availability_Template__r.sked__Start__c <= :this.SelectedDate)
                                                                              AND (sked__Availability_Template__r.sked__Finish__c = NULL 
                                                                                   OR sked__Availability_Template__r.sked__Finish__c >= :this.SelectedDate)];
		Map<Id, Id> map_ResourceId_TemplateId = new Map<Id, Id>();
		for (sked__Availability_Template_Resource__c atr : templateResourceList) {
			map_ResourceId_TemplateId.put(atr.sked__Resource__c, atr.sked__Availability_Template__c);
		}
		map<Id, sked__Availability_Template__c> mapTemplate
			= new map<Id, sked__Availability_Template__c>([SELECT Id,
														   (SELECT Id, sked__Finish_Time__c, sked__Is_Available__c, sked__Start_Time__c, sked__Weekday__c
															FROM sked__Availability_Template_Entries__r)
														   FROM sked__Availability_Template__c
														   WHERE Id IN :map_ResourceId_TemplateId.values()]);
		Map<string, Set<Date>> mapHolidays = skedUtils.getHolidays();
		Set<Date> allHolidays = new Set<Date>();
		if (mapHolidays.containsKey('global')) {
			Set<Date> globalHolidays = mapHolidays.get('global');
			allHolidays.addAll(globalHolidays);
		}
		if (mapHolidays.containsKey(this.RegionId)) {
			Set<Date> regionHolidays = mapHolidays.get(this.RegionId);
			allHolidays.addAll(regionHolidays);
		}
		for (ResourceModel resource : mapResource.values()) {
            if (!map_ResourceId_TemplateId.containsKey(resource.Id)) {
                continue;
            }
			Id templateId = map_ResourceId_TemplateId.get(resource.Id);
			sked__Availability_Template__c avaiTemplate = mapTemplate.get(templateId);

			Map<string, sked__Availability_Template_Entry__c> mapEntry = new Map<string, sked__Availability_Template_Entry__c>();
			for (sked__Availability_Template_Entry__c entry : avaiTemplate.sked__Availability_Template_Entries__r) {
				mapEntry.put(entry.sked__Weekday__c, entry);
			}
			for (DateSlotModel dateSlot : resource.DateSlots.values()) {
				if (!mapEntry.containsKey(dateSlot.Weekday)) {
					continue;
				}
				if (allHolidays.contains(dateSlot.DateValue)) {
					continue;
				}
				sked__Availability_Template_Entry__c entry = mapEntry.get(dateSlot.Weekday);
				Integer startWorkingInMinutes = Integer.valueOf(Integer.valueOf(entry.sked__Start_Time__c) / 100) * 60 + Math.mod(Integer.valueOf(entry.sked__Start_Time__c), 100);
				Integer endWorkingInMinutes = Integer.valueOf(Integer.valueOf(entry.sked__Finish_Time__c) / 100) * 60 + Math.mod(Integer.valueOf(entry.sked__Finish_Time__c), 100);

				DateTime startWorkingTime = dateSlot.DateSlotStart.addMinutes(startWorkingInMinutes);
				DateTime endWorkingTime = dateSlot.DateSlotStart.addMinutes(endWorkingInMinutes);
				dateSlot.StartWorkingTime = startWorkingTime;
				dateSlot.EndWorkingTime = endWorkingTime;
                
                if (!resource.NoBreaks) {
                    if ((endWorkingInMinutes - startWorkingInMinutes) >= 360) { //any employee who has working time more than 6 hours needs a break
                        dateSlot.NeedBreak = true;
                    }
                }
                dateSlot.AddEvent(startWorkingTime, endWorkingTime, null, true);
                
                DateTime currentTime = system.now();
                if (ShouldHaveBufferTime()) {
                    currentTime = currentTime.addMinutes(bufferTime);
                }
                if (startWorkingTime < currentTime && currentTime < dateSlot.DateSlotEnd) {
                    DateTime availableStartTime = startWorkingTime > currentTime ? startWorkingTime : currentTime;
                    dateSlot.AddEvent(startWorkingTime, availableStartTime, 'unavailable', false);
                }
			}
		}
	}

	void LoadVehicleEvents(Map<Id, ResourceModel> mapResource, Set<Id> skedResourceIds, DateTime startTime, DateTime endTime) {
		List<sked__Job__c> vehicleJobs = [SELECT Id, Name, sked__Start__c, sked__Finish__c, Hub_to_Job_Travel_Time__c, Job_to_Hub_Travel_Time__c,
										  Evaluation__c, Test_Drive__c, Pick_Up__c, Delivery__c
										  FROM sked__Job__c
										  WHERE Vehicle__c = :this.VehicleId
										  AND (NOT Id IN :this.ExcludeJobIds)
										  AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
										  AND sked__Start__c <= :endTime AND sked__Finish__c >= :startTime];

		for (sked__Job__c job : vehicleJobs) {
			String jobDateString = job.sked__Start__c.format(SkeduloConstants.DATE_PARSE_FORMAT, this.TimezoneSidId);

			Integer hubToJobTravelTime = job.Hub_to_Job_Travel_Time__c == NULL ? 0 : Integer.valueOf(job.Hub_to_Job_Travel_Time__c);
			Integer jobToHubTravelTime = job.Job_to_Hub_Travel_Time__c == NULL ? 0 : Integer.valueOf(job.Job_to_Hub_Travel_Time__c);

			DateTime vehicleBusyFrom = job.sked__Start__c.addMinutes((-1) * hubToJobTravelTime);
			DateTime vehicleBusyTo = job.sked__Finish__c.addMinutes(jobToHubTravelTime);

			for (Id resourceId : skedResourceIds) {
				ResourceModel resource = mapResource.get(resourceId);
				DateSlotModel dateSlot = resource.DateSlots.get(jobDateString);
				dateSlot.AddEvent(vehicleBusyFrom, vehicleBusyTo, null, null, 'vehicle', false);
			}
		}
	}

	void LoadResourceEvents(Map<Id, ResourceModel> mapResource, Set<Id> skedResourceIds, DateTime startTime, DateTime endTime) {
		Map<Id, sked__Resource__c> mapSkedResources = GetResourceWithAvailabilities(skedResourceIds, startTime, endTime);

		for (Id resourceId : skedResourceIds) {
			ResourceModel resource = mapResource.get(resourceId);
			sked__Resource__c skedResource = mapSkedResources.get(resourceId);

			for (sked__Availability__c availableBlock : skedResource.sked__Availabilities1__r) {
				if (availableBlock.sked__Is_Available__c != TRUE) {
					continue;
				}
				DateTime availableStart = availableBlock.sked__Start__c;
				DateTime availableEnd = availableBlock.sked__Finish__c;

				DateSlotModel firstDateSlot = resource.DateSlots.values().get(0);
				if (availableStart < firstDateSlot.DateSlotStart) {
					availableStart = firstDateSlot.DateSlotStart;
				}
				DateSlotModel lastDateSlot = resource.DateSlots.values().get(resource.DateSlots.values().size() - 1);
				if (availableEnd > lastDateSlot.DateSlotEnd) {
					availableEnd = lastDateSlot.DateSlotEnd;
				}
                
                String availableDateString = availableStart.format(SkeduloConstants.DATE_PARSE_FORMAT, this.TimezoneSidId);
                DateSlotModel dateSlot = resource.DateSlots.get(availableDateString);
                if (dateSlot.StartWorkingTime == NULL || dateSlot.StartWorkingTime > availableStart) {
                    dateSlot.StartWorkingTime = availableStart;
                }
                if (dateSlot.EndWorkingTime == NULL || dateSlot.EndWorkingTime < availableEnd) {
                    dateSlot.EndWorkingTime = availableStart;
                }
                
                DateTime currentTime = system.now();
                if (ShouldHaveBufferTime()) {
                    currentTime = currentTime.addMinutes(bufferTime);
                }
                if (currentTime < availableEnd) {
                    if (availableStart < currentTime) {
                        availableStart = currentTime;
                    }
                    dateSlot.AddEvent(availableStart, availableEnd, null, true);
                }
			}

			for (sked__Availability__c availableBlock : skedResource.sked__Availabilities1__r) {
				if (availableBlock.sked__Is_Available__c != FALSE) {
					continue;
				}
				DateTime availableStart = availableBlock.sked__Start__c;
				DateTime availableEnd = availableBlock.sked__Finish__c;

				DateSlotModel firstDateSlot = resource.DateSlots.values().get(0);
				if (availableStart < firstDateSlot.DateSlotStart) {
					availableStart = firstDateSlot.DateSlotStart;
				}
				DateSlotModel lastDateSlot = resource.DateSlots.values().get(resource.DateSlots.values().size() - 1);
				if (availableEnd > lastDateSlot.DateSlotEnd) {
					availableEnd = lastDateSlot.DateSlotEnd;
				}
				String availableDateString = availableStart.format(SkeduloConstants.DATE_PARSE_FORMAT, this.TimezoneSidId);
				DateSlotModel dateSlot = resource.DateSlots.get(availableDateString);
                if (dateSlot.StartWorkingTime != NULL && dateSlot.StartWorkingTime >= availableStart && dateSlot.StartWorkingTime < availableEnd) {
                    dateSlot.StartWorkingTime = availableEnd;
                }
                if (dateSlot.EndWorkingTime != NULL && dateSlot.EndWorkingTime >= availableStart && dateSlot.EndWorkingTime < availableEnd) {
                    dateSlot.EndWorkingTime = availableStart;
                }
				dateSlot.AddEvent(availableStart, availableEnd, 'unavailable', false);
			}

			for (sked__Job_Allocation__c allocation : skedResource.sked__Job_Allocations__r) {
				String allocationDateString = allocation.sked__Job__r.sked__Start__c.format(SkeduloConstants.DATE_PARSE_FORMAT, this.TimezoneSidId);
				DateSlotModel dateSlot = resource.DateSlots.get(allocationDateString);
				if (resource.DateSlots.containsKey(allocationDateString)) {
					DateTime jobStart = allocation.sked__Job__r.sked__Start__c;
					DateTime jobEnd = allocation.sked__Job__r.sked__Finish__c;
					Location jobLocation = allocation.sked__Job__r.sked__GeoLocation__c;
                    dateSlot.JobAllocationCountForResource++;
					dateSlot.AddEvent(jobStart, jobEnd, jobLocation, 'allocation', false);

					if (allocation.sked__Job__r.Hub_to_Job_Travel_Time__c != NULL) {
						Integer hubToJobMinutes = Integer.valueOf(allocation.sked__Job__r.Hub_to_Job_Travel_Time__c);
						dateSlot.AddEvent(jobStart.addMinutes((-1) * hubToJobMinutes), jobStart, allocation.sked__Job__r.Start_from_GeoLocation__c, jobLocation, 'travel-time', false);
					}
					if (allocation.sked__Job__r.Job_to_Hub_Travel_Time__c != NULL && this.DriversAssist == false) {
						Integer jobToHubMinutes = Integer.valueOf(allocation.sked__Job__r.Job_to_Hub_Travel_Time__c);
						dateSlot.AddEvent(jobEnd, jobEnd.addMinutes(jobToHubMinutes), jobLocation, allocation.sked__Job__r.Back_to_GeoLocation__c, 'travel-time', false);
					}
				}
			}

			for (sked__Activity__c activity : skedResource.sked__Activities__r) {
                //in reschedule mode, if the only job in selected date is the reschedule job, we should ignore the break activity
                if (skedResource.sked__Job_Allocations__r == NULL || skedResource.sked__Job_Allocations__r.size() == 0) {
                    if (activity.sked__Type__c == SkeduloConstants.ACTIVITY_TYPE_BREAK) {
                        continue;
                    }
                }
                
				String activityDateString = activity.sked__Start__c.format(SkeduloConstants.DATE_PARSE_FORMAT, this.TimezoneSidId);
				if (resource.DateSlots.containsKey(activityDateString)) {
					DateSlotModel dateSlot = resource.DateSlots.get(activityDateString);
                    if (activity.sked__Type__c == SkeduloConstants.ACTIVITY_TYPE_BREAK) {
                        dateSlot.HasBreak = true;
                    }
					dateSlot.AddEvent(activity.sked__Start__c, activity.sked__End__c, activity.sked__GeoLocation__c, 'activity', false);
				}
			}
		}
	}

	void GetMinMaxDisplayHour(Map<Id, ResourceModel> mapResource) {
        DateTime minTime, maxTime;
        for (ResourceModel resource : mapResource.values()) {
            String selectedDateString = this.SelectedDate.format();
 
            if (resource.DateSlots.containsKey(selectedDateString)) {
                DateSlotModel dateSlot = resource.DateSlots.get(selectedDateString);
                EventModel firstEvent = dateSlot.Events.get(0);
                EventModel lastEvent = dateSlot.Events.get(dateSlot.Events.size() - 1);
                if (minTime == NULL || minTime > firstEvent.EndTime) {
                    minTime = firstEvent.EndTime;
                }
                if (maxTime == NULL || maxTime < lastEvent.StartTime) {
                    maxTime = lastEvent.StartTime;
                }
            }
        }
 
        this.MinHour = Integer.valueOf(minTime.format('Hmm', this.TimezoneSidId));
        this.MinHour = Integer.valueOf(this.MinHour / 100) * 60 + minTime.minute();
        this.MaxHour = Integer.valueOf(maxTime.format('Hmm', this.TimezoneSidId));
        this.MaxHour = Integer.valueOf(this.MaxHour / 100) * 60 + maxTime.minute();
    }

	void GenerateTimeSlots(Map<Id, ResourceModel> mapResource, Map<string, Location> mapLocation, boolean isLoadingDriversAssist) {
		String bookingJobTypeKey = this.JobType;
		if (this.DriversAssist != NULL && this.DriversAssist) {
			bookingJobTypeKey += '_DriversAssist';
		}
		Job_Type_Settings__c jobTypeSetting = this.MapJobType.get(bookingJobTypeKey);
        List<Job_Type_Activity_Settings__c> jobTypeActivitySettings = [SELECT Name, Activity_Type__c, Duration__c, Is_After__c, Is_Before__c
                                                                       FROM Job_Type_Activity_Settings__c
                                                                       WHERE Job_Type__c = :this.JobType];
		for (ResourceModel resource : mapResource.values()) {
			if (this.ObjectType == SkeduloConstants.OBJECT_TYPE_TEST_DRIVE || this.ObjectType == SkeduloConstants.OBJECT_TYPE_EVALUATION || (this.ObjectType == SkeduloConstants.OBJECT_TYPE_PICKUP && !this.IsPickupBackflow)) {
				Location bookingStartFromLoc, bookingBackToLoc;
				if (jobTypeSetting.Start_from_Hub__c) {
					bookingStartFromLoc = Location.newInstance(resource.ParkingLot.Latitude, resource.ParkingLot.Longitude);
					mapLocation.put('startfrom', bookingStartFromLoc);
				}
				if (jobTypeSetting.Back_to_Hub__c) {
					bookingBackToLoc = Location.newInstance(resource.ParkingLot.Latitude, resource.ParkingLot.Longitude);
					mapLocation.put('backto', bookingBackToLoc);
				}
			}

			resource.TimeSlots = new List<TimeSlotModel>();

			for (DateSlotModel dateSlot : resource.DateSlots.values()) {
				Map<DateTime, TimeslotModel> mapTimeSlot = InitializeTimeSlots(dateSlot);

				if (isLoadingDriversAssist == false && this.DriversAssist == true) {
					for (Integer i = 0; i < dateSlot.Events.size(); i++) {
						EventModel eventItem = dateSlot.Events.get(i);
						if (eventItem.EventType == 'allocation' || i == dateSlot.Events.size() - 1) {
							EventModel firstEvent = dateSlot.Events.get(0);
							UpdateTimeSlotAvailability(mapTimeSlot, firstEvent.EndTime, eventItem.StartTime, 'cannot-book');
							break;
						}
					}
				}
                
                List<EventModel> processedEvents = new List<EventModel>();
                for (EventModel eventItem : dateSlot.Events) {
                    if (processedEvents.isEmpty()) {
                        processedEvents.add(eventItem);
                        continue;
                    }
                    EventModel lastProcessedEvent = processedEvents.get(processedEvents.size() - 1);
                    if (lastProcessedEvent.EndTime < eventItem.EndTime) {
                        processedEvents.add(eventItem);
                    }
                }

				for (Integer i = 0; i < processedEvents.size(); i++) {
					EventModel eventItem = processedEvents.get(i);
					DateTime eventStartTime = eventItem.StartTime;
					DateTime eventEndTime = eventItem.EndTime;

					Integer eventStartTimeMinute = eventStartTime.minute();
					Integer tempInt = Math.mod(eventStartTimeMinute, this.Step);
					if (tempInt != 0) {
						eventStartTime = eventStartTime.addMinutes((-1) * tempInt);
					}

					Integer eventEndTimeMinute = eventEndTime.minute();
					tempInt = Math.mod(eventEndTimeMinute, this.Step);
					if (tempInt != 0) {
						eventEndTime = eventEndTime.addMinutes(this.Step - tempInt);
					}

					UpdateTimeSlotAvailability(mapTimeSlot, eventStartTime, eventEndTime, eventItem.EventType);

					if (i < processedEvents.size() - 1) {
						EventModel nextEventItem = processedEvents.get(i + 1);
						if (eventItem.EndTime < nextEventItem.StartTime) {
							CheckAvailabililityBetweenEvents(mapTimeSlot, eventItem, nextEventItem, mapLocation, i, processedEvents.size(), jobTypeSetting, jobTypeActivitySettings, isLoadingDriversAssist);
						}
					}
				}
				resource.TimeSlots.addAll(mapTimeSlot.values());
			}
		}
	}
    
    void ApplyBufferForJobSchedulingToTimeSlots(Map<Id, ResourceModel> mapResource, DateTime currentTime) {
        if (this.BufferForJobScheduling == NULL) {
            return;
        }
 
        DateTime minTimeForBookingWithoutEmployeeApproval = currentTime.addMinutes(Integer.valueOf(this.BufferForJobScheduling.Buffer_Time_Minutes__c));
        DateTime nowInRegionTz = skedUtils.ConvertBetweenTimezones(currentTime, UserInfo.getTimeZone().getID(), this.TimezoneSidId);
        DateTime todayInRegionTz =  DateTime.newInstance(nowInRegionTz.date(), Time.newInstance(0, 0, 0, 0));
        if (nowInRegionTz.hour() > this.BufferForJobScheduling.Max_Hour__c) {
            minTimeForBookingWithoutEmployeeApproval = todayInRegionTz.addDays(1).addMinutes(Integer.valueOf(this.BufferForJobScheduling.Earliest_Time_Allowed_Minutes__c));
        } else if (nowInRegionTz.hour() < this.BufferForJobScheduling.Min_Hour__c) {
            minTimeForBookingWithoutEmployeeApproval = todayInRegionTz.addMinutes(Integer.valueOf(this.BufferForJobScheduling.Earliest_Time_Allowed_Minutes__c));
        }
 
        for (ResourceModel resource : mapResource.values()) {
            for (TimeSlotModel timeSlot : resource.TimeSlots) {
                if (timeslot.TimeSlotStart < minTimeForBookingWithoutEmployeeApproval) {
                    timeSlot.EmployeeApprovalRequired = TRUE;
                }
            }
        }
    }

	void ApplyFilteringRulesToTimeSlots(Map<Id, ResourceModel> mapResource) {
        DateTime now = System.now();
        DateTime minTimeForBooking = now.addMinutes(bufferTime);
 
        ApplyBufferForJobSchedulingToTimeSlots(mapResource, now);

		List<Booking_Availability_Settings__c> availabilitySettings = [SELECT Start__c, End__c, Is_Available__c
																	   FROM Booking_Availability_Settings__c
																	   WHERE Object_Type__c = :this.ObjectType];
		Boolean noOtherJobFlag = FALSE;
		for (ResourceModel resource : mapResource.values()) {
			for (Integer i = resource.TimeSlots.size() - 1; i >= 0; i--) {
				TimeSlotModel timeSlot = resource.TimeSlots.get(i);
				if (timeSlot.StartTime < this.MinHour || timeSlot.EndTime > this.MaxHour) {
					resource.TimeSlots.remove(i);
					continue;
				}
				if (this.RequestedTime != NULL && timeSlot.TimeSlotStart <= this.RequestedTime && this.RequestedTime < timeSlot.TimeSlotEnd) {
					timeSlot.IsRequestedTime = TRUE;
				}
				if (timeSlot.StyleClass == 'cannot-book') {
					noOtherJobFlag = TRUE;
				}
			}
            Integer timeSlotIndex = 0;
            for (DateSlotModel dateSlot : resource.DateSlots.values()) {
                if (dateSlot.StartWorkingTime != NULL) {
                    for (Booking_Availability_Settings__c setting : availabilitySettings) {
                        while (timeSlotIndex < resource.TimeSlots.size()) {
                            TimeSlotModel timeSlot = resource.TimeSlots.get(timeSlotIndex);
                            DateTime bookingAvailabilityStart = dateSlot.StartWorkingTime.addMinutes(Integer.valueOf(setting.Start__c));
                            DateTime bookingAvailabilityEnd = dateSlot.StartWorkingTime.addMinutes(Integer.valueOf(setting.End__c));
                            if (timeSlot.TimeSlotStart >= bookingAvailabilityStart && timeSlot.TimeSlotStart < bookingAvailabilityEnd) {
                                timeSlot.IsAvailable = timeSlot.IsAvailable && setting.Is_Available__c;
                                timeSlot.EmployeeApprovalRequired = timeSlot.EmployeeApprovalRequired || setting.Employee_Approval_Required__c;
                            } else if (timeSlot.TimeSlotStart >= bookingAvailabilityEnd) {
                                break;
                            }
                            timeSlotIndex++;
                        }
                    }
                }
            }
		}
		this.NoOtherJobs = noOtherJobFlag;
	}

    void CheckAvailabililityBetweenEvents(Map<DateTime, TimeSlotModel> mapTimeSlot, EventModel currentEvent, EventModel nextEvent,
                                          Map<string, Location> mapLocation, Integer index, Integer noOfEvents, Job_Type_Settings__c jobTypeSetting,
                                          List<Job_Type_Activity_Settings__c> jobTypeActivitySettings, boolean isLoadingDriversAssist)
	{
		Integer totalRequiredTime = this.Duration;
		if (currentEvent.EndTime.addMinutes(totalRequiredTime) > nextEvent.StartTime) {
			UpdateTimeSlotAvailability(mapTimeSlot, currentEvent.EndTime, nextEvent.StartTime, 'not-enough');
			return;
		}

		sked_Booking_Email_Setting__c bookingSetting = sked_Booking_Email_Setting__c.getOrgDefaults();
		Location bookingStartFromLoc = mapLocation.get('startfrom');
		Location bookingLoc = mapLocation.get('location');
		Location bookingBackToLoc = mapLocation.get('backto');

		Integer travelTimeFromCurrentEvent = 0;
		Integer travelTimeToNextEvent = 0;
		Integer hubToJobTravelTime = 0;
		Integer jobToHubTravelTime = 0;
        Integer activityTimeBeforeJob = 0;
        Integer activityTimeAfterJob = 0;
        
        if (!isLoadingDriversAssist) {
            for (Job_Type_Activity_Settings__c jobTypeActivitySetting : jobTypeActivitySettings) {
                if (jobTypeActivitySetting.Duration__c != NULL) {
                    if (jobTypeActivitySetting.Is_Before__c) {
                        activityTimeBeforeJob += integer.valueOf(jobTypeActivitySetting.Duration__c);
                    }
                    if (jobTypeActivitySetting.Is_After__c) {
                        activityTimeAfterJob += integer.valueOf(jobTypeActivitySetting.Duration__c);
                    }
                }
            }
        }

		Location currentEventLoc;
		if (this.DriversAssist) {
			currentEventLoc = currentEvent.GetStartLocation();
		}
		else {
			currentEventLoc = currentEvent.GetEndLocation();
		}
		if (currentEventLoc != NULL) {
			travelTimeFromCurrentEvent += GetTravelTime(currentEventLoc, bookingStartFromLoc, currentEvent.EndTime);
		}
		hubToJobTravelTime += GetTravelTime(bookingStartFromLoc, bookingLoc, currentEvent.EndTime.addMinutes(travelTimeFromCurrentEvent));
        
		totalRequiredTime = totalRequiredTime + travelTimeFromCurrentEvent + activityTimeBeforeJob + hubToJobTravelTime;
		if (currentEvent.EndTime.addMinutes(totalRequiredTime) > nextEvent.StartTime) {
			UpdateTimeSlotAvailability(mapTimeSlot, currentEvent.EndTime, nextEvent.StartTime, 'not-enough');
			return;
		}

		Location nextEventLoc = nextEvent.GetStartLocation();
		if (nextEventLoc != NULL) {
			travelTimeToNextEvent += GetTravelTime(bookingBackToLoc, nextEventLoc, nextEvent.StartTime.addMinutes((-1) * this.Step));
		}
		jobToHubTravelTime += GetTravelTime(bookingLoc, bookingBackToLoc, nextEvent.StartTime.addMinutes((-1) * (travelTimeFromCurrentEvent + this.Step)));

		Integer totalTravelTimeAfter = travelTimeToNextEvent + jobToHubTravelTime;
		DateTime availableStart = currentEvent.EndTime.addMinutes(travelTimeFromCurrentEvent + activityTimeBeforeJob + hubToJobTravelTime);
		DateTime availableEnd = nextEvent.StartTime.addMinutes((-1) * totalTravelTimeAfter);

		if (index == noOfEvents - 2) {
			Integer lastJobRuleMinutes = 60;
			if (bookingSetting.Last_Job_Rule_Minutes__c != NULL || bookingSetting.Last_Job_Rule_Minutes__c >= 0) {
				lastJobRuleMinutes = Integer.valueOf(bookingSetting.Last_Job_Rule_Minutes__c);
			}
			if (totalTravelTimeAfter <= lastJobRuleMinutes) {
				availableEnd = nextEvent.StartTime;
			}
			else {
				availableEnd = nextEvent.StartTime.addMinutes(lastJobRuleMinutes - totalTravelTimeAfter);
			}
		}

		if (availableStart < availableEnd) {
			DateTime firstAvailableSlot = availableStart;
			Integer availableStartMinute = firstAvailableSlot.minute();
			Integer tempInt = Math.mod(availableStartMinute, this.Step);
			if (tempInt != 0) {
				firstAvailableSlot = firstAvailableSlot.addMinutes(this.Step - tempInt);

				if (firstAvailableSlot.addMinutes(this.Duration + travelTimeToNextEvent + jobToHubTravelTime) > nextEvent.StartTime) {
					UpdateTimeSlotAvailability(mapTimeSlot, currentEvent.EndTime, nextEvent.StartTime, 'not-enough');
					return;
				}
			}
			Integer totalTime = 0;
            DateTime tempDt = firstAvailableSlot;
            while (tempDt < availableEnd) {
                totalTime += this.Step;
                tempDt = tempDt.addMinutes(this.Step);
            }
            tempDt = firstAvailableSlot;
            while (tempDt < availableEnd) {
                TimeSlotModel timeSlot = mapTimeSlot.get(tempDt);
                if (tempDt.addMinutes(this.Duration) > availableEnd) {
                    timeSlot.IsAvailable = false;
                    timeSlot.StyleClass = 'not-enough';
                } else {
                    timeSlot.IdleTimeBefore = (tempDt.addMinutes((-1) * hubToJobTravelTime).getTime() - currentEvent.EndTime.addMinutes(travelTimeFromCurrentEvent).getTime()) / millisecondsInMinute;
                    timeSlot.IdleTimeAfter = (nextEvent.StartTime.addMinutes((-1) * travelTimeToNextEvent).getTime() - tempDt.addMinutes(this.Duration + jobToHubTravelTime).getTime()) / millisecondsInMinute;
                    timeSlot.PreferredScore = ScoreIdleTime(totalTime, timeSlot.IdleTimeBefore) + ScoreIdleTime(totalTime, timeSlot.IdleTimeAfter);
                }
                tempDt = tempDt.addMinutes(this.Step);
            }
		}
        if (travelTimeFromCurrentEvent + hubToJobTravelTime > 60) {
            DateTime longTravelTimeslotDt = availableStart;
            Integer longTravelTimeslotMinute = longTravelTimeslotDt.minute();
            integer tempInt = Math.mod(longTravelTimeslotMinute, this.Step);
            if (tempInt != 0) {
                longTravelTimeslotDt = longTravelTimeslotDt.addMinutes(this.Step - tempInt);
            }
            TimeslotModel longTravelTimeslot = mapTimeSlot.get(longTravelTimeslotDt);
            longTravelTimeslot.StyleClass = 'long-travel-time';
        }
		UpdateTimeSlotAvailability(mapTimeSlot, currentEvent.EndTime, availableStart, 'travel-time');
		UpdateTimeSlotAvailability(mapTimeSlot, availableEnd, availableEnd.addMinutes(totalTravelTimeAfter), 'travel-time');
	}
    
    // Score from 0-10 to help determine if a timeslot is efficient in terms of idle time created
    // See https://docs.google.com/document/d/1vFQxc3IiLteUZuvO_Ka9sftGZMkfccO-X0EDAhPezOw/edit
    Double ScoreIdleTime(Integer totalTime, Long idleTime) {
        if (totalTime > 180) {
            if (idleTime <= 45) {
                return 5.0;
            }
            if (idleTime <= 90) {
                return 1.5;
            }
            if (idleTime <= 135) {
                return 0.0;
            }
            if (idleTime < 180) {
                return 2.0;
            }
            return 3.5;
        } else {
            if (idleTime <= 45) {
                return 5.0;
            }
            if (idleTime <= 120) {
                return 2.0;
            }
            return 3.0;
        }
    }

	Map<DateTime, TimeslotModel> InitializeTimeSlots(DateSlotModel dateSlot) {
		Map<DateTime, TimeslotModel> mapTimeSlot = new Map<DateTime, TimeslotModel>();

		DateTime tempDt = dateSlot.DateSlotStart;
		while (tempDt < dateSlot.DateSlotEnd) {
			TimeSlotModel timeSlot = new TimeSlotModel();
			timeSlot.TimeSlotStart = tempDt;
			timeSlot.TimeSlotEnd = tempDt.addMinutes(this.Step);
			Integer hours = Integer.valueOf(tempDt.format('H', this.TimezoneSidId));
			Integer minutes = Integer.valueOf(tempDt.format('mm', this.TimezoneSidId));
			timeSlot.DateString = dateSlot.DateString;
			timeSlot.StartTime = hours * 60 + minutes;
			timeSlot.EndTime = timeSlot.StartTime + this.Step;
			timeSlot.IsAvailable = true;

			mapTimeSlot.put(timeSlot.TimeSlotStart, timeSlot);

			tempDt = tempDt.addMinutes(this.Step);
		}
		return mapTimeSlot;
	}

	void UpdateTimeSlotAvailability(Map<DateTime, TimeSlotModel> mapTimeSlot, DateTime startTime, DateTime endTime, String styleClass) {
		Integer startTimeMinute = startTime.minute();
		Integer tempInt = Math.mod(startTimeMinute, this.Step);
		if (tempInt != 0) {
			startTime = startTime.addMinutes((-1) * tempInt);
		}

		Integer endTimeMinute = endTime.minute();
		tempInt = Math.mod(endTimeMinute, this.Step);
		if (tempInt != 0) {
			endTime = endTime.addMinutes(this.Step - tempInt);
		}

		DateTime tempDt = startTime;
		while (tempDt < endTime) {
			if (mapTimeSlot.containsKey(tempDt)) {
				TimeslotModel timeSlot = mapTimeSlot.get(tempDt);
				timeSlot.IsAvailable = false;
				if (string.isBlank(timeSlot.StyleClass)) {
					timeSlot.StyleClass = styleClass;
				}
				else if (!timeSlot.StyleClass.contains(styleClass)) {
					timeSlot.StyleClass += ' ' + styleClass;
				}
			}
			tempDt = tempDt.addMinutes(this.Step);
		}
	}

	void RemoveUnavailableResources(List<ResourceModel> resources) {
		for (Integer i = resources.size() - 1; i >= 0; i--) {
			ResourceModel resource = resources.get(i);
			boolean availableCheck = FALSE;
			for (TimeSlotModel timeslot : resource.Timeslots) {
				if (timeslot.IsAvailable) {
					availableCheck = TRUE;
					break;
				}
			}
			if (!availableCheck) {
				resources.remove(i);
			}
		}
		for (Integer i = 0; i < resources.size(); i++) {
			ResourceModel resource = resources.get(i);
			resource.DisplayOrder = i + 1;
		}
	}

	Map<Id, sked__Resource__c> GetResourceWithAvailabilities(Set<Id> orderedResourceIds, DateTime startTime, DateTime endTime) {
		return new Map<Id, sked__Resource__c>([SELECT Id, Name, sked__User__r.SmallPhotoUrl, sked__User__c, sked__GeoLocation__c,
											   sked__GeoLocation__Latitude__s, sked__GeoLocation__Longitude__s, sked__Home_Address__c, No_Breaks__c,
											   (SELECT sked__Job__c, sked__Job__r.sked__Type__c, sked__Job__r.sked__Start__c, sked__Job__r.sked__Finish__c,
												sked__Job__r.Name, sked__Job__r.sked__Timezone__c, sked__Job__r.sked__GeoLocation__c,
												sked__Job__r.Drivers_Assist__c, sked__Job__r.Vehicle__r.Parking_Lot_ID__r.GeoLocation__c,
												sked__Estimated_Travel_Time__c, sked__Job__r.Start_from_GeoLocation__c, sked__Job__r.Back_to_GeoLocation__c,
												sked__Job__r.Evaluation__c, sked__Job__r.Test_Drive__c, sked__Job__r.Pick_Up__c, sked__Job__r.Delivery__c,
												sked__Job__r.Hub_to_Job_Travel_Time__c, sked__Job__r.Job_to_Hub_Travel_Time__c
												FROM sked__Job_Allocations__r
												WHERE sked__Status__c != 'Deleted' AND sked__Job__r.sked__Job_Status__c != 'Cancelled'
												AND (NOT sked__Job__c IN :this.ExcludeJobIds)
												AND sked__Job__r.sked__Start__c >= :startTime AND sked__Job__r.sked__Start__c < :endTime
												ORDER BY sked__Job__r.sked__Start__c ASC),
											   (SELECT Name, sked__Start__c, sked__Finish__c, sked__Is_Available__c
												FROM sked__Availabilities1__r
												WHERE sked__Start__c < :endTime AND sked__Finish__c > :startTime
												AND sked__Status__c = 'Approved'
												ORDER BY sked__Start__c ASC),
											   (SELECT Name, sked__Start__c, sked__End__c, sked__Address__c, sked__GeoLocation__c, sked__Type__c
												FROM sked__Activities__r
												WHERE (NOT Related_Job__c IN :this.ExcludeJobIds)
												AND sked__Start__c < :endTime AND sked__End__c > :startTime
												ORDER BY sked__Start__c ASC)
											   FROM sked__Resource__c
											   WHERE Id IN :orderedResourceIds]);
	}

	String GetTimeString(Integer timeInMinutes) {
		Integer hour = Integer.valueOf(timeInMinutes / 60);
		Integer minute = Math.mod(timeInMinutes, 60);
		String period = hour >= 12 ? 'pm' : 'am';
		hour = hour > 12 ? hour - 12 : hour;
		String minuteString = string.valueOf(minute) + '00';
		minuteString = minuteString.substring(0, 2);
		return string.valueOf(hour) + ':' + minuteString + period;
	}

	/*********************************************************Nested Classes*******************************************************/

	public class ResourceModel {
		public Integer DisplayOrder {get;set;}
		public String Name {get;set;}
		public String Id {get;set;}
		public String Title {get;set;}
		public String Email {get;set;}
		public String Phone {get;set;}
		public String PhotoUrl {get;set;}
        public Boolean NoBreaks {get;set;}
		public GeoLocation ParkingLot {get;set;}
		public Map<string, DateSlotModel> DateSlots {get;set;}
		public List<TimeSlotModel> Timeslots {get;set;}

		public ResourceModel() {
			this.DateSlots = new Map<string, DateSlotModel>();
			Timeslots = new List<TimeSlotModel>();
		}
	}

	public class DateSlotModel {
		public Date DateValue {get;set;}
		public String DateString {get;set;}
		public String Weekday {get;set;}
		public DateTime DateSlotStart {get;set;}
		public DateTime DateSlotEnd {get;set;}
		public DateTime StartWorkingTime {get;set;}
		public DateTime EndWorkingTime {get;set;}
        public Integer JobAllocationCountForResource {get;set;}
        public boolean NeedBreak {get;set;}
        public boolean HasBreak {get;set;}
		public List<EventModel> Events {get;set;}

		public DateSlotModel() {
            this.NeedBreak = false;
            this.HasBreak = false;
			this.Events = new List<EventModel>();
            this.JobAllocationCountForResource = 0;
		}

		public void AddEvent(DateTime startTime, DateTime endTime, String eventType, boolean isAvailable) {
			AddEvent(startTime, endTime, null, null, eventType, isAvailable);
		}

		public void AddEvent(DateTime startTime, DateTime endTime, Location geoLocation, String eventType, boolean isAvailable) {
			AddEvent(startTime, endTime, geoLocation, null, eventType, isAvailable);
		}

		public void AddEvent(DateTime startTime, DateTime endTime, Location geoLocation, Location geoLocation2, String eventType, boolean isAvailable) {
			if (isAvailable == true) {
				AddAvailableBlock(startTime, endTime);
			}
			else {
				EventModel newEvent = new EventModel();
				newEvent.StartTime = startTime;
				newEvent.EndTime = endTime;
				newEvent.EventType = eventType;
				if (geoLocation != NULL) {
					newEvent.EventLocation = new GeoLocation(geoLocation);
				}
				if (geoLocation2 != NULL) {
					newEvent.EventLocation2 = new GeoLocation(geoLocation2);
				}
				this.Events.add(newEvent);
			}
		}

		void AddAvailableBlock(DateTime startTime, DateTime endTime) {
			List<EventModel> newEvents = new List<EventModel>();
			Set<DateTime> removedEvents = new Set<DateTime>();

			for (EventModel eventItem : Events) {
				if (eventItem.StartTime < startTime && startTime < eventItem.EndTime) {
					if (endTime < eventItem.EndTime) {
						EventModel newEvent = new EventModel();
						newEvent.StartTime = endTime;
						newEvent.EndTime = eventItem.EndTime;
						newEvent.EventType = eventItem.EventType;
						newEvents.add(newEvent);
					}
					eventItem.EndTime = startTime;
				}
				else if (startTime <= eventItem.StartTime) {
					if (endTime >= eventItem.EndTime) {
						removedEvents.add(eventItem.StartTime);
					}
					else if (eventItem.StartTime < endTime && endTime < eventItem.EndTime) {
						eventItem.StartTime = endTime;
					}
				}
			}

			for (Integer i = this.Events.size() - 1; i >= 0; i--) {
				EventModel eventItem = this.Events.get(i);
				if (removedEvents.contains(eventItem.StartTime)) {
					this.Events.remove(i);
				}
			}

			this.Events.addAll(newEvents);
		}
	}

	public class EventModel implements Comparable {
		public DateTime StartTime {get;set;}
		public DateTime EndTime {get;set;}
		public String EventType {get;set;}
		public GeoLocation EventLocation {get;set;}
		public GeoLocation EventLocation2 {get;set;}

		public Location GetStartLocation() {
			Location startLocation;
			if (this.EventLocation != NULL) {
				startLocation = Location.newInstance(this.EventLocation.Latitude, this.EventLocation.Longitude);
			}
			return startLocation;
		}

		public Location GetEndLocation() {
			Location endLocation;
			if (this.EventLocation != NULL) {
				if (this.EventLocation2 != NULL) {
					endLocation = Location.newInstance(this.EventLocation2.Latitude, this.EventLocation2.Longitude);
				}
				else {
					endLocation = Location.newInstance(this.EventLocation.Latitude, this.EventLocation.Longitude);
				}
			}
			return endLocation;
		}

		public Integer compareTo(Object compareTo) {
			EventModel compareToRecord = (EventModel)compareTo;
			Integer returnValue = 0;

			if (StartTime > compareToRecord.StartTime) {
				returnValue = 1;
			} else if (StartTime < compareToRecord.StartTime) {
				returnValue = -1;
			} else {
                if (EndTime > compareToRecord.EndTime) {
                    returnValue = -1;
                } else if (EndTime < compareToRecord.EndTime) {
                    returnValue = 1;
                }
            }
			return returnValue;
		}
	}

	public class TimeSlotModel {
		public DateTime TimeSlotStart {get;set;}
		public DateTime TimeSlotEnd {get;set;}
		public String DateString {get;set;}
		public Integer StartTime {get;set;}
		public Integer EndTime {get;set;}
        public Boolean IsRequestedTime {get;set;}
        public Boolean IsAvailable {get;set;}
        public Boolean EmployeeApprovalRequired {get;set;}
        public Boolean IsBestSlot {get;set;}
        public String StyleClass {get;set;}
        public Id JobId {get;set;}
        public Long IdleTimeBefore {get;set;}
        public Long IdleTimeAfter {get;set;}
        public Double PreferredScore {get;set;}

		public TimeSlotModel() {
            IsAvailable = TRUE;
            EmployeeApprovalRequired = FALSE;
            IsRequestedTime = FALSE;
            IsBestSlot = FALSE;
            PreferredScore = 0.0;
		}
	}

	public class GeoLocation {
		public double Latitude {get;set;}
		public double Longitude {get;set;}

		public GeoLocation() {}

		public GeoLocation(Location inputLocation) {
			if (inputLocation != NULL) {
				this.Latitude = inputLocation.getLatitude();
				this.Longitude = inputLocation.getLongitude();
			}
		}
	}
}