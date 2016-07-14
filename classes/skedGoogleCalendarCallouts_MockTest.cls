@isTest
global class skedGoogleCalendarCallouts_MockTest implements HttpCalloutMock {
    
    global string calloutMethod {get;set;}
    
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        
        if (calloutMethod == 'createEvent' || calloutMethod == 'updateEvent') {
            res.setHeader('Content-Type', 'application/json');
            skedGoogleData.Item result = new skedGoogleData.Item();
            result.id = 'id';
            result.summary = 'event summary';
            res.setBody(Json.serialize(result));
            res.setStatusCode(200);
        } 
        else if (calloutMethod == 'deleteEvent') {
            res.setHeader('Content-Type', 'application/json');
            res.setBody('');
            res.setStatusCode(200);
        } 
        else if (calloutMethod == 'createEvent_Error' || calloutMethod == 'updateEvent_Error') {
            res.setHeader('Content-Type', 'application/json');
            skedGoogleData.Item result = new skedGoogleData.Item();
            res.setBody(Json.serialize(result));
            res.setStatusCode(200);
        }
        else if (calloutMethod == 'deleteEvent_Error') {
            res.setHeader('Content-Type', 'application/json');
            skedGoogleData.ErrorRootObject result = new skedGoogleData.ErrorRootObject();
            result.Error = new skedGoogleData.Error();
            result.Error.message = 'Error';
            res.setBody(Json.serialize(result));
            res.setStatusCode(200);
        }
        else if (calloutMethod == 'getCalendar') {
            res.setHeader('Content-Type', 'application/json');
            skedGoogleData.Calendar result = new skedGoogleData.Calendar();
            skedGoogleData.Item item1 = new skedGoogleData.Item();
            item1.id = 'item1id';
            result.items.add(item1);
            res.setBody(Json.serialize(result));
            res.setStatusCode(200);
        }
        else if (calloutMethod == 'getCalendarList') {
            res.setHeader('Content-Type', 'application/json');
            skedGoogleData.CalendarList result = new skedGoogleData.CalendarList();
            skedGoogleData.CalendarListItem item1 = new skedGoogleData.CalendarListItem();
            item1.id = 'item1id';
            result.items.add(item1);
            res.setBody(Json.serialize(result));
            res.setStatusCode(200);
        }
        else if (calloutMethod == 'refreshToken') {
            res.setHeader('Content-Type', 'application/json');
            RefreshTokenObject refreshToken = new RefreshTokenObject();
            refreshToken.access_token = 'ya29.pAKW8SB6cw6C7KYC4bxBazDz-1rsaTUNVU-VWD73IZ8bWkJ4t3N3hOC7r7j0V2j_0g';
            refreshToken.token_type = 'Bearer';
            refreshToken.expires_in = 3600;
            res.setBody(Json.serialize(refreshToken));
            res.setStatusCode(200);
        }
        
        return res;
    }
    
    public class RefreshTokenObject {
        public string access_token {get;set;}
        public string token_type {get;set;}
        public integer expires_in {get;set;}	
    }
    
}