public class ShiftStaffProfiles {
	static void validateUserIds(List<Staff_Profile__c> staffProfiles) {
		Set<Id> userIds = new Set<Id>();
		for (Staff_Profile__c staffProfile : staffProfiles) {
			if (staffProfile.User_ID__c == null) {
				staffProfile.addError('User ID is null');
				continue;
			}
			userIds.add(staffProfile.User_ID__c);
		}
	}

	static void validateSingleStaffProfilePerUser(Map<Id, Staff_Profile__c> oldMap, List<Staff_Profile__c> newList) {
		Set<Id> userIds = new Set<Id>();
		for (Staff_Profile__c sp : newList) {
			if (oldMap == null || oldMap.get(sp.Id).User_ID__c != sp.User_ID__c) {
				userIds.add(sp.User_ID__c);
			}
		}
		if (userIds.isEmpty()) {
			return;
		}
		List<AggregateResult> staffProfilesCountsResults = [
			SELECT User_ID__c, COUNT(Id) NumStaffProfiles
			FROM Staff_Profile__c
			WHERE User_ID__c IN :userIds
			GROUP BY User_ID__c
		];
		Set<Id> usersWithTooManyProfiles = new Set<Id>();
		for (AggregateResult result : staffProfilesCountsResults) {
			if ((Integer) result.get('NumStaffProfiles') > 1) {
				usersWithTooManyProfiles.add((Id) result.get('User_ID__c'));
			}
		}

		for (Staff_Profile__c sp : newList) {
			if(usersWithTooManyProfiles.contains(sp.User_ID__c)) {
				sp.addError('User cannot be associated with multiple staff profiles.');
			}
		}
	}

	static sked__Resource__c skeduloResourceForStaffProfile(Staff_Profile__c staffProfile) {
		return new sked__Resource__c(
			Id = staffProfile.Skedulo_Resource_ID__c,
			Name = staffProfile.User_ID__r.Name,
			sked__User__c = staffProfile.User_ID__c,
			sked__Home_Address__c = staffProfile.Home_Address__c,
			sked__Primary_Region__c = staffProfile.Region_ID__r.Skedulo_Region_ID__c,
			sked__Resource_Type__c = ShiftConstants.SKEDULO_RESOURCE_TYPE_PERSON,
			sked__Email__c = staffProfile.Email__c
		);
	}

	static sked__Tag__c skeduloTagForStaffProfileAttribute(Staff_Profile_Attribute__c attribute) {
		String skeduloTagType = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_TO_SKEDULO_TAG_TYPE.get(attribute.Type__c);
		if (skeduloTagType == null) {
			return null;
		}
		return new sked__Tag__c(
			Id = attribute.Skedulo_Tag_ID__c,
			Name = attribute.Shift_Key__c,
			sked__Classification__c = ShiftConstants.SKEDULO_TAG_CLASSIFICATION_GLOBAL,
			sked__Type__c = skeduloTagType
		);
	}

	static sked__Resource_Tag__c skeduloResourceTagForStaffProfileAttributeAssociation(Staff_Profile_Attribute_Association__c association) {
		return new sked__Resource_Tag__c(
			Id = association.Skedulo_Resource_Tag_ID__c,
			sked__Resource__c = association.Staff_Profile_ID__r.Skedulo_Resource_ID__c,
			sked__Tag__c = association.Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c
		);
	}

	static void insertSkeduloResources(List<Staff_Profile__c> newStaffProfiles) {
		List<Staff_Profile__c> newStaffProfilesWithSkeduloRegions = [
			SELECT
				Skedulo_Resource_ID__c,
				User_ID__c,
				User_ID__r.Name,
				Home_Address__c,
				Region_ID__r.Skedulo_Region_ID__c,
				Email__c
			FROM Staff_Profile__c
			WHERE Id IN :newStaffProfiles
		];
		List<sked__Resource__c> skeduloResourcesToInsert = new List<sked__Resource__c>();
		List<sked__Resource__c> skeduloResourcesToUpdate = new List<sked__Resource__c>();
		Map<Id, sked__Resource__c> staffProfileIdToNewSkeduloResource = new Map<Id, sked__Resource__c>();
		for (Staff_Profile__c staffProfile : newStaffProfilesWithSkeduloRegions) {
			sked__Resource__c skeduloResource = skeduloResourceForStaffProfile(staffProfile);
			if (staffProfile.Skedulo_Resource_ID__c == null) {
				staffProfileIdToNewSkeduloResource.put(staffProfile.Id, skeduloResource);
				skeduloResourcesToInsert.add(skeduloResource);
			} else {
				skeduloResourcesToUpdate.add(skeduloResource);
			}
		}
		insert skeduloResourcesToInsert;
		update skeduloResourcesToUpdate;

		List<Staff_Profile__c> staffProfilesToUpdate = new List<Staff_Profile__c>();
		for (Staff_Profile__c staffProfile : newStaffProfiles) {
			sked__Resource__c skeduloResource = staffProfileIdToNewSkeduloResource.get(staffProfile.Id);
			if (skeduloResource == null) {
				continue;
			}
			staffProfilesToUpdate.add(new Staff_Profile__c(
				Id = staffProfile.Id,
				Skedulo_Resource_ID__c = skeduloResource.Id
			));
		}
		update staffProfilesToUpdate;
	}

	static void updateSkeduloResources(List<Staff_Profile__c> newStaffProfiles) {
		List<Staff_Profile__c> newStaffProfilesWithSkeduloRegions = [
			SELECT
				Skedulo_Resource_ID__c,
				User_ID__c,
				User_ID__r.Name,
				Home_Address__c,
				Region_ID__r.Skedulo_Region_ID__c,
				Email__c
			FROM Staff_Profile__c
			WHERE Id IN :newStaffProfiles
		];
		List<sked__Resource__c> skeduloResourcesToUpdate = new List<sked__Resource__c>();
		for (Staff_Profile__c staffProfile : newStaffProfilesWithSkeduloRegions) {
			if (staffProfile.Skedulo_Resource_ID__c == null) {
				staffProfile.Skedulo_Resource_ID__c.addError('"Skedulo Resource" cannot be NULL');
				continue;
			}
			skeduloResourcesToUpdate.add(skeduloResourceForStaffProfile(staffProfile));
		}
		update skeduloResourcesToUpdate;
	}

	static void deleteSkeduloResources(List<Staff_Profile__c> oldStaffProfiles) {
		List<sked__Resource__c> skeduloResourcesToDelete = new List<sked__Resource__c>();
		for (Staff_Profile__c staffProfile : oldStaffProfiles) {
			skeduloResourcesToDelete.add(new sked__Resource__c(Id = staffProfile.Skedulo_Resource_ID__c));
		}
		delete skeduloResourcesToDelete;
	}

	static void insertSkeduloTags(List<Staff_Profile_Attribute__c> newAttributes) {
		List<sked__Tag__c> skeduloTagsToInsert = new List<sked__Tag__c>();
		List<sked__Tag__c> skeduloTagsToUpdate = new List<sked__Tag__c>();
		Map<Id, sked__Tag__c> attributeIdToNewSkeduloTag = new Map<Id, sked__Tag__c>();
		for (Staff_Profile_Attribute__c attribute : newAttributes) {
			sked__Tag__c skeduloTag = skeduloTagForStaffProfileAttribute(attribute);
			if (skeduloTag == null) {
				continue;
			}
			if (attribute.Skedulo_Tag_ID__c == null) {
				attributeIdToNewSkeduloTag.put(attribute.Id, skeduloTag);
				skeduloTagsToInsert.add(skeduloTag);
			} else {
				skeduloTagsToUpdate.add(skeduloTag);
			}
		}
		insert skeduloTagsToInsert;
		update skeduloTagsToUpdate;

		for (Staff_Profile_Attribute__c attribute : newAttributes) {
			sked__Tag__c skeduloTag = attributeIdToNewSkeduloTag.get(attribute.Id);
			if (skeduloTag == null) {
				continue;
			}
			attribute.Skedulo_Tag_ID__c = skeduloTag.Id;
		}
	}

	static void updateSkeduloTags(List<Staff_Profile_Attribute__c> newAttributes) {
		// This method is intended to be called in a before update trigger; it sets 
		// the value of a Staff Profile Attribute field which is intended to be written
		// as part of the update.
		System.assert(Trigger.isBefore && Trigger.isUpdate);

		List<sked__Tag__c> skeduloTagsToInsert = new List<sked__Tag__c>();
		List<sked__Tag__c> skeduloTagsToUpdate = new List<sked__Tag__c>();
		List<sked__Tag__c> skeduloTagsToDelete = new List<sked__Tag__c>();
		Map<Id, sked__Tag__c> attributeIdToSkeduloTag = new Map<Id, sked__Tag__c>();
		for (Staff_Profile_Attribute__c attribute : newAttributes) {
			sked__Tag__c skeduloTag = skeduloTagForStaffProfileAttribute(attribute);
			if (skeduloTag == null) {
				if (attribute.Skedulo_Tag_ID__c != null) {
					skeduloTagsToDelete.add(new sked__Tag__c(
						Id = attribute.Skedulo_Tag_ID__c
					));
				}
			} else {
				if (attribute.Skedulo_Tag_ID__c == null) {
					attributeIdToSkeduloTag.put(attribute.Id, skeduloTag);
					skeduloTagsToInsert.add(skeduloTag);
				} else {
					skeduloTagsToUpdate.add(skeduloTag);
				}
			}
		}
		insert skeduloTagsToInsert;
		update skeduloTagsToUpdate;
		delete skeduloTagsToDelete;

		// This loop sets values to be written as part of this update.
		for (Staff_Profile_Attribute__c attribute : newAttributes) {
			sked__Tag__c skeduloTag = attributeIdToSkeduloTag.get(attribute.Id);
			if (skeduloTag == null) {
				continue;
			}
			attribute.Skedulo_Tag_ID__c = skeduloTag.Id;
		}
	}

	static void insertSkeduloResourceTagsForNewSkeduloTags(Map<Id, Staff_Profile_Attribute__c> oldAttributeMap, List<Staff_Profile_Attribute__c> newAttributes) {
		Set<Id> attributeIdsWithNewSkeduloTags = new Set<Id>();
		for (Staff_Profile_Attribute__c attribute : newAttributes) {
			if (oldAttributeMap.get(attribute.Id).Skedulo_Tag_ID__c == null && attribute.Skedulo_Tag_ID__c != null) {
				attributeIdsWithNewSkeduloTags.add(attribute.Id);
			}
		}
		List<Staff_Profile_Attribute_Association__c> associations = [
			SELECT Id
			FROM Staff_Profile_Attribute_Association__c
			WHERE Staff_Profile_Attribute_ID__c IN :attributeIdsWithNewSkeduloTags
		];
		insertSkeduloResourceTags(associations);
	}

	static void deleteSkeduloTags(List<Staff_Profile_Attribute__c> oldAttributes) {
		List<sked__Tag__c> skeduloTagsToDelete = new List<sked__Tag__c>();
		for (Staff_Profile_Attribute__c attribute : oldAttributes) {
			if (attribute.Skedulo_Tag_ID__c != null) {
				skeduloTagsToDelete.add(new sked__Tag__c(Id = attribute.Skedulo_Tag_ID__c));
			}
		}
		delete skeduloTagsToDelete;
	}

	static void insertSkeduloResourceTags(List<Staff_Profile_Attribute_Association__c> newAssociations) {
		List<Staff_Profile_Attribute_Association__c> newAssociationsWithSkeduloIds = [
			SELECT
				Skedulo_Resource_Tag_ID__c,
				Staff_Profile_ID__r.Skedulo_Resource_ID__c,
				Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c
			FROM Staff_Profile_Attribute_Association__c
			WHERE Id IN :newAssociations
		];
		List<sked__Resource_Tag__c> skeduloResourceTagsToInsert = new List<sked__Resource_Tag__c>();
		List<sked__Resource_Tag__c> skeduloResourceTagsToUpdate = new List<sked__Resource_Tag__c>();
		Map<Id, sked__Resource_Tag__c> associationIdToNewSkeduloResourceTag = new Map<Id, sked__Resource_Tag__c>();
		for (Staff_Profile_Attribute_Association__c association : newAssociationsWithSkeduloIds) {
			sked__Resource_Tag__c skeduloResourceTag = skeduloResourceTagForStaffProfileAttributeAssociation(association);
			if (skeduloResourceTag.sked__Tag__c == null) {
				continue;
			}
			if (association.Skedulo_Resource_Tag_ID__c == null) {
				associationIdToNewSkeduloResourceTag.put(association.Id, skeduloResourceTag);
				skeduloResourceTagsToInsert.add(skeduloResourceTag);
			} else {
				skeduloResourceTagsToUpdate.add(skeduloResourceTag);
			}
		}
		insert skeduloResourceTagsToInsert;
		insert skeduloResourceTagsToUpdate;

		List<Staff_Profile_Attribute_Association__c> associationsToUpdate = new List<Staff_Profile_Attribute_Association__c>();
		for (Staff_Profile_Attribute_Association__c association : newAssociations) {
			sked__Resource_Tag__c skeduloResourceTag = associationIdToNewSkeduloResourceTag.get(association.Id);
			if (skeduloResourceTag == null) {
				continue;
			}
			associationsToUpdate.add(new Staff_Profile_Attribute_Association__c(
				Id = association.Id,
				Skedulo_Resource_Tag_ID__c = skeduloResourceTag.Id
			));
		}
		update associationsToUpdate;
	}

	static void updateSkeduloResourceTags(List<Staff_Profile_Attribute_Association__c> newAssociations) {
		List<Staff_Profile_Attribute_Association__c> newAssociationsWithSkeduloIds = [
			SELECT
				Skedulo_Resource_Tag_ID__c,
				Staff_Profile_ID__r.Skedulo_Resource_ID__c,
				Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c
			FROM Staff_Profile_Attribute_Association__c
			WHERE Id IN :newAssociations
		];
		List<sked__Resource_Tag__c> skeduloResourceTagsToUpdate = new List<sked__Resource_Tag__c>();
		for (Staff_Profile_Attribute_Association__c association : newAssociationsWithSkeduloIds) {
			skeduloResourceTagsToUpdate.add(skeduloResourceTagForStaffProfileAttributeAssociation(association));
		}
		update skeduloResourceTagsToUpdate;
	}

	static void deleteSkeduloResourceTags(List<Staff_Profile_Attribute_Association__c> oldAssociations) {
		List<sked__Resource_Tag__c> skeduloResourceTagsToDelete = new List<sked__Resource_Tag__c>();
		for (Staff_Profile_Attribute_Association__c association : oldAssociations) {
			skeduloResourceTagsToDelete.add(new sked__Resource_Tag__c(Id = association.Skedulo_Resource_Tag_ID__c));
		}
		delete skeduloResourceTagsToDelete;
	}

	public static void beforeStaffProfileInsert(List<Staff_Profile__c> newStaffProfiles) {
		validateUserIds(newStaffProfiles);
	}

	public static void beforeStaffProfileUpdate(Map<Id, Staff_Profile__c> oldStaffProfiles, List<Staff_Profile__c> newStaffProfiles) {
		validateUserIds(newStaffProfiles);
	}

	public static void afterStaffProfileInsert(List<Staff_Profile__c> newStaffProfiles) {
		validateSingleStaffProfilePerUser(null, newStaffProfiles);

		// This is done in an after trigger because we need access to
		// `Region_ID__r.Skedulo_Region_ID__c`, which must be queried for, and
		// we can only query for it once the staff profiles have been inserted.
		// Alternatively, we could query for the Region object separately, but
		// that process can become unwieldy if we need to do more of that.
		insertSkeduloResources(newStaffProfiles);
	}

	public static void afterStaffProfileUpdate(Map<Id, Staff_Profile__c> oldStaffProfiles, List<Staff_Profile__c> newStaffProfiles) {
		validateSingleStaffProfilePerUser(oldStaffProfiles, newStaffProfiles);

		// This is done in an after trigger because we need access to
		// `Region_ID__r.Skedulo_Region_ID__c`, which must be queried for, and
		// we can only query for it once the staff profiles have been inserted.
		// Alternatively, we could query for the Region object separately, but
		// that process can become unwieldy if we need to do more of that.
		updateSkeduloResources(newStaffProfiles);
	}

	public static void afterStaffProfileDelete(List<Staff_Profile__c> oldStaffProfiles) {
		deleteSkeduloResources(oldStaffProfiles);
	}

	public static void beforeStaffProfileAttributeInsert(List<Staff_Profile_Attribute__c> newAttributes) {
		validateStaffProfileAttributes(newAttributes);
		insertSkeduloTags(newAttributes);
	}

	public static void beforeStaffProfileAttributeUpdate(Map<Id, Staff_Profile_Attribute__c> oldAttributeMap, List<Staff_Profile_Attribute__c> newAttributes) {
		validateStaffProfileAttributes(newAttributes);
		updateSkeduloTags(newAttributes);
	}

	static void validateStaffProfileAttributes(List<Staff_Profile_Attribute__c> newAttributes) {
		ShiftUtil.validateRequiredField(newAttributes, Schema.Staff_Profile_Attribute__c.Type__c);
	}

	public static void afterStaffProfileAttributeUpdate(Map<Id, Staff_Profile_Attribute__c> oldAttributeMap, List<Staff_Profile_Attribute__c> newAttributes) {
		insertSkeduloResourceTagsForNewSkeduloTags(oldAttributeMap, newAttributes);
	}

	public static void afterStaffProfileAttributeDelete(List<Staff_Profile_Attribute__c> oldAttributes) {
		deleteSkeduloTags(oldAttributes);
	}

	static void setAttributeAssociationKey(List<Staff_Profile_Attribute_Association__c> newAssociations) {
		for (Staff_Profile_Attribute_Association__c association : newAssociations) {
			association.Shift_UQ_Profile_ID_Attribute_ID__c = association.Staff_Profile_ID__c + ':' + association.Staff_Profile_Attribute_ID__c;
		}
	}

	public static void beforeStaffProfileAttributeAssociationInsert(List<Staff_Profile_Attribute_Association__c> newAssociations) {
		setAttributeAssociationKey(newAssociations);
	}

	public static void beforeStaffProfileAttributeAssociationUpdate(Map<Id, Staff_Profile_Attribute_Association__c> oldAssociationMap, List<Staff_Profile_Attribute_Association__c> newAssociations) {
		setAttributeAssociationKey(newAssociations);
	}


	public static void afterStaffProfileAttributeAssociationInsert(List<Staff_Profile_Attribute_Association__c> newAssociations) {
		// This is done in an after trigger because we need access to
		// `Staff_Profile_ID__r.Skedulo_Resource_ID__c` and
		// `Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c`, which must
		// be queried for, and we can only query for them once the staff
		// profiles have been inserted.
		// Alternatively, we could query for the Skedulo objects separately,
		// but that process can become unwieldy if we need to do more of that.
		insertSkeduloResourceTags(newAssociations);
	}

	public static void afterStaffProfileAttributeAssociationUpdate(Map<Id, Staff_Profile_Attribute_Association__c> oldAssociationMap, List<Staff_Profile_Attribute_Association__c> newAssociations) {
		// This is done in an after trigger because we need access to
		// `Staff_Profile_ID__r.Skedulo_Resource_ID__c` and
		// `Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c`, which must
		// be queried for, and we can only query for them once the staff
		// profiles have been inserted.
		// Alternatively, we could query for the Skedulo objects separately,
		// but that process can become unwieldy if we need to do more of that.
		updateSkeduloResourceTags(newAssociations);
	}

	public static void afterStaffProfileAttributeAssociationDelete(List<Staff_Profile_Attribute_Association__c> oldAssociations) {
		deleteSkeduloResourceTags(oldAssociations);
	}
}