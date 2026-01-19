/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName: ContentDocumentTriggerHandler
 * @Description: Handles public link creation when files are attached to Prescription records
 *****************************************************************************************************/
public without sharing class ContentDocumentTriggerHandler {

    /*********************************************************************************************************
     * @MethodName: handleAfterInsert
     * @param: List<ContentDocumentLink>
     * @Description: Creates a public link for Prescription attachments and stores it if not already present
     *****************************************************************************************************/
    public void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        Set<Id> prescriptionIds = new Set<Id>();
        List<ContentDocumentLink> relevantLinks = new List<ContentDocumentLink>();

        // Filter links related to Prescription__c
        for (ContentDocumentLink link : newLinks) {
            if (link.LinkedEntityId != null && 
                link.LinkedEntityId.getSObjectType() == Prescription__c.SObjectType) {
                prescriptionIds.add(link.LinkedEntityId);
                relevantLinks.add(link);
            }
        }

        if (prescriptionIds.isEmpty()) {
            return;
        }

        // Query Prescriptions to check if link already exists
        Map<Id, Prescription__c> prescriptionMap = new Map<Id, Prescription__c>([
            SELECT Id, Invoice_Public_Link__c 
            FROM Prescription__c 
            WHERE Id IN :prescriptionIds
        ]);

        Set<Id> docIds = new Set<Id>();
        List<ContentDocumentLink> linksToProcess = new List<ContentDocumentLink>();
        Set<Id> processedPrescriptions = new Set<Id>();

        for (ContentDocumentLink link : relevantLinks) {
            Prescription__c p = prescriptionMap.get(link.LinkedEntityId);
            // Skip if prescription not found, already has link, or we already processed this prescription in this batch
            if (p != null && p.Invoice_Public_Link__c == null && !processedPrescriptions.contains(p.Id)) {
                docIds.add(link.ContentDocumentId);
                linksToProcess.add(link);
                processedPrescriptions.add(p.Id);
            }
        }

        if (linksToProcess.isEmpty()) {
            return;
        }

        // Get latest ContentVersion for the documents
        Map<Id, Id> docIdToVersionId = new Map<Id, Id>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :docIds 
            AND IsLatest = true
        ]) {
            docIdToVersionId.put(cv.ContentDocumentId, cv.Id);
        }

        List<ContentDistribution> distributionsToInsert = new List<ContentDistribution>();
        
        for (ContentDocumentLink link : linksToProcess) {
            Id versionId = docIdToVersionId.get(link.ContentDocumentId);
            if (versionId != null) {
                ContentDistribution cd = new ContentDistribution();
                cd.Name = 'Prescription Invoice';
                cd.ContentVersionId = versionId;
                cd.PreferencesAllowViewInBrowser = true;
                cd.PreferencesAllowOriginalDownload = true;
                cd.RelatedRecordId = link.LinkedEntityId; // Link to Prescription
                distributionsToInsert.add(cd);
            }
        }

        if (!distributionsToInsert.isEmpty()) {
            insert distributionsToInsert;

            // Query back to get the Public URL
            List<Prescription__c> prescriptionsToUpdate = new List<Prescription__c>();
            for (ContentDistribution cd : [
                SELECT Id, DistributionPublicUrl, RelatedRecordId 
                FROM ContentDistribution 
                WHERE Id IN :distributionsToInsert
            ]) {
                if (cd.RelatedRecordId != null && cd.DistributionPublicUrl != null) {
                    prescriptionsToUpdate.add(new Prescription__c(
                        Id = cd.RelatedRecordId,
                        Invoice_Public_Link__c = cd.DistributionPublicUrl
                    ));
                }
            }

            if (!prescriptionsToUpdate.isEmpty()) {
                update prescriptionsToUpdate;
            }
        }
    }
}