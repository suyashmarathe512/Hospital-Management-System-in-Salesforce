public with sharing class AppointmentViewerController{
    @AuraEnabled(cacheable=true)
    public static Appointment__c getAppointmentDetails(String recordId){
        List<Appointment__c> appts = [SELECT 
                                            Name,Appointment_Date__c,Appointment_Status__c,Reason_for_Visit__c,
                                            Doctor__c,Doctor__r.Name,
                                            Patient__c,Patient__r.Name,Patient__r.PersonEmail,Patient__r.Phone,
                                            Patient__r.Age__c,Patient__r.PersonBirthdate
                                    FROM
                                        Appointment__c
                                    WHERE
                                        Id=:recordId];
        if(appts.isEmpty()){
            throw new AuraHandledException('Appointment record not found.');
        }
        return appts[0];
    }
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getConsultationFee(String doctorId,String patientId,String visitDate){
        Map<String,Object> result=new Map<String,Object>();
        Doctor__c doc=[SELECT 
                            Consultation_Fees__c
                        FROM
                            Doctor__c
                        WHERE
                            Id=:doctorId
                        LIMIT 1];
        Decimal baseFee=(doc.Consultation_Fees__c!=null)?doc.Consultation_Fees__c:100;
        Date dateToCheck = String.isNotBlank(visitDate) ? Date.valueOf(visitDate) : Date.today();
        Integer visitsToday=[SELECT
                                COUNT()
                            FROM
                                Consultation__c
                            WHERE
                                Doctor__c=:doctorId
                            AND
                                Patient__c=:patientId
                            AND
                                Date_of_Visit__c=:dateToCheck];
        Integer previousVisits=[SELECT
                                    COUNT()
                                FROM
                                    Consultation__c
                                WHERE
                                    Doctor__c=:doctorId
                                AND
                                    Patient__c=:patientId];
        if(visitsToday>0){
            result.put('fee',0);
            result.put('message','Same day revisit: No Charge');
        }else if(previousVisits>0){
            result.put('fee',baseFee*0.5);
            result.put('message','Follow-up Visit: 50% Discount Applied');
        }else{
            result.put('fee',baseFee);
            if(baseFee == 0){
                result.put('message','Standard Fee is 0 (Check Doctor Record)');
            }else {
                result.put('message','Standard Consultation Fee');
            }
        }
        return result;
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
            
            // Use passed visitCharges if available, otherwise calculate
            if(consultationData.containsKey('visitCharges') && consultationData.get('visitCharges') != null && String.isNotBlank(String.valueOf(consultationData.get('visitCharges')))){
                cons.Visit_Charges__c = Decimal.valueOf(String.valueOf(consultationData.get('visitCharges')));
            } else {
                // Fee Calculation Logic
                Doctor__c doc = [SELECT 
                                    Consultation_Fees__c 
                                FROM 
                                    Doctor__c
                                WHERE
                                    Id = :cons.Doctor__c LIMIT 1];
                Decimal baseFee = (doc.Consultation_Fees__c != null) ? doc.Consultation_Fees__c : 100;
                Integer visitsToday = [SELECT
                                            COUNT()
                                        FROM
                                            Consultation__c
                                        WHERE
                                            Doctor__c = :cons.Doctor__c
                                        AND
                                            Patient__c = :cons.Patient__c
                                        AND
                                            Date_of_Visit__c = :cons.Date_of_Visit__c];
                Integer previousVisits = [SELECT
                                            COUNT()
                                        FROM
                                            Consultation__c
                                        WHERE
                                            Doctor__c = :cons.Doctor__c
                                        AND 
                                            Patient__c = :cons.Patient__c];
                if(visitsToday > 0){
                    cons.Visit_Charges__c = 0; // Same day revisit: Free
                }else if(previousVisits > 0){
                    cons.Visit_Charges__c = baseFee * 0.5; // Follow-up: 50% of standard fee
                }else {
                    cons.Visit_Charges__c = baseFee; // First visit: Standard fee
                }
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
            // 4. Update Appointment Status to Completed
            if(consultationData.containsKey('appointmentId') && String.isNotBlank((String)consultationData.get('appointmentId'))){
                Appointment__c apptToUpdate = new Appointment__c();
                apptToUpdate.Id = (Id)consultationData.get('appointmentId');
                apptToUpdate.Appointment_Status__c = 'Completed';
                update apptToUpdate;
            }
            // 5. Send PDF Email
            sendPrescriptionEmail(cons.Id);
        }catch(Exception e){
            Database.rollback(sp);
            throw new AuraHandledException('Error saving consultation: ' + e.getMessage());
        }
    }
    @future(callout=true)
    public static void sendPrescriptionEmail(Id consultationId){
        try {
            Consultation__c cons = [SELECT Id, Name, Patient__r.PersonEmail, Patient__r.Name FROM Consultation__c WHERE Id = :consultationId LIMIT 1];
            if(cons.Patient__r.PersonEmail != null){
                PageReference pdfPage = Page.PrescriptionPDF;
                pdfPage.getParameters().put('id', consultationId);
                Blob pdfBlob;
                if(Test.isRunningTest()) { 
                    pdfBlob = Blob.valueOf('Test PDF');
                } else {
                    pdfBlob = pdfPage.getContentAsPDF();
                }

                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{cons.Patient__r.PersonEmail});
                email.setSubject('Your Prescription and Bill Details');
                email.setPlainTextBody('Dear ' + cons.Patient__r.Name + ',\n\nPlease find attached your prescription and billing details from your recent visit.\n\nRegards,\nHospital Management System');
                Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
                attach.setFileName('Prescription_' + cons.Name + '.pdf');
                attach.setBody(pdfBlob);
                email.setFileAttachments(new List<Messaging.EmailFileAttachment>{attach});
                
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
            }
        } catch(Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}