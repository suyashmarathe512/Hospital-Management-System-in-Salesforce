/*****************************************************************************************************
 * @Author:      CRM Team Innovation
 * @ClassName:   AccountSyncBatch
 * @Description: This Class belongs to Client Org, where the data is being synced from Client Org to Server Org.
 *               This class is responsible for updating Account records in Server Org.
 **************************************************************************************************************/
public with sharing class AccountSyncBatch implements Database.Batchable<sObject>,Database.AllowsCallouts,Schedulable{
/*****************************************************************************************************
 * @Author:      CRM Team Innovation
 * @MethodName:   execute
 * @param1 :     SchedulableContext sc
 * @Description: This method is responsible calling the batch class for further logic.
 **************************************************************************************************************/
    public void execute(SchedulableContext sc){
        Database.executeBatch(new AccountSyncBatch(),200);
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   start
 * @param1 :      Database.BatchableContext bc
 * @Description:  This method is responsible fetching the Account records from 
 *                Client Org which needs to be updated in Server Org.
 **************************************************************************************************************/
    public Database.QueryLocator start(Database.BatchableContext bc){        
        // We look back 20 minutes to cover the 15-minute schedule interval plus a buffer.
        Datetime timeWindow=Datetime.now().addMinutes(-20);
        return Database.getQueryLocator([
            SELECT 
                Id,Salutation,FirstName,LastName,PersonBirthdate,Age__c,PersonMobilePhone,Phone,PersonEmail,Login_Password__c,
                PersonMailingStreet,PersonMailingCity,PersonMailingState,PersonMailingPostalCode,PersonMailingCountry,
                PersonOtherStreet,PersonOtherCity,PersonOtherState,PersonOtherPostalCode,PersonOtherCountry,External_Record_Id__c 
            FROM 
                Account
            WHERE 
                isPersonAccount=True AND(External_Record_Id__c=NULL OR LastModifiedDate>=:timeWindow)
        ]);
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   execute
 * @param1 :      Database.BatchableContext bc
 * @param2 :      List<Account> scope
 * @Description:  This method is responsible creating the payload that need to be sent to server org.
 *                 In response, we get the External_Record_Id__c(record Id of server) 
 *                  from server org and update it in client org.
 **************************************************************************************************************/
    public void execute(Database.BatchableContext bc,List<Account> scope){
        List<Map<String,Object>> payload=new List<Map<String,Object>>();
        for(Account acc:scope){
            Map<String,Object> accPayload=new Map<String,Object>();
            accPayload.put('External_Record_Id__c',acc.Id);
            accPayload.put('Salutation',acc.Salutation);
            accPayload.put('FirstName',acc.FirstName);
            accPayload.put('LastName',acc.LastName);
            accPayload.put('PersonBirthdate',acc.PersonBirthdate);
            accPayload.put('Age__c',acc.Age__c);
            accPayload.put('PersonMobilePhone',acc.PersonMobilePhone);
            accPayload.put('Phone',acc.Phone);
            accPayload.put('PersonEmail',acc.PersonEmail);
            accPayload.put('Login_Password__c',acc.Login_Password__c);
            accPayload.put('PersonMailingStreet',acc.PersonMailingStreet);
            accPayload.put('PersonMailingCity',acc.PersonMailingCity);
            accPayload.put('PersonMailingState',acc.PersonMailingState);
            accPayload.put('PersonMailingPostalCode',acc.PersonMailingPostalCode);
            accPayload.put('PersonMailingCountry',acc.PersonMailingCountry);
            accPayload.put('PersonOtherStreet',acc.PersonOtherStreet);
            accPayload.put('PersonOtherCity',acc.PersonOtherCity);
            accPayload.put('PersonOtherState',acc.PersonOtherState);
            accPayload.put('PersonOtherPostalCode',acc.PersonOtherPostalCode);
            accPayload.put('PersonOtherCountry',acc.PersonOtherCountry);
            // If we have the Server's ID stored in External_Record_Id__c,send it as the Id
            if(String.isNotBlank(acc.External_Record_Id__c)){
                accPayload.put('Id',acc.External_Record_Id__c);
            }
            payload.add(accPayload);
        }
        if(payload.isEmpty()) return;
        HttpRequest req=new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/AccountService/');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(120000);
        try{
            Http http=new Http();
            HttpResponse res=http.send(req);
            if(res.getStatusCode()==200){
                // The server returns a Map<String,String> where Key=Client ID(sent as External_Record_Id__c) and Value=Server ID
                Map<String,Object> responseMap=(Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                List<Account> accountsToUpdate=new List<Account>();
                for(Account acc:scope){
                    // Check if the server returned a mapping for this account
                    if(responseMap.containsKey(acc.Id)){
                        String serverId=(String) responseMap.get(acc.Id);
                        // Only update if the External Id is missing or different to avoid unnecessary DML
                        if(acc.External_Record_Id__c != serverId){
                            acc.External_Record_Id__c=serverId;
                            accountsToUpdate.add(acc);
                        }
                    }
                }
                if(!accountsToUpdate.isEmpty()){
                    update accountsToUpdate;
                }
            }else{
                System.debug('Account Sync Failed. Status: '+res.getStatus()+' Body: '+res.getBody());
            }
        }catch(Exception e){
            System.debug('Account Sync Exception: '+e.getMessage());
        }
    }
/********************************************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   finish
 * @param1 :      Database.BatchableContext bc
 * @Description:  This method is responsible for logging the success or failure of the batch job.
 ***************************************************************************************************************************/
    public void finish(Database.BatchableContext bc){
    }
}