public class skedExceptions {
	public class AppointmentAlreadyScheduledException extends skedException {}

	public static AppointmentAlreadyScheduledException newAppointmentAlreadyScheduledException() {
		return new AppointmentAlreadyScheduledException();
	}

	public class AppointmentLimitReachedException extends skedException {}

	public static AppointmentLimitReachedException newAppointmentLimitReachedException(String objectType) {
		return new AppointmentLimitReachedException('Limit for ' + objectType + ' appointments reached.');
	}

	public class CustomerBlacklistedException extends skedException {}

	public static CustomerBlacklistedException newCustomerBlacklistedException(String contactId) {
		return new CustomerBlacklistedException('Contact : ' + contactId + ' has been blacklisted.');
	}

	public class JobAlreadyCancelledException extends skedException {}

	public static JobAlreadyCancelledException newJobAlreadyCancelledException(String jobId) {
		return new JobAlreadyCancelledException('Job ' + jobId + ' is already cancelled.');
	}

	public class JobAlreadyCompleteException extends skedException {}

	public static JobAlreadyCompleteException newJobAlreadyCompleteException(String jobId) {
		return new JobAlreadyCompleteException('Job ' + jobId + ' is already complete.');
	}

	public class JobNotFoundException extends skedException {}

	public static JobNotFoundException newJobNotFoundException(String jobId) {
		return new JobNotFoundException('Job ' + jobId + ' not found.');
	}

	public class NoEmployeeAvailableException extends skedException {}

	public static NoEmployeeAvailableException newNoEmployeeAvailableException(DateTime startTime) {
		return new NoEmployeeAvailableException('No employee is available at ' + startTime + '.');
	}

	public static NoEmployeeAvailableException newNoEmployeeAvailableException(String jobType, DateTime startTime) {
		return new NoEmployeeAvailableException('No employee is available to perform a ' + jobType + ' at ' + startTime + '.');
	}

	public class OpportunityNotFoundException extends skedException {}

	public static OpportunityNotFoundException newOpportunityNotFoundException(String oppId) {
		return new OpportunityNotFoundException('Opportunity ' + oppId + ' not found.');
	}

	public class RequiredInputMissingException extends skedException {}

	public static RequiredInputMissingException newRequiredInputMissingException(String inputName) {
		return new RequiredInputMissingException('Request missing required input: ' + inputName + '.');
	}

	public class VehicleNotFoundException extends skedException {}

	public static VehicleNotFoundException newVehicleNotFoundException(String vin) {
		return new VehicleNotFoundException('Vehicle with vin: ' + vin + ' not found.');
	}

	public class VehicleNotReadyException extends skedException {}

	public static VehicleNotReadyException newVehicleNotReadyException(String vehicleId, string message) {
		return new VehicleNotReadyException('Vehicle ' + vehicleId + ' is not ready for test drives: ' + message + '.');
	}

	public class ZipCodeNotServicedException extends skedException {}

	public static ZipCodeNotServicedException newZipCodeNotServicedException(String ZIPCode) {
		return new ZipCodeNotServicedException(ZIPCode + ' is not currently serviced.');
	}
}