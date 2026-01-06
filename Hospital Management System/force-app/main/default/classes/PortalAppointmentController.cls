public with sharing class PortalAppointmentController {
    @AuraEnabled(cacheable=true)
    public static List<Appointment__c> getAppointments(String accountId) {
        return [SELECT 
                    Id,Name,Appointment_Type__c,Appointment_Date__c,Appointment_Status__c,Reason_for_Visit__c
                FROM 
                    Appointment__c 
                WHERE 
                    Patient__c = :accountId 
                ORDER BY 
                    Appointment_Date__c DESC];
    }

    @AuraEnabled
    public static void bookAppointment(String accountId, Date appointmentDate, String reason, String appointmentType) {
        Appointment__c newAppt = new Appointment__c(
            Patient__c = accountId,
            Appointment_Type__c = appointmentType,
            Appointment_Date__c = appointmentDate,
            Reason_for_Visit__c = reason,
            Appointment_Status__c = 'Scheduled'
        );
        insert newAppt;
    }
}