global class skedBookingGridUtils {
	
	global static List<sked__Job__c> GetRelatedJobs(String objectType, String objectId) {
		List<sked__Job__c> relatedJobs;
		if (objectType == 'evaluation') {
			relatedJobs = [SELECT Id, Name, sked__Type__c, sked__Start__c, Drivers_Assist__c,
							(SELECT sked__Resource__c
							FROM sked__Job_Allocations__r
							WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
							FROM sked__Job__c
							WHERE Evaluation__c = :objectId
							AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
							ORDER BY CreatedDate DESC];
		}
		else if (objectType == 'testdrive') {
			relatedJobs = [SELECT Id, Name, sked__Type__c, sked__Start__c, Drivers_Assist__c,
							(SELECT sked__Resource__c
							FROM sked__Job_Allocations__r
							WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
							FROM sked__Job__c
							WHERE Test_Drive__c = :objectId
							AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
							ORDER BY CreatedDate DESC];
		}
		else if (objectType == 'pickup') {
			relatedJobs = [SELECT Id, Name, sked__Type__c, sked__Start__c, Drivers_Assist__c,
							(SELECT sked__Resource__c
							FROM sked__Job_Allocations__r
							WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
							FROM sked__Job__c
							WHERE Pick_Up__c = :objectId
							AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
							ORDER BY CreatedDate DESC];
		}
		else if (objectType == 'delivery') {
			relatedJobs = [SELECT Id, Name, sked__Type__c, sked__Start__c, Drivers_Assist__c,
							(SELECT sked__Resource__c
							FROM sked__Job_Allocations__r
							WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
							FROM sked__Job__c
							WHERE Delivery__c = :objectId
							AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED
							ORDER BY CreatedDate DESC];
		}
		return relatedJobs;
	}
	
	global static Integer getTravelTime(Location fromLoc, Location toLoc, Integer velocity) {
		if (fromLoc == NULL || toLoc == NULL) {
			return 0;
		}

		double distance = fromLoc.getDistance(toLoc, 'km');
		double travelTime = 0;
		if (velocity != 0) {
			travelTime = Math.ceil((distance / velocity) * 60);
		}
		
		return Integer.valueOf(travelTime);
	}

	global static List<sked__Resource__c> GetResourceByTag(String SubRegion_Id, Date dateValue, String role) {
		Set<String> roles = new Set<String>();
		Set<String> skills = new Set<String>();
		roles.add(role);
		return GetResourceByTags(SubRegion_Id, dateValue, roles, skills);
	}
	
	global static List<sked__Resource__c> GetResourceByTags(String SubRegion_Id, Date dateValue, Set<String> roles, Set<String> skills) {
		List<Subregion_Assignment__c> assignments = [SELECT Id, Is_Primary__c, Staff_Profile_ID__r.Skedulo_Resource_ID__c, Staff_Profile_ID__r.Skedulo_Resource_ID__r.Name
													 FROM Subregion_Assignment__c
													 WHERE Subregion_ID__c = :SubRegion_Id
													 AND DAY_ONLY(Starts_At__c) <= :dateValue
													 AND DAY_ONLY(Ends_At__c) >= :dateValue];
		
		Set<Id> resourceIds = new Set<Id>();
		Set<Id> primaryResourceIds = new Set<Id>();
		for (Subregion_Assignment__c assignment : assignments) {
			if (!String.isBlank(assignment.Staff_Profile_ID__r.Skedulo_Resource_ID__c)) {
				resourceIds.add(assignment.Staff_Profile_ID__r.Skedulo_Resource_ID__c);
				if (assignment.Is_Primary__c) {
					primaryResourceIds.add(assignment.Staff_Profile_ID__r.Skedulo_Resource_ID__c);
				}
			}
		}
		
		List<sked__Resource__c> subregionResources = [SELECT Id, Name, sked__Email__c, sked__Primary_Phone__c,
														sked__User__r.Title, sked__User__r.SmallPhotoUrl, No_Breaks__c,
													  (SELECT Id, Parking_Lot_ID__r.GeoLocation__c
														FROM Staff_Profiles__r),
													  (SELECT sked__Tag__c, sked__Tag__r.Name
														FROM sked__ResourceTags__r
														WHERE sked__Expiry_Date__c = NULL OR sked__Expiry_Date__c>= :dateValue)
													  FROM sked__Resource__c
													  WHERE Id IN :resourceIds];
		
		List<sked__Resource__c> matchedResources = new List<sked__Resource__c>();
		//if the resources do not have staff profile or parking lot, that resource will not be loaded
		for (sked__Resource__c resource : subregionResources) {
			if (resource.Staff_Profiles__r == NULL || resource.Staff_Profiles__r.size() == 0){
				continue;
			} else {
				Staff_Profile__c staffProfile = resource.Staff_Profiles__r.get(0);
				if (staffProfile.Parking_Lot_ID__r == NULL || staffProfile.Parking_Lot_ID__r.GeoLocation__c == NULL) {
					continue;
				}
			}

			if (resource.sked__ResourceTags__r != NULL && resource.sked__ResourceTags__r.size() > 0) {
				Set<String> resourceTags = new Set<String>();
				for (sked__Resource_Tag__c item : resource.sked__ResourceTags__r) {
					resourceTags.add(item.sked__Tag__r.Name);
				}
				boolean roleMatched = FALSE;
				for (String role : roles) {
					if (resourceTags.contains(role)) {
						roleMatched = TRUE;
						break;
					}
				}
				if (roleMatched) {
					if (skills.size() == 0 || resourceTags.containsAll(skills)) {
						matchedResources.add(resource);
					}
				}
			}
		}

		List<sked__Resource__c> orderedList = new List<sked__Resource__c>();
		if (matchedResources.size() > 0) {
			for (Integer i = matchedResources.size() - 1; i >= 0; i-- ) {
				sked__Resource__c resource = matchedResources.get(i);
				if (primaryResourceIds.contains(resource.Id)) {
					orderedList.add(resource);
					matchedResources.remove(i);
				}
			}
			if (matchedResources.size() > 0) {
				orderedList.addAll(matchedResources);
			}
		}

		return orderedList;
	}
	
	global static List<SearchResult> GetDriversAssist(String regionTimezone, String subRegionId, DateTime jobStart, Integer duration) {
		List<SearchResult> results = new List<SearchResult>();
		String dateString = jobStart.format('yyyy-MM-dd', regionTimezone);
		Date dateValue = skedUtils.ConvertToDateValue(dateString);
		List<sked__Resource__c> matchedResources = skedBookingGridUtils.GetResourceByTag(subRegionId, dateValue, SkeduloConstants.RESOURCE_TAG_DOS);
		//TODO: Need to verify whether the driver assists are free at the booking time
		for (sked__Resource__c resource : matchedResources) {
			SearchResult result = new SearchResult();
			result.Text = resource.Name;
			result.Value = resource.Id;
			results.add(result);
		}
		return results;
	}

	global class SearchResult {
		public String Text {get;set;}
		public String Value {get;set;}
	}

	global static String GetZipcodeFromAddress(String address) {
		if (String.isBlank(address)) {
			return '';
		}
		Integer zipcode;
		address = address.replace(',', ' ');
		String[] addressComponents = address.split(' ');
		for (String component : addressComponents) {
			component = component.trim();
			if (component.length() != 5) {
				continue;
			}
			try {
				zipcode = Integer.valueOf(component);
			}
			catch (Exception ex) {
				continue;
			}
		}
		if (zipcode == NULL) {
			return '';
		}
		return String.valueOf(zipcode);
	}
}