public with sharing class AccountSyncBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AccountSyncBatch(), 200);
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query Accounts that are new (External_Record_Id__c is null) or have been updated recently.
        // We look back 20 minutes to cover the 15-minute schedule interval plus a buffer.
        Datetime timeWindow = Datetime.now().addMinutes(-20);
        return Database.getQueryLocator([
            SELECT 
                Id, Name, Phone, Type, Industry, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, External_Record_Id__c 
            FROM 
                Account 
            WHERE 
                External_Record_Id__c = NULL OR LastModifiedDate >= :timeWindow
        ]);
    }
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Account> payload = new List<Account>();
        
        for (Account acc : scope) {
            // Create a new Account instance for the payload to map fields explicitly
            // We map the local Client Id to External_Record_Id__c so the Server knows the source ID
            Account accPayload = new Account(
                External_Record_Id__c = acc.Id,
                Name = acc.Name,
                Phone = acc.Phone,
                Type = acc.Type,
                Industry = acc.Industry,
                BillingStreet = acc.BillingStreet,
                BillingCity = acc.BillingCity,
                BillingState = acc.BillingState,
                BillingPostalCode = acc.BillingPostalCode,
                BillingCountry = acc.BillingCountry
            );
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