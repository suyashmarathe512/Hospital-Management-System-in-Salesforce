/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   ConsultationsService
 * @Description: This Class exposed the Consultation to REST API.
 *****************************************************************************************************/
@RestResource(urlMapping='/ConsultationsService/*')
global with sharing class ConsultationsService{
    @HttpGet
    global static void getConsultations(){
        RestRequest req = RestContext.request;
        RestResponse response = RestContext.response;
        String patientId = req.params.get('ExternalRecordId');
        if(String.isBlank(patientId)){
            response.responseBody = Blob.valueOf('[]');
            response.addHeader('Content-Type', 'application/json');
            return;
        }
        List<Consultation__c> consultations = [SELECT
                    Id,Name,Date_of_Visit__c,Doctor__c,Doctor__r.Name,Next_Visit__c,Patient__c,Patient__r.Name,Visit_Charges__c
                FROM
                    Consultation__c
                WHERE
                    Patient__c = :patientId
                WITH
                    SECURITY_ENFORCED];
        
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for(Consultation__c c : consultations){
            Map<String, Object> res = new Map<String, Object>();
            res.put('Id', c.Id);
            res.put('Name', c.Name);
            res.put('Date_of_Visit__c', c.Date_of_Visit__c);
            res.put('Visit_Charges__c', c.Visit_Charges__c);
            res.put('Next_Visit__c', c.Next_Visit__c);
            res.put('DoctorName', c.Doctor__r != null ? c.Doctor__r.Name : '');
            results.add(res);
        }
        response.responseBody = Blob.valueOf(JSON.serialize(results));
        response.addHeader('Content-Type', 'application/json');
    }
}