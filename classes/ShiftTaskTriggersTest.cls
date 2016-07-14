@isTest
private class ShiftTaskTriggersTest {
	
	@testSetup private static void setup() { ShiftTesting.setup(); }

	@isTest
	static void testForcedVisible() {
		insert new Task(
			IsVisibleInSelfService = false
		);
		Task task = [SELECT Id, IsVisibleInSelfService FROM Task];
		System.assertEquals(true, task.IsVisibleInSelfService);
	}

	private static void assertOwner(Id taskId, Id expctOwnerId) {
		Task act = [SELECT OwnerId FROM Task WHERE Id = :taskId];
		System.assertEquals(expctOwnerId, act.OwnerId);
	}
}