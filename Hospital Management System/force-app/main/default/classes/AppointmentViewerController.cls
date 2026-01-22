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
                    Visit_Charges__c,Next_Visit__c
                FROM
                    Consultation__c
                WHERE
                    Patient__c=:patientId
                ORDER BY
                    Date_of_Visit__c DESC];
    }
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPatientPrescriptions(String patientId){
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        List<Prescription__c> prescriptions = [SELECT 
                    Id,Name,CreatedDate,Consultation__r.Doctor__r.Name,Notes__c,
                    Consultation__r.Date_of_Visit__c
                FROM
                    Prescription__c
                WHERE
                    Account__c=:patientId
                ORDER BY
                    CreatedDate DESC];
        
        if(prescriptions.isEmpty()) {
            return result;
        }

        Set<Id> prescIds = new Set<Id>();
        for(Prescription__c p : prescriptions) {
            prescIds.add(p.Id);
        }

        // Fetch Opportunities and Line Items (Medicines)
        List<Opportunity> opps = [SELECT Id, Prescription__c, 
                                    (SELECT Id, Product2.Name, Quantity, Description FROM OpportunityLineItems) 
                                  FROM Opportunity 
                                  WHERE Prescription__c IN :prescIds];
        
        Map<Id, List<Map<String, Object>>> prescToMeds = new Map<Id, List<Map<String, Object>>>();
        for(Opportunity opp : opps) {
            if(opp.Prescription__c != null) {
                List<Map<String, Object>> meds = new List<Map<String, Object>>();
                for(OpportunityLineItem oli : opp.OpportunityLineItems) {
                    Map<String, Object> med = new Map<String, Object>();
                    med.put('Id', oli.Id);
                    med.put('productName', oli.Product2.Name);
                    med.put('quantity', oli.Quantity);
                    med.put('description', oli.Description);
                    meds.add(med);
                }
                prescToMeds.put(opp.Prescription__c, meds);
            }
        }

        for(Prescription__c p : prescriptions) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id', p.Id);
            row.put('Name', p.Name);
            row.put('Notes__c', p.Notes__c);
            row.put('CreatedDate', p.CreatedDate);
            
            String docName = (p.Consultation__r != null && p.Consultation__r.Doctor__r != null) ? p.Consultation__r.Doctor__r.Name : 'Unknown Doctor';
            row.put('DoctorName', docName);

            Date visitDate = (p.Consultation__r != null && p.Consultation__r.Date_of_Visit__c != null) ? p.Consultation__r.Date_of_Visit__c : Date.valueOf(p.CreatedDate);
            row.put('VisitDate', visitDate);

            if(prescToMeds.containsKey(p.Id)) {
                row.put('medications', prescToMeds.get(p.Id));
            } else {
                row.put('medications', new List<Map<String, Object>>());
            }
            result.add(row);
        }
        
        return result;
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
            
            // 3. Create Opportunity and Line Items (Medicines)
            if(medications!=null&&!medications.isEmpty()){
                handleMedicines(medications, patientId, presc.Id);
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

    private static void handleMedicines(List<Map<String,Object>> medications, Id patientId, Id prescriptionId) {
        // Fetch Prescription Name and Patient Name for Opportunity Naming
        Prescription__c presc = [SELECT
                                    Name, Account__r.Name
                                FROM
                                    Prescription__c
                                WHERE
                                    Id = :prescriptionId LIMIT 1];
        
        // Create Opportunity
        Opportunity opp = new Opportunity();
        opp.Name = presc.Account__r.Name + ' - ' + presc.Name;
        opp.StageName = 'Closed Won';
        opp.CloseDate = Date.today();
        opp.Prescription__c = prescriptionId; 
        insert opp;

        // Collect Product IDs
        Set<Id> productIds = new Set<Id>();
        for(Map<String,Object> med : medications) {
            if(med.containsKey('productId') && String.isNotBlank((String)med.get('productId'))) {
                productIds.add((Id)med.get('productId'));
            }
        }

        if(productIds.isEmpty()) return;

        // Get Standard Pricebook ID
        Id pricebookId;
        if(Test.isRunningTest()) {
            pricebookId = Test.getStandardPricebookId();
        } else {
            Pricebook2 stdPb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            pricebookId = stdPb.Id;
        }

        // Fetch PricebookEntries for Products
        Map<Id, Id> pbeMap = new Map<Id, Id>();
        for(PricebookEntry pbe : [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND Product2Id IN :productIds]) {
            pbeMap.put(pbe.Product2Id, pbe.Id);
        }

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
        for(Map<String,Object> med : medications) {
            Id prodId = (Id)med.get('productId');
            if(String.isBlank(prodId)) continue;

            if(!pbeMap.containsKey(prodId)) {
                throw new AuraHandledException('Selected medicine is not in the Standard Pricebook.');
            }

            OpportunityLineItem oli = new OpportunityLineItem();
            oli.OpportunityId = opp.Id;
            oli.PricebookEntryId = pbeMap.get(prodId);
            oli.Product2Id = prodId;
            oli.Quantity = Decimal.valueOf(String.valueOf(med.get('quantity')));
            oli.Description = (String)med.get('instructions');
            oli.TotalPrice = 0; // No pricing logic required
            oliList.add(oli);
        }
        insert oliList;
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