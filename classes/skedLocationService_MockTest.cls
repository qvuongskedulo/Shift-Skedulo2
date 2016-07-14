@isTest
global class skedLocationService_MockTest implements HttpCalloutMock {
    
    global string calloutMethod {get;set;}
    
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        
        res.setHeader('Content-Type', 'application/json');
        map<string, object> result = new map<string,object>();
        result.put('lat', '34,123456');
        result.put('lng', '-122,123456');
        res.setBody(Json.serialize(result));
        res.setStatusCode(200);
        
        return res;
    }
    
}