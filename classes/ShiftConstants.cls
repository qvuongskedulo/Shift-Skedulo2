// TODO(ohler): generate from data model in salesforce
public class ShiftConstants {
	public static final String OPPORTUNITY_RECORD_TYPE_SELLER = 'Seller';
	public static final String OPPORTUNITY_RECORD_TYPE_BUYER = 'Buyer';

	public static final String SELLER_OPPORTUNITY_STAGE_LEADS = 'Leads';
	public static final String SELLER_OPPORTUNITY_STAGE_QUOTE = 'Quote and Schedule';
	public static final String SELLER_OPPORTUNITY_STAGE_EVALUATE = 'Evaluate and Pickup';
	public static final String SELLER_OPPORTUNITY_STAGE_PREPARE = 'Prepare Car for Sale';
	public static final String SELLER_OPPORTUNITY_STAGE_SELL = 'Sell Car';
	public static final String SELLER_OPPORTUNITY_STAGE_HANDOVER = 'Handover';
	public static final String SELLER_OPPORTUNITY_STAGE_SOLD = 'Sold';
	public static final String SELLER_OPPORTUNITY_STAGE_LOST = 'Lost';
	
	public static final Map<String, Integer> SELLER_STAGE_INDICES = new Map<String, Integer>{
		SELLER_OPPORTUNITY_STAGE_LEADS => 0,
		SELLER_OPPORTUNITY_STAGE_QUOTE => 1,
		SELLER_OPPORTUNITY_STAGE_EVALUATE => 2,
		SELLER_OPPORTUNITY_STAGE_PREPARE => 3,
		SELLER_OPPORTUNITY_STAGE_SELL => 4,
		SELLER_OPPORTUNITY_STAGE_HANDOVER => 5,
		SELLER_OPPORTUNITY_STAGE_SOLD => 6,
		SELLER_OPPORTUNITY_STAGE_LOST => 7
	};

	public static final List<String> SELLER_OPPORTUNITY_STAGES = new List<String>{
		SELLER_OPPORTUNITY_STAGE_LEADS,
		SELLER_OPPORTUNITY_STAGE_QUOTE,
		SELLER_OPPORTUNITY_STAGE_EVALUATE,
		SELLER_OPPORTUNITY_STAGE_PREPARE,
		SELLER_OPPORTUNITY_STAGE_SELL,
		SELLER_OPPORTUNITY_STAGE_HANDOVER,
		SELLER_OPPORTUNITY_STAGE_SOLD,
		SELLER_OPPORTUNITY_STAGE_LOST
	};

	public static final String BUYER_OPPORTUNITY_STAGE_LEADS = 'Leads';
	public static final String BUYER_OPPORTUNITY_STAGE_QUALIFIED = 'Qualified';
	public static final String BUYER_OPPORTUNITY_STAGE_SCHEDULED = 'Test Drive Scheduled';
	public static final String BUYER_OPPORTUNITY_STAGE_COMPLETE = 'Test Drive Complete';
	public static final String BUYER_OPPORTUNITY_STAGE_PENDING = 'Sale Pending';
	public static final String BUYER_OPPORTUNITY_STAGE_HANDOVER = 'Handover';
	public static final String BUYER_OPPORTUNITY_STAGE_SOLD = 'Sold';
	public static final String BUYER_OPPORTUNITY_STAGE_LOST = 'Lost';

	public static final List<String> BUYER_OPPORTUNITY_STAGES = new List<String>{
		BUYER_OPPORTUNITY_STAGE_LEADS,
		BUYER_OPPORTUNITY_STAGE_QUALIFIED,
		BUYER_OPPORTUNITY_STAGE_SCHEDULED,
		BUYER_OPPORTUNITY_STAGE_COMPLETE,
		BUYER_OPPORTUNITY_STAGE_PENDING,
		BUYER_OPPORTUNITY_STAGE_HANDOVER,
		BUYER_OPPORTUNITY_STAGE_SOLD,
		BUYER_OPPORTUNITY_STAGE_LOST
	};

	public static final Integer OPPORTUNITY_NAME_MAX_LENGTH =
		Opportunity.Name.getDescribe().getLength();

	public static final Integer VEHICLE_NAME_MAX_LENGTH =
		Vehicle__c.Name.getDescribe().getLength();

	public static final String ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY = 'shift-community-account';

	public static final String USER_SHIFT_KEY_UNOWNED = 'unowned';
	public static final String USER_SHIFT_KEY_VEHICLE_VALUATION = 'vehicle-valuation';

	public static final String TASK_STATUS_NOT_STARTED = 'Not Started';
	public static final String TASK_STATUS_IN_PROGRESS = 'In Progress';
	public static final String TASK_STATUS_COMPLETED = 'Completed';
	public static final String TASK_STATUS_WAITING_ON_SOMEONE_ELSE = 'Waiting on someone else';
	public static final String TASK_STATUS_DEFERRED = 'Deferred';
	public static final String TASK_STATUS_CANCELED = 'Canceled';

	public static final String TASK_TEAM_COPYWRITING = 'Copywriting';
	public static final String TASK_TEAM_CUSTOMER_EXPERIENCE = 'Customer Experience';
	public static final String TASK_TEAM_DETAILING = 'Detailing';
	public static final String TASK_TEAM_DOCUMENT_OPERATIONS = 'Document Operations';
	public static final String TASK_TEAM_ESTIMATES_AND_APPROVALS = 'Estimates and Approvals';
	public static final String TASK_TEAM_INSPECTION = 'Inspection';
	public static final String TASK_TEAM_MERCHANDISING = 'Merchandising';
	public static final String TASK_TEAM_PHOTOGRAPHY = 'Photography';
	public static final String TASK_TEAM_PRICING = 'Pricing';
	public static final String TASK_TEAM_PROCESSING_QUALITY_CONTROL = 'Processing Quality Control';
	public static final String TASK_TEAM_REPAIR_MANAGEMENT = 'Repair Management';
	public static final String TASK_TEAM_TOP_FEATURES = 'Top Features';
	public static final String TASK_TEAM_USER_HAPPINESS = 'User Happiness';
	public static final String TASK_TEAM_WHOLESALE = 'Wholesale';

	public static final String PROFILE_NAME_INSIDE_SALES_OUTBOUND = 'Inside Sales - Outbound';
	public static final String PROFILE_NAME_INSIDE_SALES_INBOUND = 'Inside Sales - Inbound';

	public static final String UTM_CODE_UBER_DEC_LA = 'uber-dec-la';
	public static final String UTM_CODE_UBER_DRIVERS_SOCAL_2016 = 'uber-drivers-sc-2016';

	public static final String REFERRAL_PROGRAM_OR_PROMOTION_UBER_LA_2015 = 'UberLA2015';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_UBER_DRIVERS_SOCAL_2016 = 'UberDriversSocal2016';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_ANYPERK = 'AnyPerk';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_PASSPORT_UNLIMITED_HOT_DEAL = 'Passport Unlimited 12/15 Hot Deal';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_TESLA = 'Tesla';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_PASSPORT_UNLIMITED = 'Passport Unlimited';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_GOOGLE = 'Google';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_LA_STREET_TEAM = 'LA Street Team';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_HIGHLAND_PORTOFLIO = 'Highland Portfolio';
	public static final String REFERRAL_PROGRAM_OR_PROMOTION_QUALCOMM = 'Qualcomm';

	// All keys for Key_Value__c objects go here. (Right now there's just this one.)
	public static final String KEY_BATCH_PROCESS_ANALYTICS_LAST_EXECUTION_TIME =
		'batch-process-analytics-last-execution-time';

	public static final String VEHICLE_ORDER_RETURNED_REASON_BUYERS_REMORSE = 'Buyer\'s Remorse';

	public static final String VEHICLE_ORDER_DEPOSIT_RETURNED_REASON_CAR_RETURNED = 'Car returned';
	public static final String VEHICLE_ORDER_DEPOSIT_RETURNED_REASON_OTHER = 'Other';

	public static final String VEHICLE_ORDER_PAYMENT_METHOD_CASH = 'Cash';

	public static final String TASK_SUBJECT_INPUT_CONTRACT_EXPIRATION_DATE = 'Input Contract Expiration Date';
	public static final String TASK_SUBJECT_REVIEW_CONTRACT_EXPIRATION_DATE = 'Review Contract Expiration Date';

	public static final String LEAD_SOURCE_CRAIGSLIST = 'Craigslist';
	public static final String LEAD_SOURCE_DRIVESHIFT = 'driveshift.com';
	public static final String LEAD_SOURCE_SELLER_APP = 'Seller App';
	public static final String LEAD_SOURCE_TESLA = 'Tesla';
	public static final String LEAD_SOURCE_TESLA_REMARKETING = 'Tesla - Remarketing';
	public static final String LEAD_SOURCE_WORD_OF_MOUTH = 'Word of Mouth';

	public static final String LEAD_INQUIRY_TYPE_HOT_BUYER = 'Hot Buyer';
	public static final String LEAD_INQUIRY_TYPE_OFF_COMING_SOON = 'Off Coming Soon Notification';
	public static final String LEAD_INQUIRY_TYPE_OFF_SALE_PENDING = 'Off Sale Pending Notification';
	public static final String LEAD_INQUIRY_TYPE_TEST_DRIVE = 'Test Drive';
	public static final String LEAD_INQUIRY_TYPE_TEST_DRIVE_REJECTED = 'Test Drive Rejected';
	public static final String LEAD_INQUIRY_TYPE_VEHICLE_QUESTION = 'Vehicle Question';

	public static final String LEAD_CONTACT_METHOD_CHAT = 'Chat';
	public static final String LEAD_CONTACT_METHOD_EMAIL = 'Email';
	public static final String LEAD_CONTACT_METHOD_SMS = 'SMS';
	public static final String LEAD_CONTACT_METHOD_VOICE = 'Voice';
	public static final String LEAD_CONTACT_METHOD_VOICEMAIL = 'Voicemail';
	
	public static final String PRICING_STRATEGY_STANDARD = 'Standard';
	public static final String PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT = 'Flat Fee - Dollar Amount';
	public static final String PRICING_STRATEGY_FLAT_FEE_PERCENT = 'Flat Fee - Percent';
	public static final String PRICING_STRATEGY_SINGLE_PRICE_0_UPSIDE = 'Single Price - 0% Upside';
	public static final String PRICING_STRATEGY_SPECIFIC_CAR_SEARCH = 'Specific Car Search';

	public static final String TRADE_IN_STATUS_FUNDED = 'Funded';
	public static final String ADVANCE_FUNDS_STATUS_FUNDED = 'Funded';
	public static final String ADVANCE_FUNDS_STATUS_CLOSED = 'Closed';
	public static final String ADVANCE_FUNDS_TYPE_LIENHOLDER_ONLY = 'Lienholder Only';
	public static final String ADVANCE_FUNDS_TYPE_FULL = 'Full';

	public static final String CASE_STATUS_NEW = 'New';
	public static final String CASE_STATUS_NEEDS_ACTION = 'Needs Action';

	public static final String STAFF_PROFILE_ATTRIBUTE_TYPE_CAPABILITY = 'Capability';
	public static final String STAFF_PROFILE_ATTRIBUTE_TYPE_ROLE = 'Role';

	public static final String SKEDULO_TAG_TYPE_SKILL = 'Skill';
	public static final String SKEDULO_TAG_TYPE_ROLE = 'Role';
	public static final String SKEDULO_TAG_CLASSIFICATION_GLOBAL = 'Global';

	public static final Map<String, String> STAFF_PROFILE_ATTRIBUTE_TYPE_TO_SKEDULO_TAG_TYPE = new Map<String, String>{
		STAFF_PROFILE_ATTRIBUTE_TYPE_CAPABILITY => SKEDULO_TAG_TYPE_SKILL,
		STAFF_PROFILE_ATTRIBUTE_TYPE_ROLE => SKEDULO_TAG_TYPE_ROLE
	};

	public static final String SKEDULO_RESOURCE_TYPE_PERSON = 'Person';

	public static final String PAPERWORK_MISSING_NO = 'No';
	public static final String PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE = 'Yes - More Than 7 Days Unavailable';
	public static final String PAPERWORK_MISSING_YES_AVAILABLE_WITHOUT_FINANCING = 'Yes - Available Without Financing';
	public static final String PAPERWORK_MISSING_YES_LESS_THAN_7_DAYS_UNAVAILABLE = 'Yes - Less Than 7 Days Unavailable';

	public static final String PAPERWORK_MISSING_REASON_PAYOFF_SELLER_UNDERWATER = 'Payoff - seller underwater';
	public static final String PAPERWORK_MISSING_REASON_PAYOFF_WAITING_STATEMENT = 'Payoff - waiting for seller to send payoff statement';
	public static final String PAPERWORK_MISSING_REASON_SELLER_NOT_COOPERATING = 'Seller - not cooperating';
	public static final String PAPERWORK_MISSING_REASON_TITLE_SELLER_PROBLEM = 'Title - missing signature, seller not reachable';
	public static final String PAPERWORK_MISSING_REASON_TITLE_OUT_OF_STATE = 'Title - out of state title';
	public static final String PAPERWORK_MISSING_REASON_TITLE_WAITING_SELLER = 'Title - waiting on seller to send';

	public static final Integer PAPERWORK_MISSING_FEE = 300;
	public static final Decimal ADVANCE_FUNDS_FEE = 100.0;
	
	public static final Decimal SELLER_PICKUP_FEE = 100;
	public static final Decimal SELLER_DROPOFF_FEE = 0;
	public static final Decimal SELLER_PICKUP_DURING_EVAL_FEE = 0;

	public static final String CASE_TYPE_8_8_VOICEMAIL = '8x8 Voicemail';
	public static final String CASE_TYPE_AUTOMATED_PICKUP_REQUEST = 'Automated Pickup Request';
	public static final String CASE_TYPE_CANCELATION_FOLLOW_UP = 'Cancellation Follow Up';
	public static final String CASE_TYPE_CAR_ENTHUSIAST_TEST_DRIVE_REQUEST = 'Car Enthusiast Test Drive Request';
	public static final String CASE_TYPE_CRAIGSLIST_FOLLOW_UP = 'Craigslist Follow Up';
	public static final String CASE_TYPE_DELIVERY_REQUEST = 'Delivery Request';
	public static final String CASE_TYPE_GENERAL_EMAIL = 'General Email';
	public static final String CASE_TYPE_NEW_INBOUND_SELLER_OPPORTUNITY = 'New Inbound Seller Opportunity';
	public static final String CASE_TYPE_OPEN_EVALUATION = 'Open Evaluation';
	public static final String CASE_TYPE_OTHER = 'Other';
	public static final String CASE_TYPE_PERMANENT_RETRUN = 'Permanent Return';
	public static final String CASE_TYPE_PRICING_UPDATE = 'Pricing Update';
	public static final String CASE_TYPE_RESPONSE_TO_DRIP_CAMPAIGN = 'Response to Drip Campaign';
	public static final String CASE_TYPE_SHIFT_TEST_DRIVE_REQUEST = 'shift.com Test Drive Request';
	public static final String CASE_TYPE_SHIFT_TEST_DRIVE_REQUEST_REJECTED = 'shift.com Test Drive Request Rejected';
	public static final String CASE_TYPE_SHIFT_VEHICLE_QUESTION = 'shift.com Vehicle Question';
	public static final String CASE_TYPE_TEMPORARY_RETURN = 'Temporary Return';
	public static final String CASE_TYPE_TESLA_EMAIL = 'Tesla Email';
	public static final String CASE_TYPE_THIRD_PARTY_LISTING_SITE_VEHICLE_QUESTION = 'Third Party Listing Site Vehicle Question';
	public static final String CASE_TYPE_VEHICLE_AVAILABLE_SCHEDULE_TEST_DRIVES = 'Vehicle Available - Schedule Test Drives';
	public static final String CASE_TYPE_VEHICLE_UNAVAILABLE_CANCEL_TEST_DRIVES = 'Vehicle Unavailable - Cancel Test Drives';

	public static final Decimal VEHICLE_PRICE_TIER_ONE = 15000.0;
	public static final Decimal VEHICLE_PRICE_TIER_TWO = 30000.0;

	public static final Decimal SERVICE_FEE_TIER_ONE = 195.0;
	public static final Decimal SERVICE_FEE_TIER_TWO = 295.0;
	public static final Decimal SERVICE_FEE_TIER_THREE = 395.0;
}