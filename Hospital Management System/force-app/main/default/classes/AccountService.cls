@RestResource(urlMapping='/AccountService/*')
global with sharing class AccountService {
    @HttpPost
    global static Map<String, String> createAccounts() {
        RestRequest req = RestContext.request;
        List<Account> accounts = (List<Account>) JSON.deserialize(req.requestBody.toString(), List<Account>.class);
        Map<String, String> responseMap = new Map<String, String>();
        if (accounts != null && !accounts.isEmpty()) {
            Set<String> extIds = new Set<String>();
            for (Account acc : accounts) {
                if (String.isNotBlank(acc.External_Record_Id__c)) {
                    extIds.add(acc.External_Record_Id__c);
                }
            }
            if (!extIds.isEmpty()) {
                Map<String, Id> existingMap = new Map<String, Id>();
                for (Account existing : [SELECT 
                                            Id, External_Record_Id__c 
                                        FROM
                                            Account 
                                        WHERE
                                             External_Record_Id__c 
                                        IN
                                            :extIds]) {
                    existingMap.put(existing.External_Record_Id__c, existing.Id);
                }
                for (Account acc : accounts) {
                    if (String.isNotBlank(acc.External_Record_Id__c) && existingMap.containsKey(acc.External_Record_Id__c)) {
                        acc.Id = existingMap.get(acc.External_Record_Id__c);
                    }
                }
            }
            upsert accounts;
            for (Account acc : accounts) {
                if (String.isNotBlank(acc.External_Record_Id__c)) {
                    responseMap.put(acc.External_Record_Id__c, acc.Id);
                }
            }
        }
        return responseMap;
    }
}