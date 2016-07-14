@IsTest
class ShiftRegionTriggersTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static void expectSkeduloRegionSynced(Id regionId) {
		Region__c region = [
			SELECT
				Name,
				Timezone__c,
				Skedulo_Region_ID__r.Id,
				Skedulo_Region_ID__r.Name,
				Skedulo_Region_ID__r.sked__Timezone__c
			FROM Region__c
			WHERE Id = :regionId
		];
		System.assertEquals(region.Name, region.Skedulo_Region_ID__r.Name);
		System.assertEquals(region.Timezone__c, region.Skedulo_Region_ID__r.sked__Timezone__c);
	}

	@IsTest
	static void testSyncSkeduloRegion() {
		Region__c r = new Region__c(
			Name = ShiftUtil.randomStringLowercaseAlphanum(8),
			Shift_Key__c = ShiftUtil.randomStringLowercaseAlphanum(8),
			Timezone__c = ShiftTesting.REGION_TIMEZONE_TESTING
		);
		insert r;
		expectSkeduloRegionSynced(r.Id);

		r.Timezone__c = ShiftTesting.REGION_TIMEZONE_TESTING + '/2';
		update r;
		expectSkeduloRegionSynced(r.Id);

		delete r;
		System.assertEquals(0, [SELECT COUNT() FROM sked__Region__c WHERE Name = :r.Name]);
	}
}