public with sharing class BillTriggerHandler{
    private ApexPages.StandardController stdController;
    // Constructor to support Visualforce Extension
    public BillTriggerHandler(ApexPages.StandardController stdController){
        this.stdController=stdController;
    }
    // Action method invoked by the Visualforce page
    public void attemptEmail(){
        String sendEmailParam=ApexPages.currentPage().getParameters().get('sendEmail');
        if(sendEmailParam=='true'&&stdController.getId()!=null){
            sendBillEmail(new List<Id>{stdController.getId()});
        }
    }
    @AuraEnabled
    public static void sendBillEmail(List<Id> billIds){
        // Query Bill details and related Line Items
        List<Bill__c> bills=[SELECT 
                                    Id,Name,Billing_Date__c,Tax_Percentage__c,Sub_Total__c,Total_Amount__c,
                                    Patient__c,Patient__r.Name,Patient__r.PersonEmail,
                                    Consultation__c,Consultation__r.Name,Consultation__r.Doctor__r.Name,
                                    Prescription__c,Prescription__r.Name,
                                (SELECT 
                                        Name,Medication__c,Medication__r.Name,Unit_Price__c,Quantity__c,Line_Total__c 
                                    FROM 
                                        Bill_Line_Items__r)
                                FROM 
                                    Bill__c
                                WHERE 
                                    Id IN :billIds];

        List<Messaging.SingleEmailMessage> emails=new List<Messaging.SingleEmailMessage>();
        Map<Id,Blob> billPdfMap=new Map<Id,Blob>();
        List<ContentVersion> cvList=new List<ContentVersion>();
        List<Bill__c> billsWithPdf=new List<Bill__c>();
        // 1. Generate PDFs and Prepare ContentVersions
        for(Bill__c bill : bills){
            PageReference pdf=Page.BillPDF;
            pdf.getParameters().put('id',bill.Id);
            Blob pdfBlob;
            if(!Test.isRunningTest()){
                pdfBlob=pdf.getContentAsPDF();
            } else{
                pdfBlob=Blob.valueOf('Test PDF');
            }
            billPdfMap.put(bill.Id,pdfBlob);
            // Create ContentVersion
            ContentVersion cv=new ContentVersion();
            cv.Title='Invoice_'+bill.Name;
            cv.PathOnClient='Invoice_'+bill.Name+'.pdf';
            cv.VersionData=pdfBlob;
            cv.FirstPublishLocationId=bill.Id; // Automatically links to the Bill
            cvList.add(cv);
            billsWithPdf.add(bill);
        }
        // 2. Insert ContentVersions
        if(!cvList.isEmpty()){
            insert cvList;
        }
        // 3. Map Bill Id to ContentDocumentId
        // We use the list index to map back since cvList matches billsWithPdf order
        Map<Id,Id> cvIdToBillId=new Map<Id,Id>();
        for(Integer i=0; i < cvList.size(); i++){
            cvIdToBillId.put(cvList[i].Id,billsWithPdf[i].Id);
        }
        List<ContentVersion> insertedCVs=[SELECT
                                            Id,ContentDocumentId
                                        FROM
                                            ContentVersion
                                        WHERE
                                            Id
                                        IN
                                            :cvList];
        Map<Id,Id> billIdToContentDocId=new Map<Id,Id>();
        for(ContentVersion cv : insertedCVs){
            if(cvIdToBillId.containsKey(cv.Id)){
                billIdToContentDocId.put(cvIdToBillId.get(cv.Id),cv.ContentDocumentId);
            }
        }
        // 4. Create ContentDocumentLinks and Emails
        List<ContentDocumentLink> cdLinks=new List<ContentDocumentLink>();
        for(Bill__c bill : bills){
            Id contentDocId=billIdToContentDocId.get(bill.Id);
            // Link to Patient,Consultation,Prescription
            if(contentDocId!=null){
                Set<Id> linkedEntityIds=new Set<Id>();
                if(bill.Patient__c!=null) linkedEntityIds.add(bill.Patient__c);
                if(bill.Consultation__c!=null) linkedEntityIds.add(bill.Consultation__c);
                if(bill.Prescription__c!=null) linkedEntityIds.add(bill.Prescription__c);
                for(Id linkedId : linkedEntityIds){
                    ContentDocumentLink cdl=new ContentDocumentLink();
                    cdl.ContentDocumentId=contentDocId;
                    cdl.LinkedEntityId=linkedId;
                    cdl.ShareType='V'; // Viewer permission
                    cdl.Visibility='AllUsers';
                    cdLinks.add(cdl);
                }
            }
            // Prepare Email
            if(String.isNotBlank(bill.Patient__r.PersonEmail)&&billPdfMap.containsKey(bill.Id)){
                Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{bill.Patient__r.PersonEmail});
                mail.setSubject('Invoice '+bill.Name+' - Hospital Management System');
                String body='Dear '+bill.Patient__r.Name+',\n\n';
                body+='We hope you are recovering well.\n\n';
                body+='Please find attached the invoice for your recent visit.\n';
                body+='--------------------------------------------------\n';
                body+='Bill Number: '+bill.Name+'\n';
                body+='Date: ' +(bill.Billing_Date__c!=null ? bill.Billing_Date__c.format() : '')+'\n';
                body+='Total Amount: '+bill.Total_Amount__c+'\n';
                body+='--------------------------------------------------\n\n';
                body+='If you have any questions regarding this bill,please contact our billing department.\n\n';
                body+='Regards,\nHospital Management System';
                mail.setPlainTextBody(body);
                Messaging.EmailFileAttachment attach=new Messaging.EmailFileAttachment();
                attach.setFileName('Invoice_'+bill.Name+'.pdf');
                attach.setBody(billPdfMap.get(bill.Id));
                mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{attach});
                emails.add(mail);
            }
        }
        if(!cdLinks.isEmpty()){
            insert cdLinks;
        }
        if(!emails.isEmpty()){
            Messaging.sendEmail(emails);
        }
    }
}