// The parent class for all Shift exceptions (which all extend ShiftException).
public class ShiftExceptions {
	@TestVisible final static String FIELD_MISSING_EXCEPTION_TEXT = ' is required';

	public class FieldMissingException extends ShiftException {}

	public static FieldMissingException newFieldMissingException(Schema.SObjectField field) {
		return new FieldMissingException(field.getDescribe().getLabel() + FIELD_MISSING_EXCEPTION_TEXT);
	}

}