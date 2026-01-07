/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   PrescriptionService
 * @Description: This Class exposed the Prescription__c to REST API.
 *****************************************************************************************************/
@RestResource(urlMapping='/prescriptions/*')
public with sharing class PrescriptionService{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getPrescriptions
 * @Description: This method queries the prescription from org.
 *****************************************************************************************************/
    @HttpGet
    global static List<Prescription__c> getPrescriptions(){
        return [SELECT
                    Id,Name,Total_Amount__c,Total_Medication_Amount__c,Notes__c,CreatedDate
                FROM
                    Prescription__c
                WITH
                    SECURITY_ENFORCED];
    }
}