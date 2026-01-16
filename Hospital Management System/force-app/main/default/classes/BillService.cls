@RestResource(urlMapping='/Bill/*')
global without sharing class BillService{
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
                ORDER BY
                    CreatedDate DESC
                LIMIT 1];
            if(bills.isEmpty()){
                res.statusCode=404;
                res.responseBody=Blob.valueOf('No Bill found for the given prescription ID.');
                return;
            }
            res.statusCode=200;
            
            // Convert SObject to Map to ensure child relationships are serialized as simple arrays
            Bill__c bill = bills[0];
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(bill));
            
            List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
            for(Bill_Line__c item : bill.Bill_Line_Items__r) {
                Map<String, Object> itemMap = new Map<String, Object>();
                itemMap.put('Id', item.Id);
                itemMap.put('Unit_Price__c', item.Unit_Price__c);
                itemMap.put('Quantity__c', item.Quantity__c);
                itemMap.put('Line_Total__c', item.Line_Total__c);
                if(item.Medication__r != null) {
                    itemMap.put('Medication__r', new Map<String, Object>{'Name' => item.Medication__r.Name});
                }
                lineItems.add(itemMap);
            }
            
            Map<String, Object> subqueryMap = new Map<String, Object>();
            subqueryMap.put('totalSize', lineItems.size());
            subqueryMap.put('done', true);
            subqueryMap.put('records', lineItems);
            result.put('Bill_Line_Items__r', subqueryMap);
            
            res.responseBody=Blob.valueOf(JSON.serialize(result));
            res.headers.put('Content-Type','application/json');
        }catch(Exception e){
            res.statusCode=500;
            res.responseBody=Blob.valueOf('Error retrieving Bill: '+e.getMessage());
        }
    }
}
