public with sharing class AppointmentSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    public void execute(SchedulableContext sc) {
        // Execute batch with a manageable chunk size for callouts
        Database.executeBatch(new AppointmentSyncBatch(), 100);
    }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Sync if External_Record_Id__c is null (New Record) OR modified in last 20 mins (Update)
        DateTime timeThreshold = DateTime.now().addMinutes(-20);
        return Database.getQueryLocator([
            SELECT 
                Id, Appointment_Date__c, Appointment_Status__c, Reason_for_Visit__c,
                   External_Record_Id__c, Patient__r.External_Record_Id__c
            FROM 
                Appointment__c
            WHERE 
                External_Record_Id__c = NULL 
               OR 
                LastModifiedDate >= :timeThreshold
        ]);
    }
    public void execute(Database.BatchableContext bc, List<Appointment__c> scope) {
        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        for (Appointment__c appt : scope) {
            Map<String, Object> apptMap = new Map<String, Object>();
            apptMap.put('clientAppointmentId', appt.Id);
            // If we have an External_Record_Id__c, it means it exists on Server. Send it to perform update.
            if (String.isNotBlank(appt.External_Record_Id__c)) {
                apptMap.put('serverAppointmentId', appt.External_Record_Id__c);
            }
            apptMap.put('appointmentDate', appt.Appointment_Date__c);
            apptMap.put('status', appt.Appointment_Status__c);
            apptMap.put('reason', appt.Reason_for_Visit__c);
            // Map Patient via External ID
            if (appt.Patient__r != null) {
                apptMap.put('patientExternalId', appt.Patient__r.External_Record_Id__c);
            }
            payload.add(apptMap);
        }
        if (payload.isEmpty()) return;
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('appointments', payload);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/AppointmentService/');
        req.setMethod('POST');
        req.setBody(JSON.serialize(requestBody));
        req.setHeader('Content-Type', 'application/json');
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Appointment__c> toUpdate = new List<Appointment__c>();
                for (String clientId : responseMap.keySet()) {
                    toUpdate.add(new Appointment__c(
                        Id = clientId,
                        External_Record_Id__c = (String) responseMap.get(clientId)
                    ));
                }
                if (!toUpdate.isEmpty()) {
                    update toUpdate;
                }
            } else {
                System.debug('Sync failed with status: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Sync Exception: ' + e.getMessage());
        }
    }
    public void finish(Database.BatchableContext bc) {
    }
}