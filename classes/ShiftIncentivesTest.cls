@IsTest
public class ShiftIncentivesTest {
  @IsTest static void testValidateIncentives() {
    Incentive_Program__c program1 = ShiftTesting.createIncentiveProgram();
    Incentive_Program__c program2 = ShiftTesting.createIncentiveProgram();
    insert new List<Incentive_Program__c>{program1, program2};

    Incentive__c incentive = ShiftTesting.createIncentive('token', program1.Id);
    insert incentive;

    incentive.Token__c = 'newToken';
    ShiftTesting.expectUpdateExceptionContains(incentive, String.escapeSingleQuotes('Attempt to change Token__c from token to newToken'));
    incentive.Token__c = 'token';

    incentive.Incentive_Program_ID__c = program2.Id;
    ShiftTesting.expectUpdateExceptionContains(incentive, 'Attempt to change Incentive_Program_ID__c from ' + program1.Id + ' to ' + program2.Id);
    incentive.Incentive_Program_ID__c = program1.Id;

    // Test succcessful visits increment.
    incentive.Visits__c = 1;
    update incentive;
    incentive.Visits__c = 2;
    update incentive;

    incentive.Visits__c = 1;
    ShiftTesting.expectUpdateExceptionContains(incentive, 'Attempt to decrement number of incentive visits from 2 to 1');
  }

  static Task getTaskOnContact(Id id) {
    return [SELECT Id, Subject, Description, Team__c FROM Task WHERE WhoId = :id LIMIT 1];
  }

  static Contact getContactForOpportunity(Id opportunityId) {
    return [SELECT Id, Email, FirstName, Incentive_Token__c FROM Contact WHERE AccountId IN (SELECT AccountId FROM Opportunity WHERE Id = :opportunityId) LIMIT 1];
  }

  static Contact getContactById(Id contactId) {
    return [SELECT Id, Email, FirstName, Incentive_Token__c FROM Contact WHERE Id = :contactId];
  }

  @IsTest static void testProcessIncentives() {
    ShiftTesting.setup();
    ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
    ctx.opportunity.Marketing_Cost__c = 100;
    ctx.insertOpportunity();
    Test.startTest();
    Incentive_Program__c program = ShiftTesting.createIncentiveProgram();
    insert program;
    Contact referrer1 = ShiftTesting.createContactWithRandomEmail();
    Contact referrer2 = ShiftTesting.createContactWithRandomEmail();
    insert new List<Contact>{referrer1, referrer2};
    
    Incentive__c sellerIncentive = ShiftTesting.createIncentive('sellerToken', program.Id, referrer1.Email);
    Incentive__c buyerIncentive = ShiftTesting.createIncentive('buyerToken', program.Id, referrer2.Email);
    insert new List<Incentive__c>{sellerIncentive, buyerIncentive};

    referrer1.Incentive_ID__c = sellerIncentive.Id;
    referrer2.Incentive_ID__c = buyerIncentive.Id;
    update new List<Contact>{referrer1, referrer2};

    ShiftTesting.prepareVehicleForHandover(ctx.vehicle);
    Vehicle_Order__c vo = [SELECT Id, Buyer_Opportunity_ID__c FROM Vehicle_Order__c WHERE Vehicle_ID__c = :ctx.vehicle.Id];
    Applied_Incentive__c appliedIncentive1 = ShiftTesting.createAppliedIncentive(ctx.opportunity.Id, sellerIncentive.Id);
    Applied_Incentive__c appliedIncentive2 = ShiftTesting.createAppliedIncentive(vo.Buyer_Opportunity_ID__c, buyerIncentive.Id);
    insert new List<Applied_Incentive__c>{appliedIncentive1, appliedIncentive2};

    ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD;
    update ctx.opportunity;
    Test.stopTest();

    Contact seller = getContactForOpportunity(ctx.opportunity.Id);
    Contact buyer = getContactForOpportunity(vo.Buyer_Opportunity_ID__c);
    referrer1 = getContactById(referrer1.Id);
    referrer2 = getContactById(referrer2.Id);
    ShiftTesting.TaskExpector sellerReferrerTask = new ShiftTesting.TaskExpector(getTaskOnContact(referrer1.Id));
    ShiftTesting.TaskExpector sellerRefereeTask = new ShiftTesting.TaskExpector(getTaskOnContact(seller.Id));
    ShiftTesting.TaskExpector buyerReferrerTask = new ShiftTesting.TaskExpector(getTaskOnContact(referrer2.Id));
    ShiftTesting.TaskExpector buyerRefereeTask = new ShiftTesting.TaskExpector(getTaskOnContact(buyer.Id));

    List<ShiftTesting.TaskExpector> expectors = new List<ShiftTesting.TaskExpector>{sellerReferrerTask, sellerRefereeTask, buyerReferrerTask, buyerRefereeTask};

    for (ShiftTesting.TaskExpector e : expectors) {
        e.expectTeam(ShiftConstants.TASK_TEAM_USER_HAPPINESS);
    }

    sellerReferrerTask.expectSubject('Pay referrer bonus');
    sellerRefereeTask.expectSubject('Pay referee bonus');
    buyerReferrerTask.expectSubject('Pay referrer bonus');
    buyerRefereeTask.expectSubject('Pay referee bonus');

    String sellerReferrerDescription = 'Pay $' + program.Referrer_Payout__c + ' to ' + referrer1.Email +
        '\n\nPayout Method: ' + program.Referrer_Payout_Method__c +
        '\nE-mail type: Referrer' +
        '\nReferee name: ' + seller.FirstName +
        '\nSale type: seller' +
        '\nIncentive token: ' + referrer1.Incentive_Token__c;
    String buyerReferrerDescription = 'Pay $' + program.Referrer_Payout__c + ' to ' + referrer2.Email +
        '\n\nPayout Method: ' + program.Referrer_Payout_Method__c +
        '\nE-mail type: Referrer' +
        '\nReferee name: ' + buyer.FirstName +
        '\nSale type: buyer' +
        '\nIncentive token: ' + referrer2.Incentive_Token__c;
    String sellerRefereeDescription = 'Pay $' + program.Payout__c + ' to ' + seller.Email +
        '\n\nPayout Method: ' + program.Payout_Method__c +
        '\nE-mail type: Was referred' +
        '\nReferrer name: ' + referrer1.FirstName +
        '\nSale type: seller' +
        '\nIncentive token: ' + seller.Incentive_Token__c;
    String buyerRefereeDescription = 'Pay $' + program.Payout__c + ' to ' + buyer.Email +
        '\n\nPayout Method: ' + program.Payout_Method__c +
        '\nE-mail type: Was referred' +
        '\nReferrer name: ' + referrer2.FirstName +
        '\nSale type: buyer' +
        '\nIncentive token: ' + buyer.Incentive_Token__c;

    sellerReferrerTask.expectDescription(sellerReferrerDescription);
    sellerRefereeTask.expectDescription(sellerRefereeDescription);
    buyerReferrerTask.expectDescription(buyerReferrerDescription);
    buyerRefereeTask.expectDescription(buyerRefereeDescription);

    Opportunity buyerOpportunity = [SELECT Marketing_Cost__c FROM Opportunity WHERE Id = :vo.Buyer_Opportunity_ID__c];
    Opportunity sellerOpportunity = [SELECT Marketing_Cost__c FROM Opportunity WHERE Id = :ctx.opportunity.Id];
    System.assertEquals(200.00, buyerOpportunity.Marketing_Cost__c);
    System.assertEquals(300.00, sellerOpportunity.Marketing_Cost__c);
  }
}