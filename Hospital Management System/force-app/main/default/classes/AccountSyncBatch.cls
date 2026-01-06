public with sharing class AccountSyncBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AccountSyncBatch(), 200);
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {        
        // We look back 20 minutes to cover the 15-minute schedule interval plus a buffer.
        Datetime timeWindow = Datetime.now().addMinutes(-20);
        return Database.getQueryLocator([
            SELECT 
                Id, Salutation, FirstName, LastName, PersonBirthdate, Age__c, PersonMobilePhone, Phone, PersonEmail, Login_Password__c,
                PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode, PersonMailingCountry,
                PersonOtherStreet, PersonOtherCity, PersonOtherState, PersonOtherPostalCode, PersonOtherCountry, External_Record_Id__c 
            FROM 
                Account
            WHERE 
                isPersonAccount = True AND (External_Record_Id__c = NULL OR LastModifiedDate >= :timeWindow)
        ]);
    }
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        
        for (Account acc : scope) {
            // Create a map for the payload to handle formula fields like Age__c and explicit mapping
            // We map the local Client Id to External_Record_Id__c so the Server knows the source ID
            Map<String, Object> accPayload = new Map<String, Object>();
            accPayload.put('External_Record_Id__c', acc.Id);
            accPayload.put('Salutation', acc.Salutation);
            accPayload.put('FirstName', acc.FirstName);
            accPayload.put('LastName', acc.LastName);
            accPayload.put('PersonBirthdate', acc.PersonBirthdate);
            accPayload.put('Age__c', acc.Age__c);
            accPayload.put('PersonMobilePhone', acc.PersonMobilePhone);
            accPayload.put('Phone', acc.Phone);
            accPayload.put('PersonEmail', acc.PersonEmail);
            accPayload.put('Login_Password__c', acc.Login_Password__c);
            accPayload.put('PersonMailingStreet', acc.PersonMailingStreet);
            accPayload.put('PersonMailingCity', acc.PersonMailingCity);
            accPayload.put('PersonMailingState', acc.PersonMailingState);
            accPayload.put('PersonMailingPostalCode', acc.PersonMailingPostalCode);
            accPayload.put('PersonMailingCountry', acc.PersonMailingCountry);
            accPayload.put('PersonOtherStreet', acc.PersonOtherStreet);
            accPayload.put('PersonOtherCity', acc.PersonOtherCity);
            accPayload.put('PersonOtherState', acc.PersonOtherState);
            accPayload.put('PersonOtherPostalCode', acc.PersonOtherPostalCode);
            accPayload.put('PersonOtherCountry', acc.PersonOtherCountry);

            // If we have the Server's ID stored in External_Record_Id__c, send it as the Id
            if (String.isNotBlank(acc.External_Record_Id__c)) {
                accPayload.put('Id', acc.External_Record_Id__c);
            }
            payload.add(accPayload);
        }

        if (payload.isEmpty()) return;
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/AccountService/');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(120000); // 2 minutes timeout

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // The server returns a Map<String, String> where Key = Client ID (sent as External_Record_Id__c) and Value = Server ID
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Account> accountsToUpdate = new List<Account>();

                for (Account acc : scope) {
                    // Check if the server returned a mapping for this account
                    if (responseMap.containsKey(acc.Id)) {
                        String serverId = (String) responseMap.get(acc.Id);
                        // Only update if the External Id is missing or different to avoid unnecessary DML
                        if (acc.External_Record_Id__c != serverId) {
                            acc.External_Record_Id__c = serverId;
                            accountsToUpdate.add(acc);
                        }
                    }
                }

                if (!accountsToUpdate.isEmpty()) {
                    update accountsToUpdate;
                }
            } else {
                System.debug('Account Sync Failed. Status: ' + res.getStatus() + ' Body: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Account Sync Exception: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Optional: Add logging or chaining logic here
    }
}