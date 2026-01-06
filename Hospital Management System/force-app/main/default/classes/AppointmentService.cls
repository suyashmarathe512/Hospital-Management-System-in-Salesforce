@RestResource(urlMapping='/AppointmentService/*')
global with sharing class AppointmentService {
    @HttpPost
    global static Map<String, String> syncAppointments() {
        RestRequest req = RestContext.request;
        Map<String, String> responseMap = new Map<String, String>();
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<Object> apptList = (List<Object>) root.get('appointments');
            List<Appointment__c> upsertList = new List<Appointment__c>();
            List<String> clientIds = new List<String>();
            // Collect External IDs for lookup resolution
            Set<String> patientExtIds = new Set<String>();
            for (Object obj : apptList) {
                Map<String, Object> apptMap = (Map<String, Object>) obj;
                if (apptMap.get('patientExternalId') != null) patientExtIds.add((String) apptMap.get('patientExternalId'));
            }
            // Resolve Lookups
            // Fetch related Accounts/Doctors using External IDs in a single SOQL (bulk-safe)
            Map<String, Id> patientMap = new Map<String, Id>();
            if (!patientExtIds.isEmpty()) {
                for (Account acc : [SELECT 
                                        Id, External_Record_Id__c 
                                    FROM 
                                        Account 
                                    WHERE 
                                        External_Record_Id__c IN :patientExtIds]) {
                    patientMap.put(acc.External_Record_Id__c, acc.Id);
                }
            }
            // Build Appointment records
            for (Object obj : apptList) {
                Map<String, Object> w = (Map<String, Object>) obj;
                Appointment__c appt = new Appointment__c();
                
                // Use Server Id if provided (Upsert logic)
                if (w.containsKey('serverAppointmentId') && w.get('serverAppointmentId') != null) {
                    // Set Id directly to update existing record
                    appt.Id = (String) w.get('serverAppointmentId');
                }
                // Map fields
                Object dateObj = w.get('appointmentDate');
                if (dateObj != null) {
                    // Safely convert date string to DateTime then Date
                    appt.Appointment_Date__c = ((DateTime) JSON.deserialize('"' + dateObj + '"', DateTime.class)).date();
                }
                appt.Appointment_Status__c = (String) w.get('status');
                appt.Reason_for_Visit__c = (String) w.get('reason');
                
                // Resolve lookups using maps
                String pExtId = (String) w.get('patientExternalId');
                if (patientMap.containsKey(pExtId)) appt.Patient__c = patientMap.get(pExtId);
                
                upsertList.add(appt);
                clientIds.add((String) w.get('clientAppointmentId'));
            }
            
            if (!upsertList.isEmpty()) {
                // Bulk upsert
                upsert upsertList;
                for (Integer i = 0; i < upsertList.size(); i++) {
                    // Map ClientId to newly saved SF Id for response
                    responseMap.put(clientIds[i], upsertList[i].Id);
                }
            }
        } catch (Exception e) {
            throw new StringException('Error processing appointments: ' + e.getMessage());
        }
        return responseMap;
    }
}
