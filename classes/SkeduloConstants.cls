public class SkeduloConstants {

	public static final string DATE_PARSE_FORMAT = 'M/d/yyyy';

	public static final string ALLOCATION_STATUS_DELETED = 'Deleted';
	public static final string ALLOCATION_STATUS_DISPATCHED = 'Dispatched';
	public static final string ALLOCATION_STATUS_CONFIRMED = 'Confirmed';

	public static final string JOB_STATUS_CANCELLED = 'Cancelled';
	public static final string JOB_STATUS_IN_PROGRESS = 'In Progress';
	public static final string JOB_STATUS_COMPLETE = 'Complete';
	public static final string JOB_STATUS_DISPATCHED = 'Dispatched';
	public static final string JOB_STATUS_READY = 'Ready';

	public static final string JOB_TYPE_BUYER_PICKUP = 'Buyer Pickup';
	public static final string JOB_TYPE_DRIVERS_ASSIST = 'Drivers Assist';
	public static final string JOB_TYPE_PICKUP_ONLY = 'Pickup Only';
	public static final string JOB_TYPE_TEST_DRIVE = 'Test Drive';
	public static final string JOB_TYPE_EVALUATION = 'Evaluation';

	public static final string OBJECT_TYPE_PICKUP = 'pickup';
	public static final string OBJECT_TYPE_DELIVERY = 'delivery';
	public static final string OBJECT_TYPE_TEST_DRIVE = 'testdrive';
	public static final string OBJECT_TYPE_EVALUATION = 'evaluation';

	public static final integer JOB_DURATION_DRIVERS_ASSIST = 15;

	public static final string RESOURCE_TAG_DRIVE_MANUAL = 'can-drive-manual';
	public static final string RESOURCE_TAG_CC = 'is-concierge';
	public static final string RESOURCE_TAG_CE = 'is-enthusiast';
	public static final string RESOURCE_TAG_DOS = 'is-delivery-operations-specialist';
	public static final string RESOURCE_TAG_PROPS_DRIVER = 'is-props-driver';

	public static final string PROFILE_INBOUND_SALES = 'Inside Sales - Inbound';
	public static final string PROFILE_OUTBOUND_SALES = 'Inside Sales - Outbound';

	public static final integer EVALUATION_QUOTE_EXPIRED_DAYS = 14;

	public static final string ACTIVITY_TYPE_1ON1_MEETING = '1:1 Meeting';
	public static final string ACTIVITY_TYPE_BUYER_DELIVERY = 'Buyer Delivery';
	public static final string ACTIVITY_TYPE_INSPECTION_DC = 'Inspection - DC';
	public static final string ACTIVITY_TYPE_INSPECTION_MD = 'Inspection - MD';
	public static final string ACTIVITY_TYPE_INSPECTION_VA = 'Inspection - VA';
	public static final string ACTIVITY_TYPE_MISCELLANEOUS = 'Miscellaneous';
	public static final string ACTIVITY_TYPE_PREP_TIME = 'Prep Time';
	public static final string ACTIVITY_TYPE_SELLER_PICKUP = 'Seller Pickup';
	public static final string ACTIVITY_TYPE_SELLER_RETURN = 'Seller Return';
	public static final string ACTIVITY_TYPE_TEAM_MEETING = 'Team Meeting';
	public static final string ACTIVITY_TYPE_TRAINING = 'Training';
	public static final string ACTIVITY_TYPE_VEHICLE_LOGISTICS = 'Vehicle Logistics';
	public static final string ACTIVITY_TYPE_BREAK = 'Break';
    
    public static final integer ACTIVITY_BREAK_DURATION = 30;

	// Error codes
	public static final string ERROR_CODE_APPOINTMENT_ALREADY_SCHEDULED = 'APPOINTMENT_ALREADY_SCHEDULED';
	public static final string ERROR_CODE_APPOINTMENT_LIMIT_REACHED = 'APPOINTMENT_LIMIT_REACHED';
	public static final string ERROR_CODE_CUSTOMER_BLACKLISTED = 'CUSTOMER_BLACKLISTED';
	public static final string ERROR_CODE_JOB_ALREADY_CANCELLED = 'JOB_ALREADY_CANCELLED';
	public static final string ERROR_CODE_JOB_ALREADY_COMPLETE = 'JOB_ALREADY_COMPLETE';
	public static final string ERROR_CODE_JOB_NOT_FOUND = 'JOB_NOT_FOUND';
	public static final string ERROR_CODE_NO_EMPLOYEE_AVAILABLE = 'NO_EMPLOYEE_AVAILABLE';
	public static final string ERROR_CODE_OPPORTUNITY_NOT_FOUND = 'OPPORTUNITY_NOT_FOUND';
	public static final string ERROR_CODE_REQUIRED_INPUT_MISSING = 'REQUIRED_INPUT_MISSING';
	public static final string ERROR_CODE_VEHICLE_NOT_FOUND = 'VEHICLE_NOT_FOUND';
	public static final string ERROR_CODE_VEHICLE_NOT_READY = 'VEHICLE_NOT_READY';
	public static final string ERROR_CODE_ZIP_CODE_NOT_SERVICED = 'ZIP_CODE_NOT_SERVICED';
}