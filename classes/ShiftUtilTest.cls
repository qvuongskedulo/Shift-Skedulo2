@isTest
private class ShiftUtilTest {

	@IsTest
	static void testNormalizePhone() {
		Map<String, String> expected = new Map<String, String>{
				null => null,
				'' => '',
				'+15551112222' => '(555) 111-2222',
				'+1 (555) 111-2222' => '(555) 111-2222',
				'1555-111-----2222' => '(555) 111-2222',
				'(555) 222-1234' => '(555) 222-1234',
				'555-222-1234' => '(555) 222-1234',
				'+555-222-1234' => '(555) 222-1234',
				'123456789' => '123456789',
				'AAABBBCCCC' => 'AAABBBCCCC',
				'+25551112222' => '+25551112222',
				'+1-122-333-7777' => '+1-122-333-7777',
				'25551116666' => '25551116666',
				'(155) 222-1234' => '(155) 222-1234'
		};

		for (String input : expected.keySet()) {
			System.assertEquals(ShiftUtil.normalizePhone(input), expected.get(input));
		}
	}

	@isTest
	static void testIsValidId() {
		System.assertEquals(true, ShiftUtil.isValidId('a0U1a0000010aeq'));
		System.assertEquals(false, ShiftUtil.isValidId('123'));
	}
}