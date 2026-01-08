public with sharing class PrescriptionPDFController {
    public Consultation__c consultation {get; set;}
    public Prescription__c prescription {get; set;}
    public List<Medication__c> medications {get; set;}
    public Decimal totalBill {get; set;}

    public PrescriptionPDFController() {
        Id consultationId = ApexPages.currentPage().getParameters().get('id');
        if(String.isNotBlank(consultationId)) {
            consultation = [SELECT Id, Name, Date_of_Visit__c, Visit_Charges__c, 
                                   Patient__r.Name, Patient__r.PersonEmail, 
                                   Doctor__r.Name
                            FROM Consultation__c 
                            WHERE Id = :consultationId LIMIT 1];
            
            List<Prescription__c> prescriptions = [SELECT Id, Notes__c FROM Prescription__c WHERE Consultation__c = :consultationId LIMIT 1];
            if(!prescriptions.isEmpty()){
                prescription = prescriptions[0];
                medications = [SELECT Name, Dosage__c, Frequency__c, Duration_Days__c 
                               FROM Medication__c 
                               WHERE Prescription__c = :prescription.Id];
            } else {
                prescription = new Prescription__c();
                medications = new List<Medication__c>();
            }
            
            totalBill = (consultation.Visit_Charges__c != null ? consultation.Visit_Charges__c : 0);
        }
    }
}