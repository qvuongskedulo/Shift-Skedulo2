@isTest class ShiftCaseControllerExtensionTest {
	@testSetup static void setup() { ShiftTesting.setup(); }

	@isTest static void testController() {
		Case caseRecord = new Case(status='New');

		insert caseRecord;

		// Extends the standard controller, this is done declaratively in the VisualForce page
		ShiftCaseControllerExtension caseController = new ShiftCaseControllerExtension(new ApexPages.StandardController(caseRecord));

		// There's a VisualForce page (ShiftCloseCase) that calls this action when it is loaded
		PageReference redirectPageReference = caseController.closeAndRedirect();

		caseRecord = [SELECT id, status FROM Case WHERE Id = :caseRecord.id];

		// The method should close the case
		System.assertEquals('Closed', caseRecord.status);

		// The method should redirect back to the case detail page
		String expectedURL = new ApexPages.StandardController(caseRecord).view().getUrl();
		String actualURL = redirectPageReference.getUrl();
		System.assert(expectedURL.equals(actualURL));
	}
}