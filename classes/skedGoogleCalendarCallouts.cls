public class skedGoogleCalendarCallouts {
    
    public static skedGoogleData.CalloutResult createEvent(skedGoogleData.Item eventModel, string resourceId) {
        sked__Resource__c resource = [SELECT Id, Name, Google_Access_Token__c, Google_Calendar_Id__c, Google_Refresh_Token__c, Google_Token_Expire_On__c
                                      FROM sked__Resource__c 
                                      WHERE Id = :resourceId];
        return createEvent(eventModel, resource);
    }
    
    public static skedGoogleData.CalloutResult createEvent(skedGoogleData.Item eventModel, sked__Resource__c resource) {
        skedGoogleData.CalloutResult result = getToken(resource);
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('content-type', 'application/json');
        string requestString = 'https://www.googleapis.com/calendar/v3/calendars/' + result.Resource.Google_Calendar_Id__c + '/events?access_token=' + result.accessToken;
        string body = Json.serialize(eventModel);
        body = body.replace('"dateTimeValue"', '"dateTime"');
        body = body.replace('"eventEnd"', '"end"');
        req.setBody(body);
        req.setEndpoint(requestString);
        req.setMethod('POST');
        req.setTimeout(60000);
        
        try {
            HttpResponse res = h.send(req);
            string jsonResult = res.getBody();
            result.GoogleEvent = (skedGoogleData.Item)(Json.deserialize(jsonResult, skedGoogleData.Item.class));
            if (result.GoogleEvent.Id == NULL) {
                result.HasError = true;
                skedGoogleData.ErrorRootObject googleError = (skedGoogleData.ErrorRootObject)(Json.deserialize(jsonResult, skedGoogleData.ErrorRootObject.class));
                result.ErrorMessage = googleError.Error.message;
            }
        } catch (Exception e) {
            result.HasError = true;
            result.ErrorMessage = e.getMessage() + '\n' + e.getStackTraceString();
        }
        return result;
    }
    
    public static skedGoogleData.CalloutResult createEvent(string jobId, string resourceId) {
        skedGoogleData.Item eventModel = createGoogleEventModel(jobId);
        return createEvent(eventModel, resourceId);
    }
    
    public static skedGoogleData.CalloutResult updateEvent(skedGoogleData.Item eventModel, string resourceId) {
        sked__Resource__c resource = [SELECT Id, Name, Google_Access_Token__c, Google_Calendar_Id__c, Google_Refresh_Token__c, Google_Token_Expire_On__c
                                      FROM sked__Resource__c 
                                      WHERE Id = :resourceId];
        return updateEvent(eventModel, resource);
    }
    
    public static skedGoogleData.CalloutResult updateEvent(skedGoogleData.Item eventModel, sked__Resource__c resource) {
        skedGoogleData.CalloutResult result = getToken(resource);
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('content-type', 'application/json');
        string requestString = 'https://www.googleapis.com/calendar/v3/calendars/' + result.Resource.Google_Calendar_Id__c + '/events/' + eventModel.id + '?access_token=' + result.AccessToken;
        string body = Json.serialize(eventModel);
        body = body.replace('"dateTimeValue"', '"dateTime"');
        body = body.replace('"eventEnd"', '"end"');
        req.setBody(body);
        req.setEndpoint(requestString);
        req.setMethod('PUT');
        req.setTimeout(60000);
        
        try {
            HttpResponse res = h.send(req);
            string jsonResult = res.getBody();
            result.GoogleEvent = (skedGoogleData.Item)(Json.deserialize(jsonResult, skedGoogleData.Item.class));
            if (result.GoogleEvent.Id == NULL) {
                result.HasError = true;
                skedGoogleData.ErrorRootObject googleError = (skedGoogleData.ErrorRootObject)(Json.deserialize(jsonResult, skedGoogleData.ErrorRootObject.class));
                result.ErrorMessage = googleError.Error.message;
            }
        } catch (Exception e) {
            result.HasError = true;
            result.ErrorMessage = e.getMessage() + '\n' + e.getStackTraceString();
        }
        return result;
    }
    
    public static skedGoogleData.CalloutResult updateEvent(string jobId, string resourceId) {
        skedGoogleData.Item eventModel = createGoogleEventModel(jobId);
        return updateEvent(eventModel, resourceId);
    }
    
    public static skedGoogleData.CalloutResult deleteEvent(skedGoogleData.Item eventModel, string resourceId) {
        sked__Resource__c resource = [SELECT Id, Name, Google_Access_Token__c, Google_Calendar_Id__c, Google_Refresh_Token__c, Google_Token_Expire_On__c
                                      FROM sked__Resource__c 
                                      WHERE Id = :resourceId];
        return deleteEvent(eventModel, resource);
    }
    
    public static skedGoogleData.CalloutResult deleteEvent(skedGoogleData.Item eventModel, sked__Resource__c resource) {
        skedGoogleData.CalloutResult result = getToken(resource);
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('content-type', 'application/json');
        string requestString = 'https://www.googleapis.com/calendar/v3/calendars/' + result.Resource.Google_Calendar_Id__c + '/events/' + eventModel.id + '?access_token=' + result.AccessToken;
        req.setEndpoint(requestString);
        req.setMethod('DELETE');
        req.setTimeout(60000);
        
        try {
            HttpResponse res = h.send(req);
            string jsonResult = res.getBody();
            if (!string.isBlank(jsonResult)) {
                result.HasError = true;
                skedGoogleData.ErrorRootObject googleError = (skedGoogleData.ErrorRootObject)(Json.deserialize(jsonResult, skedGoogleData.ErrorRootObject.class));
                result.ErrorMessage = googleError.Error.message;
            }
        } catch (Exception e) {
            result.HasError = true;
            result.ErrorMessage = e.getMessage() + '\n' + e.getStackTraceString();
        }
        return result;
    }
    
    public static skedGoogleData.CalloutResult deleteEvent(string jobId, string resourceId) {
        skedGoogleData.Item eventModel = createGoogleEventModel(jobId);
        return deleteEvent(eventModel, resourceId);
    }
    
    public static skedGoogleData.Calendar getCalendar(string calendarId, DateTime startTime, DateTime endTime) {
        sked_Google_Api_Settings__c setting = GetGoogleApiSetting();
        if (string.isBlank(setting.Server_Key__c)) {
            return null;
        }
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        string requestString = 'https://www.googleapis.com/calendar/v3/calendars/' + calendarId + '/events?key=' + setting.Server_Key__c; 
        string timeMin = json.serialize(startTime).remove('"');
        requestString += '&timeMin=' + timeMin;
        string timeMax = json.serialize(endTime).remove('"');
        requestString += '&timeMax=' + timeMax;
        
        req.setEndpoint(requestString);
        req.setMethod('GET');
        req.setTimeout(60000);
        
        try {
            HttpResponse res = h.send(req);
            string jsonResultString = res.getBody();
            jsonResultString = jsonResultString.replace('"dateTime"', '"dateTimeValue"');
            jsonResultString = jsonResultString.replace('"date"', '"dateValue"');
            jsonResultString = jsonResultString.replace('"end"', '"EventEnd"');
            skedGoogleData.Calendar calendar = (skedGoogleData.Calendar)(JSON.deserialize(jsonResultString, skedGoogleData.Calendar.class));
            return calendar;
        } catch (Exception e) {
            system.debug('#error#' + e.getMessage());
        }
        
        return null;
    }
    
    public static skedGoogleData.CalloutResult getCalendarList(string resourceId) {
        skedGoogleData.CalloutResult result = getToken(resourceId);
        
        result.CalendarList = getCalendarListWithToken(result.accessToken);
        
        return result;
    }
    
    public static skedGoogleData.CalendarList getCalendarListWithToken(string accessToken) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        string requestString = 'https://www.googleapis.com/calendar/v3/users/me/calendarList'; 
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setEndpoint(requestString);
        req.setMethod('GET');
        req.setTimeout(60000);
        try {
            HttpResponse res = h.send(req);
            string jsonResultString = res.getBody();
            skedGoogleData.CalendarList calendarList = (skedGoogleData.CalendarList)(JSON.deserialize(jsonResultString, skedGoogleData.CalendarList.class));
            return calendarList;
        } catch (Exception ex) {
            system.debug('#error#' + ex.getMessage());
            system.debug('#error#' + ex.getStackTraceString());
        }
        return null;
    }    
    
    public static skedGoogleData.Item createGoogleEventModel(string jobId) {
        sked__job__c job = [SELECT ID, Name, sked__Start__c, sked__Finish__c, sked__Account__r.Name, sked__Contact__r.Name, sked__Address__c,Google_Event_Id__c,
                            (SELECT sked__Resource__r.Google_Calendar_Id__c
                             FROM sked__Job_Allocations__r)
                            FROM sked__Job__c
                            WHERE Id = :jobId];
        
        return createGoogleEventModel(job);
    }
    
    public static skedGoogleData.Item createGoogleEventModel(sked__Job__c job) {
        skedGoogleData.Item model = new skedGoogleData.Item();
        if (!string.isBlank(job.Google_Event_Id__c)) {
            model.id = job.Google_Event_Id__c;
        }
        model.summary = '';
        model.summary += job.sked__Start__c.format('h:mma', job.sked__Timezone__c);
        model.summary += ' - ' + job.sked__Type__c;
        model.summary += ' - ' + job.Vehicle_Name__c;
        model.summary += ' - ' + job.sked__Contact__r.Name;   
        model.summary += ' - ' + job.sked__Contact__r.MailingCity;

        model.location = job.sked__Address__c;

        model.start.dateTimeValue = job.Departure_Time__c;
        model.eventEnd.dateTimeValue = job.Return_Time__c;

        model.description = '';
        model.description += 'Vehicle Name: ' + job.Vehicle_Name__c + '\n';
        model.description += 'Opportunity Name: ' + job.Opportunity_Name__c + '\n';
        model.description += 'Customer Contact Name: ' + job.sked__Contact__r.Name + '\n';
        model.description += 'Customer Phone Number: ' + job.sked__Contact__r.Phone + '\n';
        model.description += 'Customer Email Address: ' + job.sked__Contact__r.Email + '\n';
        model.description += 'Start Time: ' + job.sked__Start__c.format('h:mma', job.sked__Timezone__c) + '\n';
        model.description += 'Duration: ' + job.sked__Duration__c + '\n';
        model.description += 'Transmission: ' + job.Manual__c + '\n';
        model.description += 'Number Of Owners: ' + job.Number_of_Owners__c + '\n';
        model.description += 'Number Of Accidents: ' + job.Number_of_Accidents__c + '\n';
        model.description += 'Guaranteed Price: ' + job.Guaranteed_Price__c + '\n';
        model.description += 'Quoted Sale Price: ' + job.Quoted_Sale_Price__c + '\n';
        model.description += 'Quoted Projected In Pocket: ' + job.Quoted_Projected_In_Pocket__c + '\n';
        model.description += 'Pickup Probability: ' + job.Pick_up_probability__c + '\n';
        model.description += 'Is Aware Of Advance Funds Qualification: ' + job.Is_Aware_Of_Advance_Funds_Qualification__c + '\n';
        model.description += 'Advance Funds Status: ' + job.Advance_Funds_Status__c;

        return model;
    }
    
    public static skedGoogleData.Item createGoogleEventModel(sked_Google_Event__c skedGoogleEvent) {
        skedGoogleData.Item model = new skedGoogleData.Item();
        if (!string.isBlank(skedGoogleEvent.Event_Id__c)) {
            model.id = skedGoogleEvent.Event_Id__c;
        }
        model.summary = skedGoogleEvent.Summary__c;
        model.description = skedGoogleEvent.Description__c;
        model.location = skedGoogleEvent.Location__c;
        model.start.dateTimeValue = skedGoogleEvent.Start__c;
        model.eventEnd.dateTimeValue = skedGoogleEvent.Finish__c;
        
        return model;
    }
    
    public static void UpdateTokenIfExpired(List<skedGoogleData.CalloutResult> resultList) {
        Map<Id, sked__Resource__c> resourcesToUpdate = new Map<Id, sked__Resource__c>();
        for (skedGoogleData.CalloutResult result : resultList) {
            if (result != NULL && result.Resource != NULL && result.ExpiresIn > 0)  {
                if (resourcesToUpdate.containsKey(result.Resource.Id)) {
                    continue;
                }
                result.Resource.Google_Access_Token__c = result.AccessToken;
                result.Resource.Google_Token_Expire_On__c = System.Now().addMinutes(-1).addSeconds(result.ExpiresIn);
                resourcesToUpdate.put(result.Resource.Id, result.Resource);
            }
        }
        if (resourcesToUpdate.size() > 0) {
            update resourcesToUpdate.values();
        }
    }
    
   /**************************** Private methods ****************************/ 
    
    private static sked_Google_Api_Settings__c getGoogleApiSetting() {
        return sked_Google_Api_Settings__c.getOrgDefaults();
    }
    
    private static skedGoogleData.CalloutResult getToken(string resourceId) {
        sked__Resource__c resource = [SELECT Id, Name, Google_Access_Token__c, Google_Calendar_Id__c, Google_Refresh_Token__c, Google_Token_Expire_On__c
                                      FROM sked__Resource__c 
                                      WHERE Id = :resourceId];
        return getToken(resource);
    }
    
    private static skedGoogleData.CalloutResult getToken(sked__Resource__c resource) {
        skedGoogleData.CalloutResult result = new skedGoogleData.CalloutResult();
        if (resource.Google_Token_Expire_On__c < system.now()) {
            result = refreshToken(resource);
        } else {
            result.AccessToken = resource.Google_Access_Token__c;
            result.Resource = resource;
        }
        return result;
    }
    
    public static skedGoogleData.CalloutResult refreshToken(sked__Resource__c resource) {
        sked_Google_Api_Settings__c googleApiSetting = GetGoogleApiSetting();
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        string body = 'client_id=' + EncodingUtil.urlEncode(googleApiSetting.Client_Id__c, 'UTF-8');
        body += '&client_secret=' + EncodingUtil.urlEncode(googleApiSetting.Client_Secret__c, 'UTF-8');
        body += '&refresh_token=' + EncodingUtil.urlEncode(resource.Google_Refresh_Token__c, 'UTF-8');
        body += '&grant_type=refresh_token';
        
        req.setHeader('content-type', 'application/x-www-form-urlencoded');
        req.setBody(body);
        req.setEndpoint('https://www.googleapis.com/oauth2/v3/token');
        req.setMethod('POST');
        req.setTimeout(60000);
        
        skedGoogleData.CalloutResult result = new skedGoogleData.CalloutResult();
        result.Resource = resource;
        try {
            HttpResponse res = h.send(req);
            JSONParser parser = JSON.createParser(res.getBody());
            
            string access_token;
            integer expiresIn;
            while (parser.nextToken() != null) {
                if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'access_token')) {
                    parser.nextToken();
                    access_token = parser.getText();
                }
                if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'expires_in')) {
                    parser.nextToken();
                    expiresIn = parser.getIntegerValue();
                }
            }
            
            result.AccessToken = access_token;
            result.ExpiresIn = expiresIn;
            
            return result;
            
        } catch (Exception e) {
            result.HasError = true;
            result.ErrorMessage = e.getMessage() + '\n' + e.getStackTraceString();
            system.debug('#error#' + result.ErrorMessage);
        }
        return null;
    }
    
}