@RestResource(urlMapping='/AppointmentService/*')
global with sharing class AppointmentService {
    @HttpPost
    global static Map<String, String> syncAppointments() {
        RestRequest req = RestContext.request;
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        List<Object> apptList = (List<Object>) root.get('appointments');
        Map<String, String> responseMap = new Map<String, String>();
        List<Appointment__c> upsertList = new List<Appointment__c>();
        List<String> clientIds = new List<String>();
        // Collect External IDs for lookup resolution
        Set<String> patientExtIds = new Set<String>();
        Set<String> doctorExtIds = new Set<String>();        
        for (Object obj : apptList) {
            Map<String, Object> apptMap = (Map<String, Object>) obj;
            if (apptMap.containsKey('patientExternalId')) patientExtIds.add((String) apptMap.get('patientExternalId'));
            if (apptMap.containsKey('doctorExternalId')) doctorExtIds.add((String) apptMap.get('doctorExternalId'));
        }
        // Resolve Lookups
        // Yahan pe hum pehle saare external IDs se related Accounts/Doctors ek hi SOQL mein laa rahe hain taaki baad mein loop ke andar query na karni pade (bulk-safe approach)
        Map<String, Id> patientMap = new Map<String, Id>();
        for (Account acc : [SELECT 
                                Id, External_Record_Id__c 
                            FROM 
                                Account 
                            WHERE 
                                External_Record_Id__c 
                            IN 
                                :patientExtIds]) {
            patientMap.put(acc.External_Record_Id__c, acc.Id);
        }
        Map<String, Id> doctorMap = new Map<String, Id>();
        for (Doctor__c doc : [SELECT 
                                    Id, External_Record_Id__c 
                                FROM 
                                    Doctor__c 
                                WHERE 
                                    External_Record_Id__c 
                                IN  
                                    :doctorExtIds]) {
            doctorMap.put(doc.External_Record_Id__c, doc.Id);
        }
        // Build Appointment records
        for (Object obj : apptList) {
            Map<String, Object> w = (Map<String, Object>) obj;
            Appointment__c appt = new Appointment__c();
            // Use Server Id if provided (Upsert logic)
            if (w.containsKey('serverAppointmentId')) {
                // Agar server side Id mila hai toh direct Id set karke upsert ko update jaisa behave karwa rahe hain (duplicate create se bachte hain)
                appt.Id = (String) w.get('serverAppointmentId');
            }
            // Map fields
            Object dateObj = w.get('appointmentDate');
            // Date string ko safely DateTime mein convert kar rahe hain, JSON trick se timezone/format issues ko handle karna easy ho jata hai
            if (dateObj != null) appt.Appointment_Date__c = (DateTime) JSON.deserialize('"' + dateObj + '"', DateTime.class);
            appt.Appointment_Status__c = (String) w.get('status');
            appt.Reason_for_Visit__c = (String) w.get('reason');
            
            // External IDs se related lookups ko resolve karke actual SFDC Ids set kar rahe hain, taaki referential integrity sahi rahe
            if (patientMap.containsKey((String) w.get('patientExternalId'))) appt.Patient__c = patientMap.get((String) w.get('patientExternalId'));
            if (doctorMap.containsKey((String) w.get('doctorExternalId'))) appt.Doctor__c = doctorMap.get((String) w.get('doctorExternalId'));
            
            upsertList.add(appt);
            clientIds.add((String) w.get('clientAppointmentId'));
        }
        
        if (!upsertList.isEmpty()) {
            // Bulk upsert kar rahe hain taaki sab records ek shot mein process ho jayein (governor limits friendly)
            upsert upsertList;
            for (Integer i = 0; i < upsertList.size(); i++) {
                // ClientId ko newly saved SF Id se map karke response bana rahe hain, taaki client apna mapping sync kar sake
                responseMap.put(clientIds[i], upsertList[i].Id);
            }
        }
        return responseMap;
    }
}
