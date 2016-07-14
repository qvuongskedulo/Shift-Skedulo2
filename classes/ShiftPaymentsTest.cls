@IsTest
class ShiftPaymentsTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	@IsTest
	static void testCalculateAdvanceFundsFee() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Advance_Funds_Amount__c = 1000.0;
		o.LeadSource = ShiftConstants.LEAD_SOURCE_TESLA_REMARKETING;
		System.assertEquals(0.0, ShiftPayments.calculateAdvanceFundsFee(o));

		o.LeadSource = ShiftConstants.LEAD_SOURCE_WORD_OF_MOUTH;
		o.Advance_Funds_Fee_Override__c = null;
		System.assertEquals(ShiftConstants.ADVANCE_FUNDS_FEE, ShiftPayments.calculateAdvanceFundsFee(o));

		o.Advance_Funds_Fee_Override__c = 500.0;
		System.assertEquals(o.Advance_Funds_Fee_Override__c, ShiftPayments.calculateAdvanceFundsFee(o));
	}


	@IsTest
	static void testCalculateLatePaperWorkFee() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		Vehicle__c v = ShiftTesting.createVehicle();
		o.Entered_Stage_Sold__c = null;
		v.Paperwork_Fee_Pending__c = 100.0;
		System.assertEquals(0.0, ShiftPayments.calculateLatePaperWorkFee(o, v, null));

		o.Entered_Stage_Sold__c = null;
		System.assertEquals(0.0, ShiftPayments.calculateLatePaperWorkFee(o, v, Date.today().addDays(-20)));

		o.Entered_Stage_Sold__c = Date.today().addDays(-5);
		System.assertEquals(0.0, ShiftPayments.calculateLatePaperWorkFee(o, v, Date.today().addDays(-20)));

		o.Entered_Stage_Sold__c = Date.today().addDays(-5);
		System.assertEquals(v.Paperwork_Fee_Pending__c, ShiftPayments.calculateLatePaperWorkFee(o, v, Date.today().addDays(-50)));

		o.Entered_Stage_Sold__c = null;
		System.assertEquals(v.Paperwork_Fee_Pending__c, ShiftPayments.calculateLatePaperWorkFee(o, v, Date.today().addDays(-50)));
	}

	@IsTest
	static void testCalculatePickupFeeRevenue() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Opportunity o = ctx.opportunity;
		o.Guaranteed_Price__c = 10000.0;
		o.Pickup_Fee__c = 100.0;
		o.Final_Guaranteed_Price_2__c = ShiftPayments.calculateFinalGuaranteedPrice(o);
		o.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_STANDARD;
		o.Seller_Upside_Percentage__c = 50;

		System.assertEquals(50.0, ShiftPayments.calculatePickupFeeRevenue(o, 12000.0));

		o.Seller_Upside_Percentage__c = 20;
		System.assertEquals(80.0, ShiftPayments.calculatePickupFeeRevenue(o, 12000.0));

		o.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT;
		System.assertEquals(100.0, ShiftPayments.calculatePickupFeeRevenue(o, 12000.0));
	}

	@IsTest
	static void testCalculateAdvanceFundsNet() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Advance_Funds_Amount__c = null;
		o.Seller_Costs_DMV__c = 0.0;
		o.Advance_Funds_Fee_2__c = 0.0;
		o.Late_Paperwork_Fee_2__c = 0.0;
		o.Seller_Costs_Repairs_Estimate__c = 0.0;
		o.Payoff_Amount__c = 0.0;
		System.assertEquals(0.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Advance_Funds_Amount__c = 0.0;
		System.assertEquals(0.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Advance_Funds_Amount__c = 5000.0;
		o.Seller_Costs_DMV__c = 500.0;
		System.assertEquals(4500.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Advance_Funds_Fee_2__c = 500.0;
		System.assertEquals(4000.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Late_Paperwork_Fee_2__c = 500.0;
		System.assertEquals(3500.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Seller_Costs_Repairs__c = 500.0;
		System.assertEquals(3000.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Seller_Costs_Repairs__c = null;
		o.Seller_Costs_Repairs_Estimate__c = 500.0;
		System.assertEquals(3000.0, ShiftPayments.calculateAdvanceFundsNet(o));

		o.Payoff_Amount__c = 1000.0;
		System.assertEquals(2000.0, ShiftPayments.calculateAdvanceFundsNet(o));
	}


	@IsTest
	static void testCalculateSellerRepairCosts() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Seller_Costs_Repairs__c = null;
		o.Seller_Costs_Repairs_Estimate__c = 500.0;
		System.assertEquals(500.0, ShiftPayments.calculateSellerRepairCosts(o));

		o.Seller_Costs_Repairs__c = 1000.0;
		System.assertEquals(1000.0, ShiftPayments.calculateSellerRepairCosts(o));
	}

	@IsTest
	static void testCalculateReferralPayout() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Referral_Program_Or_Promotion__c = ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_ANYPERK;
		System.assertEquals(300.0, ShiftPayments.calculateReferralPayout(o));

		o.Referral_Program_Or_Promotion__c = ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_GOOGLE;
		System.assertEquals(200.0, ShiftPayments.calculateReferralPayout(o));
	}

	@IsTest
	static void testCalculateSellerPaymentGross() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Seller_Upside_Percentage__c = 50;
		o.Final_Guaranteed_Price_2__c = 10000.0;

		System.assertEquals(15000.0, ShiftPayments.calculateSellerPaymentGross(o, 20000.0));
		System.assertEquals(10000.0, ShiftPayments.calculateSellerPaymentGross(o, 9000.0));

		o.Seller_Upside_Percentage__c = 60;
		System.assertEquals(16000.0, ShiftPayments.calculateSellerPaymentGross(o, 20000.0));
	}

	@IsTest
	static void testCalculateSellerPaymentNet() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Seller_Payment_Gross_2__c = 16000.0;
		o.Seller_Costs_DMV__c = 0.0;
		o.Seller_Costs_Repairs__c = 0.0;
		o.Late_Paperwork_Fee_2__c = 0.0;
		o.Payoff_Amount__c = 0.0;
		o.Trade_In_Credit_Amount__c = 0.0;
		o.Referral_Payout__c = 0.0;
		o.Advance_Funds_Amount__c = 0.0;
		o.Flat_Fee__c = 0.0;
		o.Direct_To_Wholesale__c = false;
		o.Was_Paid_On_Contract_Expiration__c = false;
		o.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_STANDARD;

		System.assertEquals(16000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Seller_Costs_DMV__c = 1000.0;
		System.assertEquals(15000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Seller_Costs_Repairs__c = 500.0;
		System.assertEquals(14500.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Late_Paperwork_Fee_2__c = 500.0;
		System.assertEquals(14000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Payoff_Amount__c = 5000.0;
		System.assertEquals(9000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Referral_Payout__c = 500.0;
		System.assertEquals(9500.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Flat_Fee__c = 2000.0;
		o.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT;
		System.assertEquals(7500.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Final_Guaranteed_Price_2__c = 10000.0;
		o.Was_Paid_On_Contract_Expiration__c = true;
		System.assertEquals(6000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Direct_To_Wholesale__c = true;
		System.assertEquals(5000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Advance_Funds_Amount__c = 3000.0;
		o.Advance_Funds_Type__c = ShiftConstants.ADVANCE_FUNDS_TYPE_FULL;
		System.assertEquals(13000.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Advance_Funds_Type__c = ShiftConstants.ADVANCE_FUNDS_TYPE_LIENHOLDER_ONLY;
		o.Trade_In_Credit_Amount__c = 2000.0;
		System.assertEquals(7500.0, ShiftPayments.calculateSellerPaymentNet(o));

		o.Trade_In_Status__c = ShiftConstants.TRADE_IN_STATUS_FUNDED;
		o.Trade_In_Credit_Amount__c = 15000.0;
		System.assertEquals(1000.0, ShiftPayments.calculateSellerPaymentNet(o));
	}

	@IsTest
	static void testCalculateCarCommission() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Seller_Upside_Percentage__c = 50;
		o.Guaranteed_Price__c = 10000.0;
		o.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_STANDARD;
		System.assertEquals(5000.0, ShiftPayments.calculateCarCommission(o, 20000.0));

		o.Seller_Upside_Percentage__c = 90;
		System.assertEquals(1000.0, ShiftPayments.calculateCarCommission(o, 20000.0));

		o.Flat_Fee__c = 500.0;
		o.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT;
		System.assertEquals(500.0, ShiftPayments.calculateCarCommission(o, 20000.0));
	}


	@IsTest
	static void testCalculateTotalRevenue() {
		Opportunity o = ShiftTesting.createSellerOpportunity();
		o.Car_Commission__c = 1000.0;
		o.Late_Paperwork_Fee_2__c = 100.0;
		o.Advance_Funds_Fee_2__c = 100.0;
		o.Pickup_Fee_Revenue__c = 800.0;

		System.assertEquals(2000.0, ShiftPayments.calculateTotalRevenue(o));
	}
}