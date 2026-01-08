public with sharing class AppointmentViewerController{
    @AuraEnabled
    public static Appointment__c getAppointmentDetails(String recordId){
        return [SELECT 
                    Name,Appointment_Date__c,Appointment_Status__c,Reason_for_Visit__c,
                    Doctor__c,Doctor__r.Name,
                    Patient__c,Patient__r.Name,Patient__r.PersonEmail,Patient__r.Phone,
                    Patient__r.Age__c,Patient__r.PersonBirthdate
                FROM
                    Appointment__c
                WHERE
                    Id=:recordId];
    }
    @AuraEnabled
    public static void saveConsultation(Map<String,Object> consultationData,List<Map<String,Object>> medications){
        Savepoint sp=Database.setSavepoint();
        try{
            // 1. Create Consultation Record
            Consultation__c cons=new Consultation__c();
            cons.Doctor__c=(Id) consultationData.get('doctorId');
            cons.Patient__c=(Id) consultationData.get('patientId');
            cons.Date_of_Visit__c=Date.valueOf((String) consultationData.get('visitDate'));
            if(consultationData.containsKey('nextVisitDate')&&String.isNotBlank((String)consultationData.get('nextVisitDate'))){
                cons.Next_Visit__c=Date.valueOf((String) consultationData.get('nextVisitDate'));
            }
            if(consultationData.containsKey('numberOfVisits')&&String.isNotBlank(String.valueOf(consultationData.get('numberOfVisits')))){
                cons.Number_of_Visits__c=Decimal.valueOf(String.valueOf(consultationData.get('numberOfVisits')));
            }
            if(consultationData.containsKey('visitCharges')&&String.isNotBlank(String.valueOf(consultationData.get('visitCharges')))){
                cons.Visit_Charges__c=Decimal.valueOf(String.valueOf(consultationData.get('visitCharges')));
            }
            insert cons;
            // 2. Create Prescription Record
            Prescription__c presc=new Prescription__c();
            presc.Consultation__c=cons.Id;
            presc.Account__c=cons.Patient__c;
            presc.Notes__c=(String) consultationData.get('notes');
            insert presc;
            // 3. Create Medication Line Items
            if(medications != null&&!medications.isEmpty()){
                List<Medication__c> lineItems=new List<Medication__c>();
                for(Map<String,Object> med:medications){
                    // Skip rows without a medicine name
                    String medName=(String) med.get('name');
                    if(String.isBlank(medName)) continue;
                    Medication__c item=new Medication__c();
                    item.Prescription__c=presc.Id;
                    item.Name=medName;
                    item.Dosage__c=(String) med.get('dosage');
                    item.Frequency__c=(String) med.get('frequency');
                    String durationStr=(String) med.get('duration');
                    if(String.isNotBlank(durationStr)){
                        String numericDuration=durationStr.replaceAll('[^0-9]','');
                        if(String.isNotBlank(numericDuration)){
                            item.Duration_Days__c=Decimal.valueOf(numericDuration);
                        }
                    }
                    lineItems.add(item);
                }
                if(!lineItems.isEmpty()) insert lineItems;
            }
        }catch(Exception e){
            Database.rollback(sp);
            throw new AuraHandledException('Error saving consultation: ' + e.getMessage());
        }
    }
}