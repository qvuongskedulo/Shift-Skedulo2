@isTest
private class ShiftNoteTriggersTest {
    @isTest
    static void testInsert() {
        try {
            insert new Note(Body = 'foo');
            System.assert(false, 'creation of Notes should fail');
        } catch (Exception e) {
        }
    }
}