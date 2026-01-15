/*********************************************************************************************************
 * @Author:      CRM Team Innovation
 * @ClassName:   AppointmentViewerController
 * @Description: This class is used to fetch the appointment details for the patient.
 *****************************************************************************************************/
public with sharing class AppointmentViewerController{
    @AuraEnabled(cacheable=true)
    public static Appointment__c getAppointmentDetails(String recordId){
        List<Appointment__c> appts=[SELECT 
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
        // Query Doctor for fee details
        Doctor__c doc=[SELECT
                            Consultation_Fees__c
                        FROM
                            Doctor__c
                        WHERE
                            Id=:doctorId LIMIT 1];
        Decimal baseFee=(doc.Consultation_Fees__c!=null)?doc.Consultation_Fees__c:100;
        // Query Consultation history for this doctor and patient(One SOQL)
        List<Consultation__c> history=[SELECT
                                            Date_of_Visit__c 
                                        FROM
                                            Consultation__c 
                                        WHERE
                                            Doctor__c=:doctorId 
                                        AND
                                            Patient__c=:patientId];
        Date dateToCheck=String.isNotBlank(visitDate)?Date.valueOf(visitDate):Date.today();
        return calculateFeeLogic(baseFee,history,dateToCheck);
    }
    @AuraEnabled(cacheable=true)
    public static List<Consultation__c> getConsultationHistory(String patientId){
        return [SELECT 
                    Id,Name,Date_of_Visit__c,Doctor__c,Doctor__r.Name,
                    Visit_Charges__c
                FROM
                    Consultation__c
                WHERE
                    Patient__c=:patientId
                ORDER BY
                    Date_of_Visit__c DESC];
    }
    @AuraEnabled(cacheable=true)
    public static List<Prescription__c> getPatientPrescriptions(String patientId){
        return [SELECT 
                    Id,Name,CreatedDate,Consultation__r.Doctor__r.Name,Notes__c
                FROM
                    Prescription__c
                WHERE
                    Account__c=:patientId
                ORDER BY
                    CreatedDate DESC];
    }
/*****************************************************************************************************************************
 * @Author:     CRM Team Innovation
 * @MethodName: saveConsultation
 * @param1:     Map<String,Object> consultationData
 * @param2:     List<Map<String,Object>> medications
 *@Description:  This method is used to save the consultation details for the patient.
 *               It also creates a prescription record for the patient.
 *************************************************************************************************************/
    @AuraEnabled
    public static void saveConsultation(Map<String,Object> consultationData,List<Map<String,Object>> medications){
        Savepoint sp=Database.setSavepoint();
        try{
            Id doctorId=(Id) consultationData.get('doctorId');
            Id patientId=(Id) consultationData.get('patientId');
            Date visitDate=Date.valueOf((String) consultationData.get('visitDate'));
            Doctor__c doc=[SELECT
                                Name,Consultation_Fees__c
                            FROM
                                Doctor__c
                            WHERE
                                Id=:doctorId LIMIT 1];
            // Fetching Name and Email for Patient
            Account patient=[SELECT
                                Name,PersonEmail
                            FROM
                                Account
                            WHERE
                                Id=:patientId LIMIT 1];
            // 1. Create Consultation Record
            Consultation__c cons=new Consultation__c();
            cons.Doctor__c=doctorId;
            cons.Patient__c=patientId;
            cons.Date_of_Visit__c=visitDate;
            if(consultationData.containsKey('nextVisitDate')&&String.isNotBlank((String)consultationData.get('nextVisitDate'))){
                cons.Next_Visit__c=Date.valueOf((String) consultationData.get('nextVisitDate'));
            }
            if(consultationData.containsKey('numberOfVisits')&&String.isNotBlank(String.valueOf(consultationData.get('numberOfVisits')))){
                cons.Number_of_Visits__c=Decimal.valueOf(String.valueOf(consultationData.get('numberOfVisits')));
            }
            // Fee Calculation Logic
            if(consultationData.containsKey('visitCharges')&&consultationData.get('visitCharges')!=null&&String.isNotBlank(String.valueOf(consultationData.get('visitCharges')))){
                cons.Visit_Charges__c=Decimal.valueOf(String.valueOf(consultationData.get('visitCharges')));
            }else{
                // Query History only if fee calculation is needed
                List<Consultation__c> history=[SELECT
                                                    Date_of_Visit__c 
                                                FROM
                                                    Consultation__c 
                                                WHERE
                                                    Doctor__c=:doctorId 
                                                AND
                                                    Patient__c=:patientId];
                Decimal baseFee=(doc.Consultation_Fees__c!=null)?doc.Consultation_Fees__c:100;
                Map<String,Object> feeInfo=calculateFeeLogic(baseFee,history,visitDate);
                cons.Visit_Charges__c=(Decimal) feeInfo.get('fee');
            }
            insert cons;
            // 2. Create Prescription Record
            Prescription__c presc=new Prescription__c();
            presc.Consultation__c=cons.Id;
            presc.Account__c=patientId;
            presc.Notes__c=(String) consultationData.get('notes');
            insert presc;
            // 3. Create Medication Line Items
            if(medications!=null&&!medications.isEmpty()){
                List<Medication__c> lineItems=new List<Medication__c>();
                for(Map<String,Object> med:medications){
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
                if(!lineItems.isEmpty()){
                    insert lineItems;
                }
            }
            // 4. Update Appointment Status to Completed
            if(consultationData.containsKey('appointmentId')&&String.isNotBlank((String)consultationData.get('appointmentId'))){
                Appointment__c apptToUpdate=new Appointment__c();
                apptToUpdate.Id=(Id) consultationData.get('appointmentId');
                apptToUpdate.Appointment_Status__c='Completed';
                update apptToUpdate;
            }
            // 5. Send Email to Patient
            if(String.isNotBlank(patient.PersonEmail)){
                // We need the Auto-Numbers generated after insert
                Consultation__c consRec=[SELECT
                                            Name
                                        FROM
                                            Consultation__c
                                        WHERE
                                            Id=:cons.Id
                                        LIMIT 1];
                Prescription__c prescRec=[SELECT
                                            Name
                                        FROM
                                            Prescription__c
                                        WHERE
                                            Id=:presc.Id
                                        LIMIT 1];
                sendConsultationEmail(patient,doc,consRec,prescRec,cons,presc,medications);
            }
        }catch(Exception e){
            Database.rollback(sp);
            throw new AuraHandledException('Error saving consultation: '+e.getMessage());
        }
    }
/*******************************************************************************************************************
 * @Author:     CRM Team Innovation
 * @MethodName: calculateFeeLogic
 * @param1:     Decimal baseFee
 * @param2:     List<Consultation__c> history
 * @param3:     Date dateToCheck
 *@Description:  This method is used to calculate the fee for the consultation.
 *****************************************************************************************************/
    private static Map<String,Object> calculateFeeLogic(Decimal baseFee,List<Consultation__c> history,Date dateToCheck){
        Map<String,Object> result=new Map<String,Object>();
        Integer visitsToday=0;
        Integer previousVisits=history.size();
        for(Consultation__c c:history){
            if(c.Date_of_Visit__c==dateToCheck){
                visitsToday++;
            }
        }
        if(visitsToday > 0){
            result.put('fee',0);
            result.put('message','Same day revisit: No Charge');
        }else if(previousVisits > 0){
            result.put('fee',baseFee * 0.5);
            result.put('message','Follow-up Visit: 50% Discount Applied');
        }else{
            result.put('fee',baseFee);
            if(baseFee==0){
                result.put('message','Standard Fee is 0(Check Doctor Record)');
            }else{
                result.put('message','Standard Consultation Fee');
            }
        }
        return result;
    }
/******************************************************************************************************************
 * @Author:     CRM Team Innovation
 * @MethodName: sendConsultationEmail
 * @param1:     Account pat
 * @param2:     Doctor__c doc
 * @param3:     Consultation__c consRec
 * @param4:     Prescription__c prescRec
 * @param5:     Consultation__c cons
 * @param6:     Prescription__c presc
 * @param7:     List<Map<String,Object>> medications
 * @Description:  This method is used to send an email to the patient with the consultation details.
 *****************************************************************************************************************/
    private static void sendConsultationEmail(Account pat,Doctor__c doc,Consultation__c consRec,Prescription__c prescRec,Consultation__c cons,Prescription__c presc,List<Map<String,Object>> medications){
        Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{pat.PersonEmail});
        mail.setSubject('Consultation Summary');
        String body='Dear '+pat.Name+',\n\n';
        body+='Here is the summary of your consultation with Dr. '+doc.Name+' on '+cons.Date_of_Visit__c.format()+'.\n\n';
        body+='Consultation Details:\n';
        body+='Consultation Number: '+consRec.Name+'\n';
        body+='Date: '+cons.Date_of_Visit__c.format()+'\n';
        body+='Charges: '+cons.Visit_Charges__c+'\n\n';
        body+='Prescription Number: '+prescRec.Name+'\n';
        if(String.isNotBlank(presc.Notes__c)){
            body+='Prescription Notes:\n'+presc.Notes__c+'\n';
        }
        body+='\n';
        if(medications!=null&&!medications.isEmpty()){
            body+='Medications:\n';
            for(Map<String,Object> med:medications){
                String medName=(String) med.get('name');
                if(String.isBlank(medName)) continue;
                body+='- '+medName;
                if(med.get('dosage')!=null) body+=',Dosage: '+med.get('dosage');
                if(med.get('frequency')!=null) body+=',Frequency: '+med.get('frequency');
                if(med.get('duration')!=null) body+=',Duration: '+med.get('duration');
                body+='\n';
            }
        }
        body+='\nRegards,\nHospital Management System';
        mail.setPlainTextBody(body);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
    }
}