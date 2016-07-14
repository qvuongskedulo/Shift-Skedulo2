trigger ShiftOpportunityNameUpdateInsert on Opportunity (before update, before insert) {
    List<Id> accountIds = new List<Id>();
    List<Id> recordTypeIds = new List<Id>();
    List<Id> vehicleIds = new List<Id>();
    for (Opportunity o : Trigger.new) {
        accountIds.add(o.AccountId);
        recordTypeIds.add(o.RecordTypeId);
        vehicleIds.add(o.Vehicle_ID__c);
    }

    Map<Id, Account> accountMap = new Map<Id, Account>(
        [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
    );
    Map<Id, RecordType> recordTypeMap = new Map<Id, RecordType>(
        [SELECT Id, DeveloperName FROM RecordType WHERE Id IN :recordTypeIds]
    );
    Map<Id, Vehicle__c> vehicleMap = new Map<Id, Vehicle__c>(
        [SELECT Id, Name, Exterior_Color__c FROM Vehicle__c WHERE Id IN :vehicleIds]
    );

    for (Opportunity o : Trigger.new) {
        if (recordTypeMap.get(o.RecordTypeId).DeveloperName == ShiftConstants.OPPORTUNITY_RECORD_TYPE_SELLER) {
            // Seller opportunity name: "{vehicle YMMT} - {account name} - {exterior color}"
            Vehicle__c vehicle = vehicleMap.get(o.Vehicle_ID__c);
            if (vehicle == null) {
                // o.Vehicle_ID__c might be missing, which will be handled by
                // salesforce (missing field), but we still need to continue
                // here rather than attempting a deference below
                continue;
            }
            List<string> nameComponents = new List<string>();
            nameComponents.add(vehicle.Name);
            nameComponents.add(accountMap.get(o.AccountId).Name);
            if (String.isNotEmpty(vehicle.Exterior_Color__c)) {
                nameComponents.add(vehicle.Exterior_Color__c);
            }
            o.Name = String.join(nameComponents, ' - ');
        } else if (recordTypeMap.get(o.RecordTypeId).DeveloperName == ShiftConstants.OPPORTUNITY_RECORD_TYPE_BUYER) {
            // Buyer opportunity name: "{account name}"
            o.Name = accountMap.get(o.AccountId).Name;
        }
        if (o.Name != null) {
            o.Name = o.Name.left(ShiftConstants.OPPORTUNITY_NAME_MAX_LENGTH);
        }
    }
}