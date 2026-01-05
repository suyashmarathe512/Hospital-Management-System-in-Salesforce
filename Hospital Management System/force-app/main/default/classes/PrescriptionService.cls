@RestResource(urlMapping='/prescriptions/*')
public with sharing class PrescriptionService {
    @HttpGet
    global static List<Prescription__c> getPrescriptions() {
        return [SELECT 
                    Id, Name, Total_Amount__c, Total_Medication_Amount__c, Notes__c, CreatedDate
                FROM 
                    Prescription__c
                WITH 
                    SECURITY_ENFORCED];
    }
}