global class skedLocationService {
    
    @future(callout=true)
    global static void updateActivityGeoLocation(String idList) {
        string[] recordIds = idList.split(';');
        List<sked__Activity__c> activities = [SELECT Id, sked__Address__c
                                              FROM sked__Activity__c
                                              WHERE Id IN :recordIds];
        
        for (sked__Activity__c activity : activities) {
            Location geoData = skedLocationService.getAddressGeoLocation(activity.sked__Address__c);
            if (geoData != null) {
                activity.sked__GeoLocation__latitude__s = geoData.getLatitude();
                activity.sked__GeoLocation__longitude__s = geoData.getLongitude(); 
            }
        }
        update activities;
    }
    
    @future(callout=true)
    global static void updateGeoLocation(String idList, string objectType) {
        string[] recordIds = idList.split(';');
        List<sObject> records = new List<sObject>();
        
        if (objectType == 'evaluation') {   
            records = [SELECT Id, Location__c FROM Evaluation__c WHERE Id IN :recordIds];
        } else if (objectType == 'testdrive') { 
            records = [SELECT Id, Location__c FROM Test_Drive__c WHERE Id IN :recordIds];
        } else if (objectType == 'delivery') {  
            records = [SELECT Id, Location__c FROM Delivery__c WHERE Id IN :recordIds];
        } else if (objectType == 'pickup') {    
            records = [SELECT Id, Location__c FROM Pick_Up__c WHERE Id IN :recordIds];
        } else {
            return;
        }
        
        for (sObject record : records) {
            system.debug('#record#' + record);
            string address = string.valueOf(record.get('Location__c'));
            if (string.isBlank(address)) {
                record.put('GeoLocation__latitude__s', null);
                record.put('GeoLocation__longitude__s', null);
                continue;
            }
            Location geoData = skedLocationService.getAddressGeoLocation(address);
            if (geoData != null) {
                record.put('GeoLocation__latitude__s', geoData.getLatitude());
                record.put('GeoLocation__longitude__s', geoData.getLongitude());    
            }
        }
        update records;
    }
    
    global static Location getAddressGeoLocation(string addr) {
        Location geoLoc = new Location();
        if (string.isBlank(addr)){
            return null;
        }
        Http http           = new Http();
        HttpRequest req     = new HttpRequest(); 
        HttpResponse res    = new HttpResponse();
        
        Skedulo_API_Setting__c skeduloApiSetting = Skedulo_API_Setting__c.getOrgDefaults();
        if (string.isBlank(skeduloApiSetting.API_Token__c)) {
            system.debug('#Skedulo API Error: API Token is null#');
            return geoLoc;
        }
        
        //Set end point to Authenciate
        string EndPoint = 'https://app.skedulo.com/suggest/api/geocode?';
        string params = EncodingUtil.urlEncode(addr, 'UTF-8');
        EndPoint = EndPoint+ 'addrs=' + params;
        system.debug(EndPoint);
        req.setEndpoint( EndPoint );
        req.setMethod('GET');
        req.setTimeout(10000);               
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('apiToken', skeduloApiSetting.API_Token__c);
        
        integer responseCode = 0;
        string jsonResponse = ''; 
        
        res = http.send(req);
        responseCode = res.getStatusCode(); 
        
        if (responseCode == 200) {
            try {
                jsonResponse = res.getBody();
                map<string,object> selectedSlot = (map<string,object>)System.JSON.deserializeUntyped(jsonResponse);
                
                Map<String, Object> p = (Map<String, Object>) (selectedSlot.values()[0]);
                geoLoc = Location.newInstance((double)p.get('lat'),(double)p.get('lng'));
                return geoLoc;
            } 
            catch(Exception ex) {
                system.debug('#exception=' + ex);
                system.debug('#trace=' + ex.getStackTraceString());
            }
        } 
        return null;
    }
    
}