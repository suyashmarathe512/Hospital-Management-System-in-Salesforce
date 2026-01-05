public with sharing class PortalPrescriptionsController {
    @AuraEnabled(cacheable=true)
    public static List<Prescription__c> getPrescriptions() {
        HttpRequest req = new HttpRequest();
        // Note: 'External_Org' is a placeholder for the actual Named Credential
        req.setEndpoint('callout:Hospital_Server/services/apexrest/prescriptions/');
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return (List<Prescription__c>) JSON.deserialize(res.getBody(), List<Prescription__c>.class);
        }
        throw new CalloutException('Error fetching prescriptions: ' + res.getStatus());
    }
}