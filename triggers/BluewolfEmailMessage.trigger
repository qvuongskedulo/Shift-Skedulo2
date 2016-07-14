trigger BluewolfEmailMessage on EmailMessage (after insert) {
    if(trigger.isAfter){
        if(trigger.isInsert){
            BluewolfEmailMessageService.afterInsert(trigger.new);
        }
    }
}