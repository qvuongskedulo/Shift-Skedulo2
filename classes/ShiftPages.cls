public class ShiftPages {
	public static String getStringParameter(String name) {
		return ApexPages.currentPage().getParameters().get(name);
	}

	public static Id getIdParameter(String name) {
		return Id.valueOf(getStringParameter(name));
	}

	public static Id getIdParameter() {
		return getIdParameter('id');
	}

	public static Boolean getBooleanParameter(String name) {
		String s = getStringParameter(name);
		return s == null ? false : Boolean.valueOf(s);
	}

	public static void addMessage(ApexPages.Severity severity, String summary) {
		ApexPages.addMessage(new ApexPages.Message(severity, summary));
	}

	public static void addConfirmMessage(String summary) {
		addMessage(ApexPages.Severity.CONFIRM, summary);
	}

	public static void addErrorMessage(String summary) {
		addMessage(ApexPages.Severity.ERROR, summary);
	}

	public static void addFatalMessage(String summary) {
		addMessage(ApexPages.Severity.FATAL, summary);
	}

	public static void addInfoMessage(String summary) {
		addMessage(ApexPages.Severity.INFO, summary);
	}

	public static void addWarningMessage(String summary) {
		addMessage(ApexPages.Severity.WARNING, summary);
	}

	public static String getShiftcarsAdminUrl(String relPath, Map<String, String> parameters) {
		// TODO: use Key_Value__c or a developer cookie, as appopriate, to
		// store the base URL rather than hardcoding 'shiftcars1.appspot.com'. 
		//
		// Also, less error-prone than string concatenation would be something
		// like java.net.URI.resolve(), but it doesn't look like there is an
		// Apex equivalent.
		PageReference ref = new PageReference('https://shiftcars1.appspot.com/admin/' + relPath);
		if (parameters != null) {
			ref.getParameters().putAll(parameters);
		}
		return ref.getUrl();
	}
}