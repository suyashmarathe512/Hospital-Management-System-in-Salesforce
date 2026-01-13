/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   PortalConsultationsController
 * @Description: Controller for the portal consultations view, handling data retrieval from the server.
 *****************************************************************************************************/
public with sharing class PortalConsultationsController{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getConsultations
 * @Description: Fetches consultation records from the server org using a REST callout.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getConsultations(String accountId){
        if(String.isBlank(accountId)){
            return new List<Map<String, Object>>();
        }
        List<Account> accs=[SELECT
                                External_Record_Id__c
                            FROM
                                Account
                            WHERE
                                Id=:accountId
                            WITH
                                SECURITY_ENFORCED LIMIT 1];
        if(accs.isEmpty()||String.isBlank(accs[0].External_Record_Id__c)){
            return new List<Map<String, Object>>();
        }
        HttpRequest req=new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/ConsultationsService/?ExternalRecordId='+EncodingUtil.urlEncode(accs[0].External_Record_Id__c, 'UTF-8'));
        req.setMethod('GET');
        Http http=new Http();
        HttpResponse res=http.send(req);
        if(res.getStatusCode()==200){
            List<Object> responseList=(List<Object>)JSON.deserializeUntyped(res.getBody());
            List<Map<String, Object>> wrappers=new List<Map<String, Object>>();
            for(Object obj:responseList){
                Map<String, Object> record=(Map<String, Object>)obj;
                Map<String, Object> w=new Map<String, Object>();
                w.put('Id', record.get('Id'));
                w.put('Name', record.get('Name'));
                w.put('Date_of_Visit__c', record.get('Date_of_Visit__c'));
                w.put('Visit_Charges__c', record.get('Visit_Charges__c'));
                w.put('Next_Visit__c', record.get('Next_Visit__c'));
                w.put('DoctorName', record.get('DoctorName'));

                wrappers.add(w);
            }
            return wrappers;
        }
        throw new CalloutException('Error fetching consultations: '+res.getStatus());
    }
}