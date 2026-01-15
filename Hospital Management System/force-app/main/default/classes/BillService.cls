@RestResource(urlMapping='/Bill/*')
global with sharing class BillService{
    @HttpGet
    global static void doGet(){
        RestRequest req=RestContext.request;
        RestResponse res=RestContext.response;
        String prescriptionId=req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        try{
            List<Bill__c> bills=[
                SELECT 
                    Id,Name,Billing_Date__c,Tax_Percentage__c,Sub_Total__c,Total_Amount__c,
                    Patient__c,Patient__r.Name,Patient__r.PersonEmail,
                    Consultation__c,Consultation__r.Name,Consultation__r.Doctor__r.Name,
                    Prescription__c,Prescription__r.Name,
                (SELECT 
                        Name,Medication__c,Medication__r.Name,Unit_Price__c,Quantity__c,Line_Total__c 
                    FROM 
                        Bill_Line_Items__r)
                FROM 
                    Bill__c
                WHERE 
                    Prescription__c=:prescriptionId
                LIMIT 1];
            if(bills.isEmpty()){
                res.statusCode=404;
                res.responseBody=Blob.valueOf('No Bill found for the given prescription ID.');
                return;
            }
            res.statusCode=200;
            res.responseBody=Blob.valueOf(JSON.serialize(bills[0]));
            res.headers.put('Content-Type','application/json');
        }catch(Exception e){
            res.statusCode=500;
            res.responseBody=Blob.valueOf('Error retrieving Bill: '+e.getMessage());
        }
    }
}
