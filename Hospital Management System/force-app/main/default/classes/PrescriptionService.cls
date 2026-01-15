/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   PrescriptionService
 * @Description: This Class exposes the Prescription data to REST API.
 *****************************************************************************************************/
@RestResource(urlMapping='/PrescriptionService/*')
global with sharing class PrescriptionService{
    @HttpGet
    global static void getPrescriptions(){
        RestRequest req=RestContext.request;
        RestResponse response=RestContext.response;
        String patientId=req.params.get('ExternalRecordId');
        if (String.isBlank(patientId)){
            response.responseBody=Blob.valueOf('[]');
            response.addHeader('Content-Type','application/json');
            return;
        }
        // Fetch Prescriptions and related Line Items (Medications)
        List<Prescription__c> prescriptions=[
            SELECT
                Id,Name,CreatedDate,Consultation__r.Doctor__r.Name,Notes__c,
                (SELECT
                    Id,Name,Dosage__c,Frequency__c
                FROM
                    Medications__r)
            FROM
                Prescription__c
            WHERE
                Account__c=:patientId
            WITH
                SECURITY_ENFORCED
            ORDER BY
                CreatedDate DESC
        ];
        // Fetch Attachments (ContentDocuments) for these prescriptions
        Set<Id> pIds=new Set<Id>();
        for(Prescription__c p:prescriptions){
            pIds.add(p.Id);
        }
        Map<Id,Map<String,Object>> attachmentMap=new Map<Id,Map<String,Object>>();
        for(ContentDocumentLink link:[SELECT
                                            LinkedEntityId,ContentDocument.Title,ContentDocument.FileExtension,
                                            ContentDocument.LatestPublishedVersion.VersionData
                                        FROM
                                            ContentDocumentLink
                                        WHERE
                                            LinkedEntityId IN :pIds]){
            attachmentMap.put(link.LinkedEntityId,new Map<String,Object>{
                'fileName' => link.ContentDocument.Title + '.' + link.ContentDocument.FileExtension,
                'body' => EncodingUtil.base64Encode(link.ContentDocument.LatestPublishedVersion.VersionData)
            });
        }
        List<Map<String,Object>> results=new List<Map<String,Object>>();
        for (Prescription__c p:prescriptions){
            Map<String,Object> res=new Map<String,Object>();
            res.put('Id',p.Id);
            res.put('Name',p.Name);
            res.put('Prescription_Date__c',p.CreatedDate.date());
            res.put('DoctorName',(p.Consultation__r!=null && p.Consultation__r.Doctor__r!=null)?p.Consultation__r.Doctor__r.Name:'');
            res.put('Notes',p.Notes__c);   
            if(attachmentMap.containsKey(p.Id)) res.put('Attachment',attachmentMap.get(p.Id));
            List<Map<String,Object>> meds=new List<Map<String,Object>>();
            for (Medication__c item:p.Medications__r){
                Map<String,Object> m=new Map<String,Object>();
                m.put('Id',item.Id);
                m.put('MedicationName',item!=null?item.Name:'');
                m.put('Dosage',item.Dosage__c);
                m.put('Frequency',item.Frequency__c);
                meds.add(m);
            }
            res.put('Medications',meds);
            results.add(res);
        }
        response.responseBody=Blob.valueOf(JSON.serialize(results));
        response.addHeader('Content-Type','application/json');
    }
}