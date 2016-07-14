@IsTest public class ShiftTasksTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static void expectTaskException(Exception ex, String pat) {
		if (!(ex instanceof ShiftTasks.TaskException)) {
			throw ex;
		}
		System.debug('checking (' + ex.getMessage() + ') against (' + pat + ')');
		if (!Pattern.matches(pat, ex.getMessage())) {
			throw ex;
		}
	}

	@IsTest static void testCompleteClaimAbandon() {
		ShiftTesting.TaskExpector e = new ShiftTesting.TaskExpector(new Task(
			Subject = 'test',
			OwnerId = ShiftUsers.unownedUserId()
		));
		insert e.task;
		Id userId = UserInfo.getUserId();
		User user2 = ShiftTesting.createTestUser();
		System.runAs(user2) {
			ShiftTasks.claim(e.task.Id, userId);
			e.sync();
			System.assertEquals(userId, e.task.OwnerId);
			System.assertEquals(ShiftConstants.TASK_STATUS_IN_PROGRESS, e.task.Status);
			try {
				ShiftTasks.claim(e.task.Id, user2.Id);
				System.assert(false, 'claim() did not fail');
			} catch (Exception ex) {
				expectTaskException(ex, '.*cannot claim task \\(already owned by user.*');
			}
			try {
				ShiftTasks.abandon(e.task.Id, user2.Id);
				System.assert(false, 'abandon() did not fail');
			} catch (Exception ex) {
				expectTaskException(ex, '.*cannot abandon task \\(already owned by user.*');
			}
			ShiftTasks.abandon(e.task.Id, userId);
			e.sync();
			System.assertEquals(ShiftUsers.unownedUserId(), e.task.OwnerId);
			System.assertEquals(ShiftConstants.TASK_STATUS_NOT_STARTED, e.task.Status);
			e.task.Status = ShiftConstants.TASK_STATUS_COMPLETED;
			update e.task;
			try {
				ShiftTasks.claim(e.task.Id, userId);
				System.assert(false, 'claim() did not fail');
			} catch (Exception ex) {
				expectTaskException(ex, '.*cannot claim task \\(status is "Completed"\\).*');
			}
			e.task.Status = ShiftConstants.TASK_STATUS_NOT_STARTED;
			update e.task;
			ShiftTasks.claim(e.task.Id, userId);
			try {
				ShiftTasks.complete(e.task.Id, user2.Id);
				System.assert(false, 'complete() did not fail');
			} catch (Exception ex) {
				expectTaskException(ex, '.*cannot complete task \\(already owned by user.*');
			}
			ShiftTasks.complete(e.task.Id, userId);
			e.sync();
			System.equals(ShiftConstants.TASK_STATUS_COMPLETED, e.task.Status);
		}
	}

	static void expectShiftTaskEvent(Shift_Task_Event__c expected, Shift_Task_Event__C actual) {
		System.assertNotEquals(null, actual.Occurred_At__c);
		System.assertEquals(expected.Is_Owner_Change__c, actual.Is_Owner_Change__c);
		System.assertEquals(expected.Is_Status_Change__c, actual.Is_Status_Change__c);
		System.assertEquals(expected.From_Owner_ID__C, actual.From_Owner_ID__C);
		System.assertEquals(expected.To_Owner_ID__C, actual.To_Owner_ID__C);
		System.assertEquals(expected.From_Status__C, actual.From_Status__C);
		System.assertEquals(expected.To_Status__C, actual.To_Status__C);
	}

	@IsTest static void testShiftTaskEventInsertion() {
		User firstTestUser = ShiftTesting.createTestUser();
		User secondTestUser = ShiftTesting.createTestUser();
		insert new List<User>{firstTestUser, secondTestUser};

		Task task = new Task(
				Subject = 'test',
				OwnerId = ShiftUsers.unownedUserId()
		);
		insert task;
		task.OwnerId = firstTestUser.Id;
		task.Status = 'Test Status';
		update task;
		task.OwnerId = secondTestUser.Id;
		update task;
		task.Status = 'Another Status';
		update task;

		List<Shift_Task_Event__c> events = [
				SELECT Task_ID__c, Occurred_At__c, To_Owner_ID__c, To_Status__c, From_Owner_ID__c, From_Status__c, Is_Status_Change__c, Is_Owner_Change__c
				FROM Shift_Task_Event__c
				WHERE Task_ID__c = :task.Id
				ORDER BY Name ASC
		];
		System.assertEquals(4, events.size());
		expectShiftTaskEvent(new Shift_Task_Event__c(
			Task_ID__c = task.Id,
			Is_Owner_Change__c = true,
			To_Owner_Id__c = ShiftUsers.unownedUserId(),
			From_Owner_Id__c = null,
			Is_Status_Change__c = true,
			To_Status__c = 'Not Started',
			From_Status__c = null
		), events.get(0));
		expectShiftTaskEvent(new Shift_Task_Event__c(
			Task_ID__c = task.Id,
			Is_Owner_Change__c = true,
			To_Owner_Id__c = firstTestUser.Id,
			From_Owner_Id__c = ShiftUsers.unownedUserId(),
			Is_Status_Change__c = true,
			To_Status__c = 'Test Status',
			From_Status__c = 'Not Started'
		), events.get(1));
		expectShiftTaskEvent(new Shift_Task_Event__c(
			Task_ID__c = task.Id,
			Is_Owner_Change__c = true,
			To_Owner_Id__c = secondTestUser.Id,
			From_Owner_Id__c = firstTestUser.Id,
			Is_Status_Change__c = false,
			To_Status__c = null,
			From_Status__c = null
		), events.get(2));
		expectShiftTaskEvent(new Shift_Task_Event__c(
			Task_ID__c = task.Id,
			Is_Owner_Change__c = false,
			To_Owner_Id__c = null,
			From_Owner_Id__c = null,
			Is_Status_Change__c = true,
			To_Status__c = 'Another Status',
			From_Status__c = 'Test Status'
		), events.get(3));
	}
}