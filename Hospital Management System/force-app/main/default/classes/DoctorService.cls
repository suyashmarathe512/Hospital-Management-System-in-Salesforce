/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   DoctorService
 * @Description: This Class exposed the Consultation to REST API.
 *****************************************************************************************************/
@RestResource(urlMapping='/DoctorService/*')
global with sharing class DoctorService{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getDoctors
 * @Description: queries the doctors from org.
 *****************************************************************************************************/
    @HttpGet
    global static List<Doctor__c> getDoctors(){
        return [SELECT
                    Id,Name,Specialization__c,Degree__c,Email__c,Mobile_Number__c,Consultation_Fees__c
                FROM
                    Doctor__c
                WITH
                    SECURITY_ENFORCED];
    }
}