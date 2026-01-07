/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   ConsultationsService
 * @Description: This Class exposed the Consultation to REST API.
 *****************************************************************************************************/
@RestResource(urlMapping='/ConsultationsService/*')
global with sharing class ConsultationsService{
    @HttpGet
    global static List<Consultation__c> getConsultations(){
        return [SELECT 
                    Id,Name,Date_of_Visit__c,Doctor__c,Next_Visit__c,Patient__c,Visit_Charges__c
                FROM 
                    Consultation__c
                WITH 
                    SECURITY_ENFORCED];
    }
}