public class skedGoogleAuthController {
    
    public List<sked__Resource__c> RelatedResources {get;set;}
    public List<SelectOption> Calendars {get;set;}
    
    public boolean isConnected {get;set;}
    public integer NoOfResources {
        get {
            return RelatedResources != NULL ? RelatedResources.size() : 0;
        }
    }
    
    private string baseUrl;
    private string oAuthRedirectUri;
    
    public skedGoogleAuthController() {
        getRelatedResources();
        isConnected = false;
        if (this.RelatedResources.size() > 0) {
            isConnected = !string.isBlank(this.RelatedResources.get(0).Google_Refresh_Token__c);
        }
        
        this.baseUrl = ApexPages.currentPage().getHeaders().get('Host');
        this.oAuthRedirectUri = 'https://' +  this.BaseURL + '/apex/skedGoogleAuth?mode=token';
    }
    
    public void Cmd_SaveCalendar() {
        update RelatedResources;
    }
    
    public void Cmd_Revoke() {
        for (sked__Resource__c resource : this.RelatedResources) {
            resource.Google_Access_Token__c = '';
            resource.Google_Refresh_Token__c = '';
            resource.Google_Calendar_Id__c = '';
            resource.Google_Token_Expire_On__c = NULL;
        }
        this.isConnected = false;
        update this.RelatedResources;
    }
    
    public pageReference Cmd_ConnectToGoogle() {
        sked_Google_Api_Settings__c googleApiSetting = GetGoogleApiSetting();
        
        string x = 'https://accounts.google.com/o/oauth2/auth' 
            + '?scope=' + EncodingUtil.urlEncode('https://www.googleapis.com/auth/calendar','UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(this.oAuthRedirectUri,'UTF-8')
            + '&response_type=code&client_id=' + googleApiSetting.Client_Id__c
            + '&approval_prompt=force'
            + '&access_type=offline';
        
        pageReference p = new pageReference(x);
        return p;
    }
    
    public pageReference Cmd_GetTokens() {
        string modeParam = apexPages.currentPage().getParameters().get('mode');
        if (!string.isBlank(modeParam) && modeParam == 'token') {
            isConnected = true;
            string codeParam = apexPages.currentPage().getParameters().get('code');
            if (!string.isBlank(codeParam)) {
                sked_Google_Api_Settings__c googleApiSetting = GetGoogleApiSetting();
                
                String body = 'code=' + codeparam
                    + '&client_id=' + googleApiSetting.Client_Id__c
                    + '&client_secret=' + googleApiSetting.Client_Secret__c 
                    + '&redirect_uri=' + EncodingUtil.urlEncode(this.oAuthRedirectUri,'UTF-8')
                    + '&grant_type=authorization_code';
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://accounts.google.com/o/oauth2/token');
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                req.setMethod('POST');
                req.setBody(body);
                
                try {
                    Http h = new Http();
                    HttpResponse res = h.send(req);
                    JSONParser parser = JSON.createParser(res.getBody());
                    
                    string access_token, refresh_token;
                    integer expiresIn;
                    while (parser.nextToken() != null) {
                        if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'access_token')) {
                            parser.nextToken();
                            access_token = parser.getText();
                        }
                        if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'refresh_token')) {
                            parser.nextToken();
                            refresh_token = parser.getText();
                        }
                        if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'expires_in')) {
                            parser.nextToken();
                            expiresIn = parser.getIntegerValue();
                        }
                    }
                    
                    for (sked__Resource__c resource : this.RelatedResources) {
                        resource.Google_Access_Token__c = access_token;
                        resource.Google_Refresh_Token__c = refresh_token;
                        if (expiresIn != NULL) {
                            resource.Google_Token_Expire_On__c = System.Now().addMinutes(-1).addSeconds(expiresIn);
                        }
                    }
                    getCalendarListWithToken(access_token);
                    
                    update this.RelatedResources;
                } 
                catch (Exception ex) {
                    system.debug('#error#' + ex.getMessage());
                    system.debug('#error#' + ex.getStackTraceString());
                }
            }
        } else {
            if (isConnected) {
                getCalendarList(this.RelatedResources.get(0).Id);
            }
        }
        return null;
    }
    
    private void getCalendarListWithToken(string accessToken) {
        skedGoogleData.CalendarList calendarList = skedGoogleCalendarCallouts.getCalendarListWithToken(accessToken);
        this.Calendars = new List<SelectOption>();
        this.Calendars.add(new SelectOption('', 'None'));
        if (calendarList != NULL && CalendarList.Items != NULL) {
            for (skedGoogleData.CalendarListItem item : calendarList.Items) {
                this.Calendars.add(new SelectOption(item.id, item.summary));
            }
        }
    }
    
    private void getCalendarList(string resourceId) {
        skedGoogleData.CalloutResult result = skedGoogleCalendarCallouts.getCalendarList(resourceId);
        this.Calendars = new List<SelectOption>();
        this.Calendars.add(new SelectOption('', 'None'));
        if (result.CalendarList != NULL && result.CalendarList.Items != NULL) {
            for (skedGoogleData.CalendarListItem item : result.CalendarList.Items) {
                this.Calendars.add(new SelectOption(item.id, item.summary));
            }
        }
    }
    
    private void getRelatedResources() {
        this.RelatedResources = [SELECT Id, Name, Google_Access_Token__c, Google_Calendar_Id__c, Google_Refresh_Token__c, Google_Token_Expire_On__c
                                 FROM sked__Resource__c 
                                 WHERE sked__User__c = :UserInfo.getUserId()];
    }
    
    private sked_Google_Api_Settings__c GetGoogleApiSetting() {
        return sked_Google_Api_Settings__c.getOrgDefaults();
    }
}