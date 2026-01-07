/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName: PortalPrescriptionsController
 * @Description: Controller for the portal prescriptions view,handling data retrieval from the server.
 *****************************************************************************************************/
public with sharing class PortalPrescriptionsController{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName: getPrescriptions
 * @Description: Fetches prescription records from the server org using a REST callout.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Prescription__c> getPrescriptions(){
        HttpRequest req=new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/prescriptions/');
        req.setMethod('GET');
        Http http=new Http();
        HttpResponse res=http.send(req);
        if(res.getStatusCode()==200){
            return (List<Prescription__c>) JSON.deserialize(res.getBody(),List<Prescription__c>.class);
        }
        throw new CalloutException('Error fetching prescriptions: '+res.getStatus());
    }
}