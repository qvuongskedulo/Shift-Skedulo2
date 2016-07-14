global class skedSkeduloApiData {

    global class ApiResponse {
        public string jobId {get;set;}
        public string resourceId {get;set;}
        public DateTime dts {get;set;}
        public string protocol {get;set;}
        public boolean success {get;set;}
        public string referenceId {get;set;}
        public string errorMessage {get;set;}
        public string errorCode {get;set;}
    }
    
}