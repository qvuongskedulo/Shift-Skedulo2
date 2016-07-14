// The parent class for all Shift exceptions (which all extend ShiftException).
public class ShiftPayments {
	private static Date ADVANCE_FUNDS_FEE_START_DATE = Date.newInstance(2016, 4, 30);

	private static Set<String> CALCULATED_PRICING_STRATEGIES = new Set<String> {
			ShiftConstants.PRICING_STRATEGY_STANDARD,
			ShiftConstants.PRICING_STRATEGY_SINGLE_PRICE_0_UPSIDE,
			ShiftConstants.PRICING_STRATEGY_SPECIFIC_CAR_SEARCH,
			ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT,
			ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT,
			''
	};

	// To get around the issue that some fields can have null values, certain fields are validated and
	// set to 0.0 to support later calculations, clone original object and return new normalized object
	@TestVisible
	static Opportunity normalizeFinancialFields(Opportunity base) {
		Opportunity o = base.clone(false, true);
		o.Covered_Repair_Cost__c = ShiftUtil.nonNullDecimal(o.Covered_Repair_Cost__c);
		o.Flat_Fee__c = ShiftUtil.nonNullDecimal(o.Flat_Fee__c);
		o.Payoff_Amount__c = ShiftUtil.nonNullDecimal(o.Payoff_Amount__c);
		o.Pickup_Fee__c = ShiftUtil.nonNullDecimal(o.Pickup_Fee__c);
		o.Seller_Costs_Repairs__c = ShiftUtil.nonNullDecimal(o.Seller_Costs_Repairs__c);
		o.Seller_Costs_DMV__c = ShiftUtil.nonNullDecimal(o.Seller_Costs_DMV__c);
		o.Shift_Costs_Repairs__c = ShiftUtil.nonNullDecimal(o.Shift_Costs_Repairs__c);
		o.Covered_Repair_Cost__c = ShiftUtil.nonNullDecimal(o.Covered_Repair_Cost__c);
		o.Trade_In_Credit_Amount__c = ShiftUtil.nonNullDecimal(o.Trade_In_Credit_Amount__c);
		o.Seller_Upside_Percentage__c = ShiftUtil.nonNullDecimal(o.Seller_Upside_Percentage__c);
		return o;
	}

	public static void calculateSellerOpportunityFinancials(Opportunity o, Vehicle__c cv) {
		Opportunity co = normalizeFinancialFields(o);

		// Cross object formula fields are passed directly as parameters to faciliate testing
		// After the calculation is done on the cloned object copy the value over to the orignal
		// object
		co.Late_Paperwork_Fee_2__c = calculateLatePaperWorkFee(co, cv, co.Seller_Contract_Signed_On__c);
		o.Late_Paperwork_Fee_2__c = co.Late_Paperwork_Fee_2__c;
		co.Advance_Funds_Fee_2__c = calculateAdvanceFundsFee(co);
		o.Advance_Funds_Fee_2__c = co.Advance_Funds_Fee_2__c;
		co.Advance_Funds_Net_2__c = calculateAdvanceFundsNet(co);
		o.Advance_Funds_Net_2__c = co.Advance_Funds_Net_2__c;
		co.Referral_Payout__c = calculateReferralPayout(co);
		o.Referral_Payout__c = co.Referral_Payout__c;

		if (co.Guaranteed_Price__c != null) {
			co.Final_Guaranteed_Price_2__c = calculateFinalGuaranteedPrice(co);
			o.Final_Guaranteed_Price_2__c = co.Final_Guaranteed_Price_2__c;
		}

		if (co.List_Price__c != null && co.Guaranteed_Price__c != null) {
			co.Projected_Car_Commission__c = calculateCarCommission(co, co.List_Price__c);
			o.Projected_Car_Commission__c = co.Projected_Car_Commission__c;
		}

		if (co.Final_Sale_Price__c != null && co.Guaranteed_Price__c != null) {
			co.Pickup_Fee_Revenue__c = calculatePickupFeeRevenue(co, co.Final_Sale_Price__c);
			o.Pickup_Fee_Revenue__c = co.Pickup_Fee_Revenue__c;
			co.Seller_Payment_Gross_2__c = calculateSellerPaymentGross(co, co.Final_Sale_Price__c);
			o.Seller_Payment_Gross_2__c = co.Seller_Payment_Gross_2__c;
			co.Seller_Payment_Net_2__c = calculateSellerPaymentNet(co);
			o.Seller_Payment_Net_2__c = co.Seller_Payment_Net_2__c;
			co.Car_Commission__c = calculateCarCommission(co, co.Final_Sale_Price__c);
			o.Car_Commission__c = co.Car_Commission__c;
			co.Total_Revenue__c = calculateTotalRevenue(co);
			o.Total_Revenue__c = co.Total_Revenue__c;
			co.Total_Shift_Costs__c = calculateTotalShiftCosts(co);
			o.Total_Shift_Costs__c = co.Total_Shift_Costs__c;
			co.Revenue_Net_2__c = calculateRevenueNet(co);
			o.Revenue_Net_2__c = co.Revenue_Net_2__c;
		}
	}

	//Advance_Funds_Fee_2
	@TestVisible
	static Decimal calculateAdvanceFundsFee(Opportunity o) {
		Decimal finalAmount = 0.0;
		if(o.Advance_Funds_Amount__c != null && o.Advance_Funds_Amount__c != 0.0) {
			if (o.Advance_Funds_Fee_Override__c != null) {
				return o.Advance_Funds_Fee_Override__c;
			}
			if (Date.today() > ADVANCE_FUNDS_FEE_START_DATE && o.LeadSource != ShiftConstants.LEAD_SOURCE_TESLA_REMARKETING) {
				finalAmount = ShiftConstants.ADVANCE_FUNDS_FEE;
			}
		}
		return finalAmount;
	}

	//Late_Paperwork_Fee_2
	@TestVisible
	static Decimal calculateLatePaperWorkFee(Opportunity o, Vehicle__c v, Date dateSigned) {
		Decimal finalAmount = 0.0;
		if (o.Late_Paperwork_Fee_Override__c != null) {
			return o.Late_Paperwork_Fee_Override__c;
		}
		if (v != null) {
			if (o.Entered_Stage_Sold__c != null && dateSigned != null && o.Entered_Stage_Sold__c > dateSigned.addDays(30)) {
				finalAmount = ShiftUtil.nonNullDecimal(v.Paperwork_Fee_Pending__c);
			} else if (dateSigned != null && DateTime.now() > dateSigned.addDays(30)) {
				finalAmount = ShiftUtil.nonNullDecimal(v.Paperwork_Fee_Pending__c);
			}
		}
		return finalAmount;
	}

	//Pickup_Fee_Revenue
	@TestVisible
	static Decimal calculatePickupFeeRevenue(Opportunity o, Decimal finalSalePrice) {
		String pStrategy = o.Pricing_Strategy__c;
		Decimal maxCommission = finalSalePrice - o.Final_Guaranteed_Price_2__c;
		Decimal finalAmount = 0.0;
		if (maxCommission > o.Pickup_Fee__c) {
			if (pStrategy == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT) {
				finalAmount = o.Pickup_Fee__c;
			} else if (pStrategy == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT) {
				finalAmount = o.Pickup_Fee__c;
			} else {
				finalAmount = o.Pickup_Fee__c * ((100 - o.Seller_Upside_Percentage__c) / 100);
			}
		}
		return finalAmount;
	}

	//Advance_Funds_Net_2
	@TestVisible
	static Decimal calculateAdvanceFundsNet(Opportunity o) {
		Decimal finalAmount = 0.0;
		if (o.Advance_Funds_Amount__c != null && o.Advance_Funds_Amount__c != 0.0) {
			finalAmount = o.Advance_Funds_Amount__c - o.Seller_Costs_DMV__c - o.Payoff_Amount__c - calculateSellerRepairCosts(o) - o.Advance_Funds_Fee_2__c - o.Late_Paperwork_Fee_2__c;
		}
		return finalAmount;
	}

	//Helper method to calculate seller repair costs
	//TODO Need to change work flow so that we don't have to disambiguate this value
	@TestVisible
	static Decimal calculateSellerRepairCosts(Opportunity o) {
		if (o.Seller_Costs_Repairs__c != null) {
			return o.Seller_Costs_Repairs__c;
		} else {
			return o.Seller_Costs_Repairs_Estimate__c;
		}
	}

	//Referral_Payout
	@TestVisible
	static Decimal calculateReferralPayout(Opportunity o) {
		Decimal finalAmount = 0.0;
		String refProgram = o.Referral_Program_Or_Promotion__c;
		Set<String> tierOnePrograms = new Set<String> {
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_PASSPORT_UNLIMITED_HOT_DEAL,
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_TESLA,
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_ANYPERK
		};
		Set<String> tierTwoPrograms = new Set<String> {
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_GOOGLE,
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_PASSPORT_UNLIMITED,
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_LA_STREET_TEAM,
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_QUALCOMM,
				ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_HIGHLAND_PORTOFLIO
		};
		if (tierOnePrograms.contains(refProgram)) {
			finalAmount = 300.0;
		} else if (tierTwoPrograms.contains(refProgram)) {
			finalAmount = 200.0;
		}
		return finalAmount;
	}


	//Final_Guaranteed_Price_2
	@TestVisible
	static Decimal calculateFinalGuaranteedPrice(Opportunity o) {
		return o.Guaranteed_Price__c - o.Pickup_Fee__c;
	}

	//Seller_Payment_Gross_2
	@TestVisible
	static Decimal calculateSellerPaymentGross(Opportunity o, Decimal finalSalePrice) {
		Decimal finalAmount = 0.0;
		if (finalSalePrice > o.Final_Guaranteed_Price_2__c) {
			finalAmount = o.Final_Guaranteed_Price_2__c + ((finalSalePrice - o.Final_Guaranteed_Price_2__c) * (o.Seller_Upside_Percentage__c / 100));
		} else {
			finalAmount = o.Final_Guaranteed_Price_2__c;
		}
		return finalAmount;
	}

	//Seller_Payment_Net_2
	@TestVisible
	static Decimal calculateSellerPaymentNet(Opportunity o) {
		Decimal finalAmount = 0.0;
		Decimal sellerFees = o.Seller_Costs_DMV__c + calculateSellerRepairCosts(o) + o.Late_Paperwork_Fee_2__c;
		if (o.Trade_In_Status__c == ShiftConstants.TRADE_IN_STATUS_FUNDED) {
			finalAmount = o.Seller_Payment_Gross_2__c - o.Trade_In_Credit_Amount__c;
		} else if (o.Advance_Funds_Amount__c > 0) {
			if (o.Advance_Funds_Type__c == ShiftConstants.ADVANCE_FUNDS_TYPE_LIENHOLDER_ONLY) {
				finalAmount = o.Seller_Payment_Gross_2__c - sellerFees - o.Payoff_Amount__c - o.Trade_In_Credit_Amount__c + o.Referral_Payout__c;
			} else {
				finalAmount = o.Seller_Payment_Gross_2__c - o.Advance_Funds_Amount__c;
			}
		} else if (o.Direct_To_Wholesale__c == true) {
			finalAmount = o.Final_Guaranteed_Price_2__c - o.Payoff_Amount__c - o.Late_Paperwork_Fee_2__c + o.Referral_Payout__c;
		} else if (o.Was_Paid_On_Contract_Expiration__c == true) {
			finalAmount = o.Seller_Payment_Gross_2__c - o.Final_Guaranteed_Price_2__c;
		} else if (o.Pricing_Strategy__c == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT) {
			finalAmount = o.Seller_Payment_Gross_2__c - sellerFees - o.Flat_Fee__c - o.Payoff_Amount__c + o.Referral_Payout__c;
		} else {
			finalAmount = o.Seller_Payment_Gross_2__c - sellerFees - o.Payoff_Amount__c + o.Referral_Payout__c;
		}
		return finalAmount;
	}

	//Car_Commission
	@TestVisible
	static Decimal calculateCarCommission(Opportunity o, Decimal finalSalePrice) {
		String pStrategy = o.Pricing_Strategy__c;
		Decimal maxCommission = Math.max(0.0, finalSalePrice - o.Guaranteed_Price__c);
		Decimal finalAmount = maxCommission;
		if (pStrategy == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT) {
			if (maxCommission > o.Flat_Fee__c) {
				finalAmount = o.Flat_Fee__c;
			}
		} else if (pStrategy == ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT) {
			if (maxCommission > (finalSalePrice * o.Flat_Fee_Percent__c)) {
				finalAmount = finalSalePrice * o.Flat_Fee_Percent__c;
			}
		} else if (maxCommission > 0) {
			finalAmount = (finalSalePrice - o.Guaranteed_Price__c) * ((100 - o.Seller_Upside_Percentage__c) / 100);
		}
		return finalAmount;
	}

	//Total_Revenue
	@TestVisible
	static Decimal calculateTotalRevenue(Opportunity o) {
		return o.Car_Commission__c + o.Late_Paperwork_Fee_2__c + o.Advance_Funds_Fee_2__c + o.Pickup_Fee_Revenue__c;
	}

	//Total Shift Costs
	@TestVisible
	static Decimal calculateTotalShiftCosts(Opportunity o) {
		return o.Shift_Costs_Repairs__c + o.Covered_Repair_Cost__c;
	}

	//Revenue_Net_2
	@TestVisible
	static Decimal calculateRevenueNet(Opportunity o) {
		return o.Total_Revenue__c - o.Total_Shift_Costs__c;
	}
}