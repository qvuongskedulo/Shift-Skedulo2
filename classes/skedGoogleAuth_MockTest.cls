@isTest
global class skedGoogleAuth_MockTest implements HttpCalloutMock {
    
    global string calloutMethod {get;set;}

    global HTTPResponse respond(HTTPRequest req) {
		HttpResponse res = new HttpResponse();
        
        if (calloutMethod == 'Cmd_GetTokens') {
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"accessToken","refresh_token":"refreshToken","expires_in":3600}');
            res.setStatusCode(200);
        } 
        return res;
    }
    
}