@isTest class ShiftVehicleDetailControllerTest {
	@testSetup static void setup() { ShiftTesting.setup(); }

	@isTest static void testController() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.createAndInsertSeller();
		Test.setCurrentPage(Page.ShiftVehicleDetail);
		ApexPages.currentPage().getParameters().put('id', ctx.vehicle.Id);
		ShiftVehicleDetailController det = new ShiftVehicleDetailController();
		System.assertEquals(ctx.vehicle.Id, det.vehicle.Id);
		System.assertEquals(ctx.opportunity.Id, det.sellerOpportunity.Id);
		System.assertEquals(0, det.vehicleOrdersSize);
	}
}