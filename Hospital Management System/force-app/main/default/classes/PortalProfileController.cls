/**
 */
public with sharing class PortalProfileController {
    public class AccountSummary {
        @AuraEnabled public Account account;
        @AuraEnabled public List<Appointment__c> appointments;
        @AuraEnabled public List<Consultation__c> consultations;
        @AuraEnabled public List<Prescription__c> prescriptions;
    }
    @AuraEnabled(cacheable=true)
    public static AccountSummary getProfileData(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }
        AccountSummary result = new AccountSummary();
        // Account details
        result.account = [
            SELECT 
                Id, Name, PersonEmail, Phone, Website, Rating, Industry,
                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM 
                Account
            WHERE 
                Id = :accountId
            WITH 
                SECURITY_ENFORCED
            LIMIT 1
        ];
        // Upcoming Appointments for this patient
        result.appointments = [
            SELECT 
                Id, Name, Appointment_Date__c, Appointment_Status__c, Appointment_Type__c,
                Doctor__c, Doctor__r.Name, Reason_for_Visit__c
            FROM 
                Appointment__c
            WHERE 
                Patient__c = :accountId
            ORDER BY 
                Appointment_Date__c DESC
            LIMIT 10
        ];
        // Recent Consultations
        result.consultations = [
            SELECT 
                Id, Name, Date_of_Visit__c, Doctor__c, Doctor__r.Name, Next_Visit__c, Visit_Charges__c
            FROM 
                Consultation__c
            WHERE 
                Patient__c = :accountId
            ORDER BY 
                Date_of_Visit__c DESC
            LIMIT 5
        ];
        // Recent Prescriptions
        result.prescriptions = [
            SELECT 
                Id, Name, Total_Amount__c, Total_Medication_Amount__c, Notes__c, CreatedDate
            FROM 
                Prescription__c
            WHERE 
                Account__c = :accountId
            ORDER BY 
                CreatedDate DESC
            LIMIT 5
        ];
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Prescription__c> getPrescriptions(Id accountId) {
        return [
            SELECT 
                Id, Name, Total_Amount__c, Total_Medication_Amount__c, Notes__c, CreatedDate,
                (SELECT Id, Name, Dosage__c, Quantity__c FROM Medications__r)
            FROM 
                Prescription__c
            WHERE 
                Account__c = :accountId
            ORDER BY 
                CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Consultation__c> getConsultations(Id accountId) {
        return [
            SELECT 
                Id, Name, Date_of_Visit__c, Next_Visit__c, Visit_Charges__c,
                Doctor__c, Doctor__r.Name, Patient__c, Patient__r.Name
            FROM 
                Consultation__c
            WHERE 
                Patient__c = :accountId
            ORDER BY 
                Date_of_Visit__c DESC
        ];
    }
}
