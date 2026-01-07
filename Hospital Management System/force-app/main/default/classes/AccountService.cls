/*****************************************************************************************************
 * @Author:      CRM Team Innovation
 * @ClassName:   AccountService
 * @Description: This Class belongs to Server Org, where the data is being synced from Client Org to Server Org.
 *               This class is responsible for creating/updating Account records in Server Org.
 **************************************************************************************************************/
@RestResource(urlMapping='/AccountService/*')
global with sharing class AccountService{
/*****************************************************************************************************
 * @Author:      CRM Team Innovation
 * @MethodName:   createAccounts
 * @Description: This method is responsible for creating/updating Account records in Server Org.
 **************************************************************************************************************/
    @HttpPost
    global static Map<String,String> createAccounts(){
        RestRequest req=RestContext.request;
        // Deserialize as untyped to handle External_Record_Id__c which may not exist on Server Account object
        List<Object> requestBody=(List<Object>)JSON.deserializeUntyped(req.requestBody.toString());
        Map<String,String> responseMap=new Map<String,String>();
        if(requestBody!=null&&!requestBody.isEmpty()){
            List<Account> accountsToUpsert=new List<Account>();
            // Fetch Person Account Record Type Id
            Id personAccountRTId=[SELECT
                                        Id
                                    FROM
                                        RecordType
                                    WHERE
                                        SObjectType='Account'
                                    AND 
                                        IsPersonType=TRUE 
                                    LIMIT 1].Id;
            List<String> clientIds=new List<String>();
            for(Object item : requestBody){
                Map<String,Object> data=(Map<String,Object>)item;
                Account acc=new Account();
                // Map standard fields
                if(data.containsKey('Id')&&data.get('Id')!=null){
                    acc.Id=(Id)data.get('Id');
                }
                acc.RecordTypeId=personAccountRTId;
                acc.Salutation=(String)data.get('Salutation');
                acc.FirstName=(String)data.get('FirstName');
                acc.LastName=(String)data.get('LastName');
                if(data.get('PersonBirthdate')!=null){
                    acc.PersonBirthdate=Date.valueOf((String)data.get('PersonBirthdate'));
                }
                acc.PersonMobilePhone=(String)data.get('PersonMobilePhone');
                acc.Phone=(String)data.get('Phone');
                acc.PersonEmail=(String)data.get('PersonEmail');
                acc.Login_Password__c=(String)data.get('Login_Password__c');
                acc.PersonMailingStreet=(String)data.get('PersonMailingStreet');
                acc.PersonMailingCity=(String)data.get('PersonMailingCity');
                acc.PersonMailingState=(String)data.get('PersonMailingState');
                acc.PersonMailingPostalCode=(String)data.get('PersonMailingPostalCode');
                acc.PersonMailingCountry=(String)data.get('PersonMailingCountry');
                acc.PersonOtherStreet=(String)data.get('PersonOtherStreet');
                acc.PersonOtherCity=(String)data.get('PersonOtherCity');
                acc.PersonOtherState=(String)data.get('PersonOtherState');
                acc.PersonOtherPostalCode=(String)data.get('PersonOtherPostalCode');
                acc.PersonOtherCountry=(String)data.get('PersonOtherCountry');
                accountsToUpsert.add(acc);
                // Store Client ID for response mapping
                if(data.containsKey('External_Record_Id__c')){
                    clientIds.add((String)data.get('External_Record_Id__c'));
                } else{
                    clientIds.add(null);
                }
            }
            if(!accountsToUpsert.isEmpty()){
                upsert accountsToUpsert;
                for(Integer i=0; i<accountsToUpsert.size(); i++){
                    String clientId=clientIds[i];
                    Id serverId=accountsToUpsert[i].Id;
                    if(String.isNotBlank(clientId)){
                        responseMap.put(clientId,serverId);
                    }
                }
            }
        }
        return responseMap;
    }
}