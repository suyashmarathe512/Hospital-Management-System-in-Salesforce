@RestResource(urlMapping='/AppointmentService/*')
global with sharing class AppointmentService {
    @HttpPost
    global static Map<String, String> createAppointments(List<Appointment__c> appointments) {
        Map<String, String> responseMap = new Map<String, String>();
        if (appointments != null && !appointments.isEmpty()) {
            Set<String> extIds = new Set<String>();
            for (Appointment__c appt : appointments) {
                if (String.isNotBlank(appt.External_Record_Id__c)) {
                    extIds.add(appt.External_Record_Id__c);
                }
            }
            if (!extIds.isEmpty()) {
                Map<String, Id> existingMap = new Map<String, Id>();
                for (Appointment__c existing : [SELECT 
                                                    Id, External_Record_Id__c 
                                                FROM 
                                                    Appointment__c 
                                                WHERE 
                                                    External_Record_Id__c 
                                                IN :extIds]) {
                    existingMap.put(existing.External_Record_Id__c, existing.Id);
                }
                for (Appointment__c appt : appointments) {
                    if (String.isNotBlank(appt.External_Record_Id__c) && existingMap.containsKey(appt.External_Record_Id__c)) {
                        appt.Id = existingMap.get(appt.External_Record_Id__c);
                    }
                }
            }
            upsert appointments;
            for (Appointment__c appt : appointments) {
                if (String.isNotBlank(appt.External_Record_Id__c)) {
                    responseMap.put(appt.External_Record_Id__c, appt.Id);
                }
            }
        }
        return responseMap;
    }
}