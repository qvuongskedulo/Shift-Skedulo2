@isTest
public class skedBookingGrid_Test {

    static testmethod void testBookingForEvaluation() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /************************Test booking for evaluation****************************/
        Evaluation__c evaluation1 = (Evaluation__c)(mapTestData.get('evaluation1'));
        evaluation1.Pickup_Probability__c = '100%';
        evaluation1.Geolocation__Latitude__s = NULL;
        evaluation1.Geolocation__Longitude__s = NULL;
        update evaluation1;

        System.currentPageReference().getParameters().put('id', evaluation1.Id);
        System.currentPageReference().getParameters().put('type', 'evaluation');
        skedBookingGridController bookingGridCon = new skedBookingGridController();
        bookingGridCon.Cmd_UpdateGeoLocationToRootRecord();

        //go to the next date, change the job type to which has drivers assist and turn on the drivers assist
        string newDate = DateTime.newInstance(bookingGridCon.Model.SelectedDate.addDays(1), Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
        System.currentPageReference().getParameters().put('selectedDate', newDate);
        bookingGridCon.Cmd_SelectedDateChanged();

        System.currentPageReference().getParameters().put('selectedJobType', 'Outbound Evaluation Only');
        bookingGridCon.Cmd_JobTypeChanged();

        bookingGridCon.Cmd_LocationAddressChanged();

        List<skedBookingGridUtils.SearchResult> driversAssisResults
                = skedBookingGridController.GetDriversAssist(bookingGridCon.Model.TimezoneSidId, bookingGridCon.Model.SubRegionId, newDate, 660, bookingGridCon.Model.Duration);

        System.currentPageReference().getParameters().put('resourceId', skedResource1.Id);
        System.currentPageReference().getParameters().put('startTime', '660');
        System.currentPageReference().getParameters().put('driverAssistId', skedResource1.Id);
        bookingGridCon.Cmd_SaveBooking();

        Test.stopTest();
    }

    static testmethod void testBookingForEvaluation2() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /************************Test booking for evaluation****************************/
        Evaluation__c evaluation1 = (Evaluation__c)(mapTestData.get('evaluation1'));
        evaluation1.Pickup_Probability__c = '100%';
        evaluation1.Geolocation__Latitude__s = NULL;
        evaluation1.Geolocation__Longitude__s = NULL;
        update evaluation1;

        System.currentPageReference().getParameters().put('id', evaluation1.Id);
        System.currentPageReference().getParameters().put('type', 'evaluation');
        System.currentPageReference().getParameters().put('mode', 'reschedule');
        skedBookingGridController bookingGridCon = new skedBookingGridController();

        evaluation1.Canceled__c = true;
        evaluation1.Inside_Sales_Calendar_Notes__c = 'notes';
        update evaluation1;

        Test.stopTest();
    }

    static testmethod void testBookingForTestDrive() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /*************************Test booking for test drive**************************/
        Test_Drive__c testDrive1 = (Test_Drive__c)(mapTestData.get('testDrive1'));

        System.currentPageReference().getParameters().put('id', testDrive1.Id);
        System.currentPageReference().getParameters().put('type', 'testdrive');
        skedBookingGridController bookingGridCon = new skedBookingGridController();

        System.currentPageReference().getParameters().put('resourceId', skedResource1.Id);
        System.currentPageReference().getParameters().put('startTime', '660');
        System.currentPageReference().getParameters().put('driverAssistId', skedResource1.Id);
        bookingGridCon.Cmd_SaveBooking();

        List<string> timeAxis = bookingGridCon.Model.TimeAxisList;
        boolean driversAssistVisibility = bookingGridCon.Model.DriversAssistVisibility;

        /*
        testDrive1.Canceled__c = true;
        testDrive1.Customer_Experience_Calendar_Notes__c = 'notes';
        update testDrive1;
        */

        Test.stopTest();
    }

    static testmethod void testBookingForTestDriveWithAssist() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /*************************Test booking for test drive**************************/
        Test_Drive__c testDrive1 = (Test_Drive__c)(mapTestData.get('testDrive1'));

        System.currentPageReference().getParameters().put('id', testDrive1.Id);
        System.currentPageReference().getParameters().put('type', 'testdrive');
        skedBookingGridController bookingGridCon = new skedBookingGridController();

        bookingGridCon.Model.DriversAssist = true;
        bookingGridCon.Cmd_DriversAssistChanged();

        System.currentPageReference().getParameters().put('jobStartTime', '600');
        System.currentPageReference().getParameters().put('bookedResourceId', skedResource1.Id);
        bookingGridCon.Cmd_LoadDriversAssist();

        System.currentPageReference().getParameters().put('resourceId', skedResource1.Id);
        System.currentPageReference().getParameters().put('startTime', '660');
        System.currentPageReference().getParameters().put('driverAssistId', skedResource1.Id);
        bookingGridCon.Cmd_SaveBooking();

        Test.stopTest();
    }

    static testmethod void testBookingForDelivery() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /*************************Test booking for delivery**************************/
        Delivery__c delivery1 = (Delivery__c)(mapTestData.get('delivery1'));

        System.currentPageReference().getParameters().put('id', delivery1.Id);
        System.currentPageReference().getParameters().put('type', 'delivery');
        skedBookingGridController bookingGridCon = new skedBookingGridController();

        bookingGridCon.Cmd_RegionChanged();

        System.currentPageReference().getParameters().put('resourceId', skedResource1.Id);
        System.currentPageReference().getParameters().put('startTime', '660');
        System.currentPageReference().getParameters().put('driverAssistId', skedResource1.Id);
        bookingGridCon.Cmd_SaveBooking();

        delivery1.Canceled__c = true;
        delivery1.Notes__c = 'notes';
        update delivery1;
    }

    static testmethod void testBookingForPickup() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /*************************Test booking for delivery**************************/
        Pick_Up__c pickup1 = (Pick_Up__c)(mapTestData.get('pickup1'));

        System.currentPageReference().getParameters().put('id', pickup1.Id);
        System.currentPageReference().getParameters().put('type', 'pickup');
        skedBookingGridController bookingGridCon = new skedBookingGridController();

        System.currentPageReference().getParameters().put('duration', '30');
        bookingGridCon.Cmd_DurationChanged();

        System.currentPageReference().getParameters().put('resourceId', skedResource1.Id);
        System.currentPageReference().getParameters().put('startTime', '660');
        System.currentPageReference().getParameters().put('driverAssistId', skedResource1.Id);
        bookingGridCon.Cmd_SaveBooking();

        pickup1.Canceled__c = TRUE;
        pickup1.Notes__c = 'notes';
        update pickup1;
    }

    static testmethod void testBookingForPickupBackflow() {
        Map<string, sObject> mapTestData = skedTestUtils.SetupTestData();

        sked__Resource__c skedResource1 = (sked__Resource__c)(mapTestData.get('skedResource1'));

        Test.setCurrentPageReference(new PageReference('skedBookingGrid'));

        Test.startTest();

        /*************************Test booking for delivery**************************/
        Pick_Up__c pickup2 = (Pick_Up__c)(mapTestData.get('pickup2'));

        System.currentPageReference().getParameters().put('id', pickup2.Id);
        System.currentPageReference().getParameters().put('type', 'pickup');
        skedBookingGridController bookingGridCon = new skedBookingGridController();

        System.currentPageReference().getParameters().put('resourceId', skedResource1.Id);
        System.currentPageReference().getParameters().put('startTime', '660');
        System.currentPageReference().getParameters().put('driverAssistId', skedResource1.Id);
        bookingGridCon.Cmd_SaveBooking();
    }
}