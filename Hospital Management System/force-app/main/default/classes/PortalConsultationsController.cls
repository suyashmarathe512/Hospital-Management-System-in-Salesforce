public with sharing class PortalConsultationsController {
    @AuraEnabled(cacheable=true)
    public static List<Consultation__c> getConsultations() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/ConsultationsService/');
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return (List<Consultation__c>) JSON.deserialize(res.getBody(), List<Consultation__c>.class);
        }
        throw new CalloutException('Error fetching consultations: ' + res.getStatus());
    }
}