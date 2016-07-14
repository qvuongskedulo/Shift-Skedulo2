public class skedGoogleMapCallouts {
    
    private static integer count;
    private static long executionTime;
    private static Map<integer, long> mapExecutions;
    
    static public skedGoogleData.DirectionCalloutResult getDirections(Location fromLocation, Location toLocation, long departureTime) {
        if (fromLocation != NULL && toLocation != NULL) {
            string fromLocationString = fromLocation.getLatitude() + ',' + fromLocation.getLongitude();
            string toLocationString = toLocation.getLatitude() + ',' + toLocation.getLongitude();
            
            return getDirections(fromLocationString, toLocationString, departureTime);
        }
        return NULL;
    }

    static public skedGoogleData.DirectionCalloutResult getDirections(string fromLocation, string toLocation, long departureTime) {
        if (count == NULL) {
            count = 0;
        }
        count++;
        executionTime = system.now().getTime();
        if (mapExecutions == NULL) {
            mapExecutions = new Map<integer, long>();
        }
        if (count > 10) {
            long last10execution = mapExecutions.get(count - 10);
            while (executionTime < last10execution + 1000) {
                executionTime = system.now().getTime();
            }
        }
        mapExecutions.put(count, executionTime);
        
        skedGoogleData.DirectionCalloutResult result = new skedGoogleData.DirectionCalloutResult();
        // build callout
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        string requestString = 'https://maps.googleapis.com/maps/api/directions/json?origin=' + fromLocation + '&destination=' + toLocation + '&sensor=false&mode=driving';
        if (departureTime > 0) {
            requestString += '&traffic_model=pessimistic&departure_time=' + departureTime; 
        }
        sked_Google_Api_Settings__c googleApiSetting = sked_Google_Api_Settings__c.getOrgDefaults();
        if (!string.isBlank(googleApiSetting.Server_Key__c)) {
            requestString += '&key=' + googleApiSetting.Server_Key__c;
        }
        req.setEndpoint(requestString);
        req.setMethod('GET');
        req.setTimeout(60000);
        system.debug('#Google Map Request#' + requestString);
        try {
            HttpResponse res = h.send(req);
            string jsonResult = res.getBody();
            result = (skedGoogleData.DirectionCalloutResult)(Json.deserialize(jsonResult, skedGoogleData.DirectionCalloutResult.class));
            if (result.status != 'OK') {
                result.HasError = true;
                result.ErrorMessage = result.status;
            } else {
                result.HasError = false;
            }
            return result;
        } catch (Exception e) {
            result.HasError = true;
            result.ErrorMessage = e.getMessage() + '\n' + e.getStackTraceString();
        }
        
        return null;
    }
    
    static public integer getDurationInMinutes(skedGoogleData.DirectionCalloutResult result) {
        if (result != NULL) {
            if (result.routes != NULL && result.routes.size() > 0) {
                skedGoogleData.Route route = result.routes.get(0);
                if (route.legs != NULL && route.legs.size() > 0) {
                    skedGoogleData.Leg leg = route.legs.get(0);
                    if (leg.duration_in_traffic != NULL) {
                        integer secondsInTraffic = leg.duration_in_traffic.Value;
                        integer durationInTraffic = integer.valueOf(Math.ceil(double.valueOf(secondsInTraffic) / 60));
                        
                        if (leg.duration != NULL) {
                            integer seconds = leg.duration.Value;
                            integer duration = integer.valueOf(Math.ceil(double.valueOf(seconds) / 60));
                            return integer.valueOf(Math.ceil(0.5 * duration + 0.5 * durationInTraffic));
                        }
                        else {
                            return durationInTraffic;
                        }
                    }
                }
            }
        }
        return NULL;
    }
}