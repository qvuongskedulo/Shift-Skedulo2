global class skedSkeduloApiManager {
    
    @future(callout=true)
    global static void sendDispatchNotification(string jobId, string resourceId) {
        skedSkeduloApiData.ApiResponse result = dispatch(jobId, resourceId);
        
        if (result.success == FALSE) {
            List<sked__Job__c> jobResults = [SELECT Id, Skedulo_API_Error__c, Skedulo_API_Error_Message__c
                                             FROM sked__Job__c
                                             WHERE Id = :jobId];
            if (jobResults != NULL && jobResults.size() > 0) {
                sked__Job__c job = jobResults.get(0);
                job.Skedulo_API_Error__c = TRUE;
                job.Skedulo_API_Error_Message__c = '';
                if (!string.isBlank(result.errorCode)) {
                    job.Skedulo_API_Error_Message__c += 'Error Code: ';
                    job.Skedulo_API_Error_Message__c += result.errorCode;
                    job.Skedulo_API_Error_Message__c += '\n';
                }
                if (!string.isBlank(result.errorMessage)) {
                    job.Skedulo_API_Error_Message__c += 'Error Message: ';
                    job.Skedulo_API_Error_Message__c += result.errorMessage;
                }
                update job;
            }
        }
    }

    global static skedSkeduloApiData.ApiResponse dispatch(string jobId, string resourceId) {
        skedSkeduloApiData.ApiResponse result = new skedSkeduloApiData.ApiResponse();
        Http http           = new Http();
        HttpRequest req     = new HttpRequest(); 
        HttpResponse res    = new HttpResponse();
        
        if (string.isBlank(jobId) || string.isBlank(resourceId)) {
            result.success = FALSE;
            result.errorMessage = 'Invalid jobId/resourceId.';
            return result;
        }
        
        Skedulo_API_Setting__c skeduloApiSetting = Skedulo_API_Setting__c.getOrgDefaults();
        if (string.isBlank(skeduloApiSetting.API_Token__c)) {
            result.success = FALSE;
            result.errorMessage = 'Skedulo API Error: API Token is null.';
            return result;
        }
        
        //Set end point to Authenciate
        string EndPoint = 'https://app.skedulo.com/dispatch?';
        string jobParams = EncodingUtil.urlEncode(jobId, 'UTF-8');
        EndPoint = EndPoint + 'job=' + jobParams;
        
        if (!string.isBlank(resourceId)) {
            string resourceParams = EncodingUtil.urlEncode(resourceId, 'UTF-8');
            EndPoint = EndPoint + '&resource=' + resourceParams;
        }
        
        req.setEndpoint( EndPoint );
        req.setMethod('POST');
        req.setTimeout(20000);               
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('apiToken', skeduloApiSetting.API_Token__c);
        
        string jsonResponse;
        try {
            res = http.send(req);
            jsonResponse = res.getBody();
            
            Map<string, object> deserializedResponse = (Map<string, object>)Json.deserializeUntyped(jsonResponse);
            Map<string, object> resultsObject = (Map<string, object>)deserializedResponse.get('results');
            
            string resourceResponseString = Json.serialize(resultsObject.get(resourceId));
            result = (skedSkeduloApiData.ApiResponse)Json.deserialize(resourceResponseString, skedSkeduloApiData.ApiResponse.class);
        } 
        catch (JSONException jsonEx) {
            result.success = FALSE;
            result.errorMessage = 'An error happend in Skeudlo Server. Please contact administrator.';
            result.errorMessage += (' Json Response: ' + jsonResponse);
        }
        catch(Exception ex) {
            result.success = FALSE;
            result.errorMessage = ('Error: ' + ex.getMessage());
            result.errorMessage += (' Stack Trace: ' + ex.getStackTraceString());
        }
        return result;
    }
    
    @future(callout=true)
    global static void sendCancelNotification(string jobId) {
        skedSkeduloApiData.ApiResponse result = notifyCancel(jobId);
        if (result.success == FALSE) {
            List<sked__Job__c> jobResults = [SELECT Id, Skedulo_API_Error__c, Skedulo_API_Error_Message__c
                                             FROM sked__Job__c
                                             WHERE Id = :jobId];
            if (jobResults != NULL && jobResults.size() > 0) {
                sked__Job__c job = jobResults.get(0);
                job.Skedulo_API_Error__c = TRUE;
                job.Skedulo_API_Error_Message__c = '';
                if (!string.isBlank(result.errorCode)) {
                    job.Skedulo_API_Error_Message__c += 'Error Code: ';
                    job.Skedulo_API_Error_Message__c += result.errorCode;
                    job.Skedulo_API_Error_Message__c += '\n';
                }
                if (!string.isBlank(result.errorMessage)) {
                    job.Skedulo_API_Error_Message__c += 'Error Message: ';
                    job.Skedulo_API_Error_Message__c += result.errorMessage;
                }
                update job;
            }
        }
    }
    
    global static skedSkeduloApiData.ApiResponse notifyCancel(string jobId) {
        skedSkeduloApiData.ApiResponse result = new skedSkeduloApiData.ApiResponse();
        Http http           = new Http();
        HttpRequest req     = new HttpRequest(); 
        HttpResponse res    = new HttpResponse();
        
        if (string.isBlank(jobId)) {
            result.success = FALSE;
            result.errorMessage = 'Invalid jobId.';
            return result;
        }
        
        Skedulo_API_Setting__c skeduloApiSetting = Skedulo_API_Setting__c.getOrgDefaults();
        if (string.isBlank(skeduloApiSetting.API_Token__c)) {
            result.success = FALSE;
            result.errorMessage = 'Skedulo API Error: API Token is null.';
            return result;
        }
        
        //Set end point to Authenciate
        string EndPoint = 'https://app.skedulo.com/notifyCancel?';
        string jobParams = EncodingUtil.urlEncode(jobId, 'UTF-8');
        EndPoint = EndPoint + 'job=' + jobParams;
        
        req.setEndpoint( EndPoint );
        req.setMethod('POST');
        req.setTimeout(20000);               
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('apiToken', skeduloApiSetting.API_Token__c);
        
        string jsonResponse;
        try {
            res = http.send(req);
            jsonResponse = res.getBody();
            
            Map<string, object> deserializedResponse = (Map<string, object>)Json.deserializeUntyped(jsonResponse);
            Map<string, object> resultsObject = (Map<string, object>)deserializedResponse.get('results');
            
            if (resultsObject != NULL && resultsObject.values() != NULL && resultsObject.values().size() > 0) {
                string responseString = Json.serialize(resultsObject.values().get(0));
                result = (skedSkeduloApiData.ApiResponse)Json.deserialize(responseString, skedSkeduloApiData.ApiResponse.class);
            }
            else {
                result.success = FALSE;
                result.errorMessage = 'An error happend in Skeudlo Server. Please contact administrator.';
                result.errorMessage += (' Json Response: ' + jsonResponse);
            }
        } 
        catch (JSONException jsonEx) {
            result.success = FALSE;
            result.errorMessage = 'An error happend in Skeudlo Server. Please contact administrator.';
            result.errorMessage += (' Json Response: ' + jsonResponse);
        }
        catch(Exception ex) {
            result.success = FALSE;
            result.errorMessage = ('Error: ' + ex.getMessage());
            result.errorMessage += (' Stack Trace: ' + ex.getStackTraceString());
        }
        return result;
    }
    
}