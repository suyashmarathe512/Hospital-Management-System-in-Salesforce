@RestResource(urlMapping='/DoctorService/*')
global with sharing class DoctorService {
    @HttpGet
    global static List<Doctor__c> getDoctors() {
        return [SELECT 
                    Id, Name, Specialization__c, Degree__c, Email__c, Mobile_Number__c, Consultation_Fees__c
                FROM 
                    Doctor__c
                WITH 
                    SECURITY_ENFORCED];
    }
}