public class ShiftBatchProcessAnalytics
        implements Database.Batchable<Shift_Stage_Change__c>, Database.AllowsCallouts, Database.Stateful {

    private final Integer intervalMinutes;
    private final Integer fakeResponseCode;

    private Key_Value__c timeKv;

    // Job schedules itself for re-execution every intervalMinutes, iff intervalMinutes > 0.
    public ShiftBatchProcessAnalytics(Integer intervalMinutes) {
        this.intervalMinutes = intervalMinutes;
    }

    // Constructor for test use only.
    public ShiftBatchProcessAnalytics(Integer intervalMinutes, Integer fakeResponseCode) {
        this.intervalMinutes = intervalMinutes;
        this.fakeResponseCode = fakeResponseCode;
    }

    public Iterable<Shift_Stage_Change__c> start(Database.BatchableContext bc) {
        List<Key_Value__c> kvs = [
                SELECT Id, Value__c FROM Key_Value__c
                WHERE Key__c = :ShiftConstants.KEY_BATCH_PROCESS_ANALYTICS_LAST_EXECUTION_TIME
        ];
        if (kvs.isEmpty()) {
            timeKv = new Key_Value__c(
                    Key__c = ShiftConstants.KEY_BATCH_PROCESS_ANALYTICS_LAST_EXECUTION_TIME
            );
        } else {
            timeKv = kvs.get(0);
        }
        Datetime startTime = Datetime.newInstance(0);
        if (timeKv.Value__c != null) {
            // If the field is not parseable as an integer we probably want this to die with an
            // exception so that we can manually take a look at what happened. So, not catching
            // a TypeException here.
            startTime = Datetime.newInstance(Long.valueOf(timeKv.Value__c));
        }
        Datetime endTime = Datetime.now();
        timeKv.Value__c = String.valueOf(endTime.getTime());

        return (Iterable<Shift_Stage_Change__c>) Database.getQueryLocator([
                SELECT Changed_At__c, From_Stage__c, To_Stage__c, Opportunity_ID__r.Account.Id, Opportunity_ID__r.LeadSource, Opportunity_ID__r.Vehicle_ID__r.Driveshift_Listing_URL__c, Opportunity_ID__r.Car_Activity_URL__c, Opportunity_ID__r.Direct_To_Wholesale__c, Changed_By__r.Name
                FROM Shift_Stage_Change__c
                WHERE Changed_At__c >= :startTime AND Changed_At__c < :endTime
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Shift_Stage_Change__c> stageChanges) {
        Map<Id, List<Shift_Stage_Change__c>> opportunityIdToStageChangesMap = new Map<Id, List<Shift_Stage_Change__c>>();
        Map<Id, Opportunity> accountIdToOpportunityMap = new Map<Id, Opportunity>();
        for (Shift_Stage_Change__c stageChange : stageChanges) {
            List<Shift_Stage_Change__c> stageChangesForOpportunity =
                    opportunityIdToStageChangesMap.get(stageChange.Opportunity_ID__c);
            if (stageChangesForOpportunity == null) {
                stageChangesForOpportunity = new List<Shift_Stage_Change__c>();
                opportunityIdToStageChangesMap.put(stageChange.Opportunity_ID__c, stageChangesForOpportunity);
            }
            stageChangesForOpportunity.add(stageChange);

            accountIdToOpportunityMap.put(stageChange.Opportunity_ID__r.AccountId, stageChange.Opportunity_ID__r);
        }

        List<Contact> contacts = [
                SELECT Id, AccountId, Analytics_ID__c, Email FROM Contact
                WHERE AccountId IN :accountIdToOpportunityMap.keySet()
        ];
        for (Contact contact : contacts) {
            List<Shift_Stage_Change__c> stageChangesForOpportunity =
                    opportunityIdToStageChangesMap.get(accountIdToOpportunityMap.get(contact.AccountId).Id);
            for (Shift_Stage_Change__c stageChange : stageChangesForOpportunity) {
                reportStageChange(contact, stageChange);
            }
        }
    }

    // JSON struct for a Segment "track" call.
    // Apex apparently does not allow inner classes nested more than two deep.
    public class Track {
        String userId;
        String event;
        Properties properties;
        Context context;
        DateTime timestamp;
    }
    public class Properties {
        String carListingURL;
        String carActivityURL;
        String email;
        String fromStage;
        String changedBy;
        String changedByName;
        String opportunityID;
        String opportunityLeadSource;
        String directToWholesale;
    }
    public class Context {
        App app;
    }
    public class App {
        String name;
        String version;
    }

    public class SegmentException extends Exception{}

    private void reportStageChange(Contact contact, Shift_Stage_Change__c stageChange) {
        // If AnalyticsID is null or an empty string Segment will not track the event.
        String analyticsID = (contact.Analytics_ID__c == null || contact.Analytics_ID__c == '') ? 'unknown': contact.Analytics_ID__c;

        System.debug('reporting stage change for analytics ID "' + analyticsID + '": ' + stageChange);

        // Generate JSON.
        JSONGenerator gen = JSON.createGenerator(true);
        Track track = new Track();
        track.userId = analyticsID;
        track.event = 'Opportunity Stage Change: ' + stageChange.To_Stage__c;
        track.properties = new Properties();
        track.properties.email = contact.Email;
        track.properties.fromStage = stageChange.From_Stage__c;
        track.properties.changedBy = String.valueOf(stageChange.Changed_By__c);
        track.properties.changedByName = stageChange.Changed_By__r.Name;
        track.properties.opportunityID = stageChange.Opportunity_ID__c;
        track.properties.opportunityLeadSource = stageChange.Opportunity_ID__r.LeadSource;
        track.properties.carListingURL = stageChange.Opportunity_ID__r.Vehicle_ID__r.Driveshift_Listing_URL__c;
        track.properties.carActivityURL = stageChange.Opportunity_ID__r.Car_Activity_URL__c;
        track.properties.directToWholesale = String.valueOf(stageChange.Opportunity_ID__r.Direct_To_Wholesale__c);
        track.context = new Context();
        track.context.app = new App();
        track.context.app.name = 'Salesforce ShiftBatchProcessAnalytics';
        track.context.app.version = '1';
        track.timestamp = stageChange.Changed_At__c;
        gen.writeObject(track);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Segment'); // named credential saved in Salesforce
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(gen.getAsString());
        System.debug('HTTP request to Segment: ' + req.toString());
        System.debug('Request body: "' + req.getBody() + '"');
        Http h = new Http();
        HttpResponse resp;
        if (!Test.isRunningTest()) {
            resp = h.send(req);
            System.debug('Response body from Segment: "' + resp.getBody() + '"');
        } else {
            // Disgustingly, this is the only way to test HTTP callouts from Batch jobs in Apex.
            resp = new HTTPResponse();
            resp.setStatusCode(fakeResponseCode);
        }
        if (resp.getStatusCode() != 200) {
            throw new SegmentException('failed to report event to Segment\nrequest: ' + req.toString() + '\nresponse: ' + resp.toString());
        }
    }

    public void finish(Database.BatchableContext bc) {
        upsert timeKv;
        if (intervalMinutes > 0) {
            System.scheduleBatch(this, 'ShiftBatchProcessAnalytics', intervalMinutes);
        }
    }
}