public with sharing class PortalAppointmentController {
    @AuraEnabled(cacheable=true)
    public static List<Appointment__c> getAppointments(String accountId) {
        return [SELECT 
                    Id, Name, Appointment_Date__c, Appointment_Status__c, Doctor__r.Name, Reason_for_Visit__c 
                FROM 
                    Appointment__c 
                WHERE 
                    Patient__c = :accountId 
                ORDER BY 
                    Appointment_Date__c DESC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Doctor__c> getDoctors() {
        return [SELECT
                    Id, Name 
                FROM
                    Doctor__c 
                WITH
                    SECURITY_ENFORCED];
    }
    @AuraEnabled
    public static void bookAppointment(String accountId, String doctorId, Date appointmentDate, String reason) {
        Appointment__c newAppt = new Appointment__c(
            Patient__c = accountId,
            Doctor__c = doctorId,
            Appointment_Date__c = appointmentDate,
            Reason_for_Visit__c = reason,
            Appointment_Status__c = 'Scheduled'
        );
        insert newAppt;
    }
}