trigger ShiftNoteInsert on Note (before insert) {
    for (Note note : Trigger.new) {
        note.addError('Note creation not allowed. Try creating an Opportunity Note instead. You can copy and paste your text so you don\'t have to re-enter it.');
    }
}