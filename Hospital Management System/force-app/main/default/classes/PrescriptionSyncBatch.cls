/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   PrescriptionSyncBatch
 * @Description:  This class belongs to client org,where the data is being synced from client org to server org.
 *                This class is responsible for pulling Prescriptions,Medications,and Attachments from Server Org.
 **************************************************************************************************************/
public with sharing class PrescriptionSyncBatch implements Database.Batchable<SObject>,Database.AllowsCallouts,Schedulable,Database.Stateful{

    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:   execute
     * @param1:    SchedulableContext sc
     * @Description: This method is responsible calling the batch class for further logic.
     **************************************************************************************************************/
    public void execute(SchedulableContext sc){
        // Execute batch with a small chunk size because we perform a callout per Account
        Database.executeBatch(new PrescriptionSyncBatch(),5);
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   start
     * @param1:     Database.BatchableContext bc
     * @Description:  This method is responsible fetching the Accounts (Patients)that exist on Server.
     **************************************************************************************************************/
    public Database.QueryLocator start(Database.BatchableContext bc){
        // We iterate over Accounts that have an External ID (meaning they are synced patients)
        return Database.getQueryLocator([SELECT
                                            Id,External_Record_Id__c
                                        FROM
                                            Account
                                        WHERE
                                            External_Record_Id__c!=NULL]);
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   execute
     * @param1:     Database.BatchableContext bc
     * @param2:     List<Account> scope
     * @Description:  This method calls the server for each patient,fetches prescriptions,and upserts them locally.
     **************************************************************************************************************/
    public void execute(Database.BatchableContext bc,List<Account> scope){
        List<Prescription__c> prescriptionsToUpsert=new List<Prescription__c>();
        List<Medication__c> medicationsToUpsert=new List<Medication__c>();
        // Map<LocalEntityId,List<FileMap>>
        Map<String,List<Map<String,Object>>> filesByExternalId=new Map<String,List<Map<String,Object>>>();
        
        for(Account acc:scope){
            try{
                HttpRequest req=new HttpRequest();
                // Call Server to get prescriptions for this patient
                req.setEndpoint('callout:Hospital_Server/services/apexrest/PrescriptionService/?ExternalRecordId='+acc.External_Record_Id__c);
                req.setMethod('GET');
                req.setTimeout(120000);
                Http http=new Http();
                HttpResponse res=http.send(req);
                if(res.getStatusCode()==200){
                    Map<String,Object> responseMap=(Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                    
                    // 1. Handle Prescriptions
                    List<Object> pList=(List<Object>)responseMap.get('Prescriptions');
                    if(pList != null){
                        for(Object obj:pList){
                        Map<String,Object> pMap=(Map<String,Object>)obj;
                        String serverPId=(String)pMap.get('Id');
                        // Prepare Prescription Record
                        Prescription__c p=new Prescription__c();
                        p.Prescription_External_ID__c=serverPId; // Use Server ID as External ID
                        p.Account__c=acc.Id;
                        String notes=(String)pMap.get('Notes');
                        String doctorName=(String)pMap.get('DoctorName');
                        String dateStr=(String)pMap.get('Prescription_Date__c');
                        // Map Doctor Name to specific field
                        if(String.isNotBlank(doctorName)){
                            p.Doctor_s_Name__c=doctorName;
                        }
                        // Map extra fields to Notes
                        String datePrefix=String.isNotBlank(dateStr)? 'Date: ' + dateStr + '\n':'';
                        String existingNotes=notes != null ? notes:'';
                        if (String.isNotBlank(datePrefix)&& existingNotes.startsWith(datePrefix)){
                            p.Notes__c=existingNotes;
                        }else{
                            p.Notes__c=datePrefix + existingNotes;
                        }
                        prescriptionsToUpsert.add(p);
                        // Prepare Medication Records
                        List<Object> meds=(List<Object>)pMap.get('Medications');
                        if(meds!=null){
                            for(Object mObj:meds){
                                Map<String,Object> mMap=(Map<String,Object>)mObj;
                                Medication__c m=new Medication__c();
                                m.External_Record_Id__c=(String)mMap.get('Id'); // Server Medication ID
                                m.Name=(String)mMap.get('MedicationName');
                                m.Dosage__c=(String)mMap.get('Dosage');
                                m.Frequency__c=(String)mMap.get('Frequency');
                                // Link to Parent Prescription via External ID Reference
                                m.Prescription__r=new Prescription__c(Prescription_External_ID__c=serverPId);
                                medicationsToUpsert.add(m);
                            }
                        }
                         // Store Attachment Data if available
                            if(pMap.containsKey('Attachments')){
                                List<Object> atts=(List<Object>)pMap.get('Attachments');
                                List<Map<String,Object>> fileList=new List<Map<String,Object>>();
                                for(Object a:atts) fileList.add((Map<String,Object>)a);
                                filesByExternalId.put(serverPId,fileList);
                            }
                        }
                    }
                    // 2. Handle Account Files
                    if(responseMap.containsKey('AccountFiles')){
                        List<Object> accFiles=(List<Object>)responseMap.get('AccountFiles');
                        List<Map<String,Object>> fileList=new List<Map<String,Object>>();
                        for(Object a:accFiles) fileList.add((Map<String,Object>)a);
                        // Use Account External ID as key
                        filesByExternalId.put(acc.External_Record_Id__c,fileList);
                    }
                }
            }catch(Exception e){
                System.debug('Error syncing for account '+acc.Id+': '+e.getMessage());
            }
        }
        // 1. Upsert Prescriptions
        if(!prescriptionsToUpsert.isEmpty()){
            upsert prescriptionsToUpsert Prescription_External_ID__c;
        }
        // 2. Upsert Medications
        if(!medicationsToUpsert.isEmpty()){
            upsert medicationsToUpsert External_Record_Id__c;
        }
        // 3. Handle Attachments
        if(!filesByExternalId.isEmpty()){
            handleAttachments(filesByExternalId,scope);
        }
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   handleAttachments
     * @param1:     Map<String,List<Map<String,Object>>> filesByExternalId
     * @param2:     List<Account> scope
     * @Description:  This method handles the creation of ContentVersion records for attachments
     *                associated with prescriptions.
     **************************************************************************************************************/
    private void handleAttachments(Map<String,List<Map<String,Object>>> filesByExternalId,List<Account> scope){
        // Map External ID to Local ID and Parent Account ID
        Map<String,Id> externalToLocalIdMap=new Map<String,Id>();
        Map<Id,Id> localIdToAccountIdMap=new Map<Id,Id>();
        // 1. Map Accounts
        for(Account acc:scope){
            externalToLocalIdMap.put(acc.External_Record_Id__c,acc.Id);
            localIdToAccountIdMap.put(acc.Id,acc.Id);
        }
        // 2. Map Prescriptions
        List<Prescription__c> localPrescriptions=[
            SELECT
                Id,Prescription_External_ID__c,Account__c
            FROM
                Prescription__c 
            WHERE
                Prescription_External_ID__c
            IN
                :filesByExternalId.keySet()
        ];
        for(Prescription__c p:localPrescriptions){
            externalToLocalIdMap.put(p.Prescription_External_ID__c,p.Id);
            localIdToAccountIdMap.put(p.Id,p.Account__c);
        }
        // Fetch existing file titles to prevent duplicates
        Map<Id,Set<String>> existingFilesMap=new Map<Id,Set<String>>();
        Set<Id> localIds=new Set<Id>(externalToLocalIdMap.values());
        if(!localIds.isEmpty()){
            for(ContentDocumentLink cdl:[SELECT
                                            LinkedEntityId,ContentDocument.Title
                                        FROM
                                            ContentDocumentLink
                                        WHERE
                                            LinkedEntityId
                                        IN
                                            :localIds]){
                if(!existingFilesMap.containsKey(cdl.LinkedEntityId)){
                    existingFilesMap.put(cdl.LinkedEntityId,new Set<String>());
                }
                existingFilesMap.get(cdl.LinkedEntityId).add(cdl.ContentDocument.Title);
            }
        }

        List<ContentVersion> cvToInsert=new List<ContentVersion>();
        for(String extId:filesByExternalId.keySet()){
            Id localId=externalToLocalIdMap.get(extId);
            if(localId==null) continue;
            List<Map<String,Object>> fileList=filesByExternalId.get(extId);
            for(Map<String,Object> fileData:fileList){
                String fileName=(String)fileData.get('fileName');
                // Check duplication
                if(existingFilesMap.containsKey(localId)&&existingFilesMap.get(localId).contains(fileName)){
                    continue;
                }
                String bodyBase64=(String)fileData.get('body');
                // Create ContentVersion (File)
                ContentVersion cv=new ContentVersion();
                cv.Title=fileName;
                cv.PathOnClient=fileName;
                cv.VersionData=EncodingUtil.base64Decode(bodyBase64);
                cv.FirstPublishLocationId=localId; // Links to Prescription or Account
                cvToInsert.add(cv);
            }
        }
        if(!cvToInsert.isEmpty()){
            insert cvToInsert;
            // Link Prescription files to Account as well
            List<ContentDocumentLink> accountLinks=new List<ContentDocumentLink>();
            for(ContentVersion cv:[SELECT
                                        Id,ContentDocumentId,FirstPublishLocationId
                                    FROM
                                        ContentVersion
                                    WHERE
                                        Id
                                    IN
                                        :cvToInsert]){
                Id parentId=cv.FirstPublishLocationId;
                Id accountId=localIdToAccountIdMap.get(parentId);
                // If parent is Prescription,link to Account. If parent is Account,it's already linked.
                if(parentId != accountId&&accountId != null){
                    ContentDocumentLink cdl=new ContentDocumentLink();
                    cdl.ContentDocumentId=cv.ContentDocumentId;
                    cdl.LinkedEntityId=accountId;
                    cdl.ShareType='V';
                    accountLinks.add(cdl);
                }
            }
            if(!accountLinks.isEmpty()){
                insert accountLinks;
            }
        }
    }
    /********************************************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   finish
     * @param1:     Database.BatchableContext bc
     * @Description:  This method is responsible for logging the success or failure of the batch job.
     ***************************************************************************************************************************/
    public void finish(Database.BatchableContext bc){
    }
}