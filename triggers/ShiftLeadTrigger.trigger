trigger ShiftLeadTrigger on Lead (after insert) {
  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      ShiftLeads.afterInsert(Trigger.new);
    }
  }
}