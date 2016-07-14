public class ShiftUtil {
	private static final Set<String> PHONE_NORMALIZATION_SUPPORTED_LOCALES = new Set<String>{'en_US', 'en_CA'};

	private ShiftUtil() {}

	static Pattern phoneFilterPattern = Pattern.compile('\\D+');

	public static String soqlQuote(String x) {
		return '\'' + String.escapeSingleQuotes(x) + '\'';
	}

	public static Boolean isValidId(String x) {
		try {
			Id id = x;
			return true;
		} catch (StringException ex) {
			return false;
		}
	}

	private static String randomString(Integer len, String chars) {
		Integer[] res = new Integer[len];
		Integer charsLen = chars.length();
		for (Integer i = 0; i < len; ++i) {
			res[i] = chars.charAt(Math.mod(Math.abs(Crypto.getRandomInteger()), charsLen));
		}
		return String.fromCharArray(res);
	}

	public static String randomStringLowercaseAlphanum(Integer len) {
		return randomString(len, 'abcdefghijklmnopqrstuvwxyz0123456789');
	}

	// Normalizes phone numbers per https://help.salesforce.com/apex/HTViewSolution?id=000181563&language=en_US
	public static String normalizePhone(String phone) {
		if (phone == null || phone.length() == 0) {
			return phone;
		}
		if (!PHONE_NORMALIZATION_SUPPORTED_LOCALES.contains(UserInfo.getLocale())) {
			return phone;
		}
		String formattedPhoneNumber = phoneFilterPattern.matcher(phone).replaceAll('');
		if (formattedPhoneNumber.length() == 11 && formattedPhoneNumber.substring(0, 1) == '1' && formattedPhoneNumber.substring(1, 2) != '1') {
			formattedPhoneNumber = formattedPhoneNumber.substring(1);
		}
		if (formattedPhoneNumber.length() == 10 && formattedPhoneNumber.substring(0, 1) != '1') {
			return '(' + formattedPhoneNumber.substring(0, 3) + ') ' + formattedPhoneNumber.substring(3, 6) + '-' + formattedPhoneNumber.substring(6);
		}
		return phone;
	}

	public static void validateRequiredField(List<SObject> objectsToValidate, Schema.SObjectField requiredField) {
		for (SObject objectToValidate : objectsToValidate) {
			Object requiredFieldValue = objectToValidate.get(requiredField);
			if (requiredFieldValue == null || (requiredFieldValue instanceof String && String.isBlank((String) requiredFieldValue))) {
				objectToValidate.addError(ShiftExceptions.newFieldMissingException(requiredField));
			}
		}
	}

	public static Decimal nonNullDecimal(Decimal val) {
		if (val == null) {
			return 0.0;
		} else {
			return val;
		}
	}
}