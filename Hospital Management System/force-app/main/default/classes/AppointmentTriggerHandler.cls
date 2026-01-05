public with sharing class AppointmentTriggerHandler {
    public static void onAfterInsert(List<Appointment__c> newAppointments) {
        processAppointments(newAppointments);
    }
    public static void onAfterUpdate(List<Appointment__c> newAppointments, Map<Id, Appointment__c> oldMap) {
        List<Appointment__c> appointmentsToProcess = new List<Appointment__c>();
        for (Appointment__c appt : newAppointments) {
            Appointment__c oldAppt = oldMap.get(appt.Id);
            // Yahan hum update ke baad waale records collect kar rahe hain taaki downstream processing ek hi jagah se ho (single pipeline, duplication se bachna)
            appointmentsToProcess.add(appt);
        }
        processAppointments(appointmentsToProcess);
    }
    private static void processAppointments(List<Appointment__c> appointments) {
        if (appointments.isEmpty()) return;
        // Map constructor se unique Ids nikal rahe hain — yeh trick de-dup bhi karta hai aur bulk-safe bhi rehta hai
        Set<Id> appointmentIds = (new Map<Id, Appointment__c>(appointments)).keySet();
        // Call the local future method
        sendAppointments(new List<Id>(appointmentIds));
    }
     @future(callout=true)
    public static void sendAppointments(List<Id> appointmentIds) {
        // Heavy lifting async bhej diya hai taaki trigger context halki rahe aur callout limits hit na ho — background mein safe sync ho jayega
        List<Appointment__c> appointments = [
            SELECT 
                Id, Name, Appointment_Date__c, Appointment_Status__c, Reason_for_Visit__c,
                External_Record_Id__c, Patient__r.External_Record_Id__c, Doctor__r.External_Record_Id__c
            FROM 
                Appointment__c
            WHERE 
                Id IN :appointmentIds
        ];
        List<Map<String, Object>> payload = new List<Map<String, Object>>();
        for (Appointment__c appt : appointments) {
            Map<String, Object> apptMap = new Map<String, Object>();
            apptMap.put('clientAppointmentId', appt.Id);
            // Send Server Id if we have it (for upsert)
            // Agar external/server Id pehle se hai toh wo bhej dete hain taa ki remote side pe create ke bajaye update ho — idempotent behavior
            if (String.isNotBlank(appt.External_Record_Id__c)) {
                apptMap.put('serverAppointmentId', appt.External_Record_Id__c);
            }
            apptMap.put('appointmentDate', appt.Appointment_Date__c);
            apptMap.put('status', appt.Appointment_Status__c);
            apptMap.put('reason', appt.Reason_for_Visit__c);
            apptMap.put('patientExternalId', appt.Patient__r.External_Record_Id__c);
            apptMap.put('doctorExternalId', appt.Doctor__r.External_Record_Id__c);
            payload.add(apptMap);
        }
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
                // Parse response to update External_Record_Id__c
                // Server se aaya mapping use karke client SF Id -> server External Id ko sync kar rahe hain, next calls smart updates kar sakein
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
            }
        } catch (Exception e) {
            System.debug('Sync Error: ' + e.getMessage());
        }
    }
}
