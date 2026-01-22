/*********************************************************************************************************
 * @Author:     CRM Team Innovation
 * @ClassName: PortalPrescriptionsController
 * @Description:Controller for managing prescription data in the patient portal,
 *                  providing summaries and detailed views of prescriptions.
 *****************************************************************************************************/
public without sharing class PortalPrescriptionsController{
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  getPrescriptionSummaries
     * @Param:       Id accountId
     * Description: Retrieves a list of prescription summaries for a given account.
     ******************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<PrescriptionSummaryDto> getPrescriptionSummaries(Id accountId){
        List<PrescriptionSummaryDto> summaries=new List<PrescriptionSummaryDto>();
        try{
            List<Prescription__c> records=[
                SELECT
                    Id,Name,Doctor_s_Name__c,CreatedDate,Notes__c
                FROM
                    Prescription__c
                WHERE
                    Account__c=:accountId
                ORDER BY
                    CreatedDate
                DESC
                LIMIT 200];
            for(Prescription__c p:records){
                PrescriptionSummaryDto dto=new PrescriptionSummaryDto();
                dto.id=p.Id;
                dto.name=p.Name;
                dto.doctorName=p.Doctor_s_Name__c;
                dto.createdDate=p.CreatedDate;
                // Create a short preview of notes
                dto.shortNotes=(p.Notes__c!=null&&p.Notes__c.length() > 60) 
                ?p.Notes__c.substring(0,60)+'...' 
            :p.Notes__c;
                dto.hasBilling=(p.ContentDocumentLinks!=null&&!p.ContentDocumentLinks.isEmpty());
                // Logic for "Active" status(e.g.,created in last 30 days)
                dto.isActive=(p.CreatedDate >= System.now().addDays(-30));
                summaries.add(dto);
            }
        }catch(Exception e){
            throw new AuraHandledException('Unable to fetch prescriptions:'+e.getMessage());
        }
        return summaries;
    }
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  getPrescriptionDetails
     * @Param:       Id prescriptionId
     * Description: Retrieves detailed information for a specific prescription,
     *                including associated medications and billing documents.
     * ******************************************************************************************************/
    @AuraEnabled
    public static PrescriptionDetailDto getPrescriptionDetails(Id prescriptionId){
        PrescriptionDetailDto detail=new PrescriptionDetailDto();
        try{
            Prescription__c p=[SELECT
                                    Id,Name,Doctor_s_Name__c,CreatedDate,Notes__c,
                        (SELECT 
                                        Name,Dosage__c,Frequency__c,Duration_Days__c
                                    FROM
                                        Medications__r)
                                FROM
                                    Prescription__c
                                WHERE
                                    Id=:prescriptionId];
            detail.id=p.Id;
            detail.name=p.Name;
            detail.doctorName=p.Doctor_s_Name__c;
            detail.createdDate=p.CreatedDate;
            detail.notes=p.Notes__c;
            detail.medications=new List<MedicationDto>();
            if(p.Medications__r!=null){
                for(Medication__c m:p.Medications__r){
                    MedicationDto mDto=new MedicationDto();
                    mDto.name=m.Name;
                    mDto.dosage=m.Dosage__c;
                    mDto.frequency=m.Frequency__c;
                    mDto.durationdays=m.Duration_Days__c;
                    detail.medications.add(mDto);
                }
            }
            if(p.ContentDocumentLinks!=null&&!p.ContentDocumentLinks.isEmpty()){
                ContentDocumentLink cdl=p.ContentDocumentLinks[0];
                detail.contentDocumentId=cdl.ContentDocumentId;
                detail.contentTitle=cdl.ContentDocument.Title;
                detail.contentVersionId=cdl.ContentDocument.LatestPublishedVersionId;
            }
        }catch(Exception e){
            throw new AuraHandledException('Unable to fetch prescription details:'+e.getMessage());
        }
        return detail;
    }
    /*****************************************************************************************************
     *@Author:      CRM Team Innovation
     *@ClassName:  PrescriptionSummaryDto
      *@Description:Data Transfer Object for Prescription Summary
     ******************************************************************************************************/
    public class PrescriptionSummaryDto{
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String doctorName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String shortNotes;
        @AuraEnabled public Boolean hasBilling;
        @AuraEnabled public Boolean isActive;
    }
    /*****************************************************************************************************
     *@Author:      CRM Team Innovation
     *@ClassName:  PrescriptionDetailDto
      *@Description:Data Transfer Object for Prescription Details
     ******************************************************************************************************/
    public class PrescriptionDetailDto{
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String doctorName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String notes;
        @AuraEnabled public List<MedicationDto> medications;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String contentTitle;
        @AuraEnabled public String contentVersionId;
    }
    /*****************************************************************************************************
    *@Author:      CRM Team Innovation
    *@ClassName:  MedicationDto
    *@Description:Data Transfer Object for Medication Details
    ******************************************************************************************************/
    public class MedicationDto{
        @AuraEnabled public String name;
        @AuraEnabled public String dosage;
        @AuraEnabled public String frequency;
        @AuraEnabled public Decimal durationdays;
    }
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  getBillDetails
     * @Param:       Id prescriptionId
     * Description:  Fetches Bill details from external org via REST callout.
     ******************************************************************************************************/
    @AuraEnabled
    public static Map<String,Object> getBillDetails(Id prescriptionId){
        String externalId;
        try{
            Prescription__c pres=[SELECT
                                        Prescription_External_ID__c
                                    FROM
                                        Prescription__c
                                    WHERE
                                        Id=:prescriptionId
                                    LIMIT 1];
            externalId=pres.Prescription_External_ID__c;
        }catch(Exception e){
            throw new AuraHandledException('Prescription record not found.');
        }
        if(String.isBlank(externalId)){
            throw new AuraHandledException('External ID not found for this prescription.');
        }
        try{
            HttpRequest req=new HttpRequest();
            req.setEndpoint('callout:Hospital_Server/services/apexrest/Bill/'+externalId);
            req.setMethod('GET');
            Http http=new Http();
            HttpResponse res=http.send(req);
            if(res.getStatusCode()==200){
                return(Map<String,Object>) JSON.deserializeUntyped(res.getBody());
            }else{
                throw new AuraHandledException('Failed to retrieve Bill data:'+res.getStatus());
            }
        }catch(Exception e){
            throw new AuraHandledException('Error:'+e.getMessage());
        }
    }
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  emailInvoicePdf
     * @Param:       Id prescriptionId
     * Description:  Generates PDF and emails it to the patient.
     ******************************************************************************************************/
    @AuraEnabled
    public static void emailInvoicePdf(Id prescriptionId){
        try{
            if(String.isBlank(prescriptionId)){
                throw new AuraHandledException('Invalid Prescription ID.');
            }
            List<Prescription__c> presList=[SELECT
                                        Name,Account__r.PersonEmail,Account__r.Name,Invoice_Public_Link__c
                                    FROM
                                        Prescription__c
                                    WHERE
                                        Id=:prescriptionId LIMIT 1];
            if(presList.isEmpty()){
                throw new AuraHandledException('Prescription record not found.');
            }
            Prescription__c pres=presList[0];
            if(pres.Account__r==null||String.isBlank(pres.Account__r.PersonEmail)){
                throw new AuraHandledException('No email address found for this patient.');
            }
            if(String.isBlank(pres.Invoice_Public_Link__c)){
                throw new AuraHandledException('No public invoice link found for this prescription.');
            }
            Id oweaId;
            List<OrgWideEmailAddress> oweas = [SELECT
                                                    Id
                                                FROM
                                                    OrgWideEmailAddress LIMIT 1];
            if(!oweas.isEmpty()){
                oweaId = oweas[0].Id;
            }
            if(oweaId == null){
                System.debug(LoggingLevel.ERROR, 'CRITICAL: No Org-Wide Email Address found. Guest Users cannot send emails without one. Please check Setup > Org-Wide Email Addresses and Profile Eligibility.');
            }
            System.enqueueJob(new EmailPdfQueueable(pres.Account__r.PersonEmail,pres.Name,pres.Account__r.Name, oweaId, pres.Invoice_Public_Link__c));
        }catch(Exception e){
            throw new AuraHandledException('Error initiating email:'+e.getMessage());
        }
    }
    public without sharing class EmailPdfQueueable implements Queueable,Database.AllowsCallouts {
        private String emailAddress;
        private String prescriptionName;
        private String patientName;
        private Id oweaId;
        private String publicLink;
        public EmailPdfQueueable(String emailAddress,String prescriptionName,String patientName, Id oweaId, String publicLink){
            this.emailAddress=emailAddress;
            this.prescriptionName=prescriptionName;
            this.patientName=patientName;
            this.oweaId=oweaId;
            this.publicLink=publicLink;
        }
        public void execute(QueueableContext context){
            try {
                Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{emailAddress});
                // Professional Subject
                mail.setSubject('Invoice for Prescription '+prescriptionName+' - General Hospital');
                // Rich HTML Body
                String htmlBody='<div style="font-family:Helvetica,Arial,sans-serif; font-size:14px; color:#333; line-height:1.5;">'+
                    '<div style="background-color:#f4f6f9; padding:20px; text-align:center; border-bottom:4px solid #0070d2;">'+
                    '<h1 style="margin:0; color:#0070d2; font-size:24px;">General Hospital</h1>'+
                    '</div>'+
                    '<div style="padding:30px; background-color:#ffffff;">'+
                    '<p>Dear '+(String.isBlank(patientName)?'Patient':patientName)+',</p>'+
                    '<p>We hope this email finds you well.</p>'+
                    '<p>You can view and download the invoice for your recent prescription <strong>'+prescriptionName+'</strong> by clicking the link below:</p>'+
                    '<div style="text-align: center; margin: 20px 0;">'+
                    '<a href="'+publicLink+'" style="background-color:#0070d2; color:#ffffff; padding:12px 24px; text-decoration:none; border-radius:4px; font-weight:bold; display:inline-block;">View Invoice</a>'+
                    '</div>'+
                    '<p>If you have any questions regarding this invoice,please do not hesitate to contact our billing department.</p>'+
                    '<br/>'+
                    '<p>Sincerely,</p>'+
                    '<p><strong>General Hospital Team</strong><br/>'+
                    '<span style="color:#888; font-size:12px;">Balewadi High Street,Pune,Maharashtra</span></p>'+
                    '</div>'+
                    '<div style="background-color:#f4f6f9; padding:10px; text-align:center; color:#888; font-size:11px;">'+
                    '&copy; '+System.today().year()+' General Hospital. All rights reserved.'+
                    '</div>'+
                    '</div>';
                
                mail.setHtmlBody(htmlBody);
                mail.setPlainTextBody('Dear '+(String.isBlank(patientName)?'Patient':patientName)+',\n\nYou can view and download the invoice for your recent prescription '+prescriptionName+' here: '+publicLink+'\n\nSincerely,\nGeneral Hospital Team');
                if(oweaId != null){
                    mail.setOrgWideEmailAddressId(oweaId);
                } else {
                    mail.setSenderDisplayName('General Hospital');
                }
                
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
            }catch(Exception e) {
                System.debug('Error in EmailPdfQueueable:'+e.getMessage());
            }
        }
    }
}