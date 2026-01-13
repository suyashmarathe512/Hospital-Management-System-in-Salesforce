/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   PrescriptionSyncBatch
 * @Description:  This class belongs to client org,where the data is being synced from client org to server org.
 *                This class is responsible for pulling Prescriptions,Medications,and Attachments from Server Org.
 **************************************************************************************************************/
public with sharing class PrescriptionSyncBatch implements Database.Batchable<SObject>,Database.AllowsCallouts, Schedulable, Database.Stateful{

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
     * @Description:  This method is responsible fetching the Accounts (Patients) that exist on Server.
     **************************************************************************************************************/
    public Database.QueryLocator start(Database.BatchableContext bc){
        // We iterate over Accounts that have an External ID (meaning they are synced patients)
        return Database.getQueryLocator([SELECT Id,External_Record_Id__c FROM Account WHERE External_Record_Id__c!=NULL]);
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
        Map<String,Map<String,Object>> attachmentDataMap=new Map<String, Map<String, Object>>();
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
                    List<Object> results=(List<Object>) JSON.deserializeUntyped(res.getBody());
                    for(Object obj:results){
                        Map<String,Object> pMap=(Map<String,Object>) obj;
                        String serverPId=(String) pMap.get('Id');
                        // Prepare Prescription Record
                        Prescription__c p=new Prescription__c();
                        p.Prescription_External_ID__c=serverPId; // Use Server ID as External ID
                        p.Account__c=acc.Id;
                        String notes=(String) pMap.get('Notes');
                        String doctorName=(String) pMap.get('DoctorName');
                        String dateStr=(String) pMap.get('Prescription_Date__c');
                        // Map Doctor Name to specific field
                        if(String.isNotBlank(doctorName)){
                            p.Doctor_s_Name__c=doctorName;
                        }
                        // Map extra fields to Notes
                        p.Notes__c=(String.isNotBlank(dateStr)?'Date: '+dateStr+'\n':'')+(notes!=null?notes:'');
                        prescriptionsToUpsert.add(p);
                        // Prepare Medication Records
                        List<Object> meds=(List<Object>) pMap.get('Medications');
                        if(meds!=null){
                            for(Object mObj:meds){
                                Map<String,Object> mMap=(Map<String,Object>) mObj;
                                Medication__c m=new Medication__c();
                                m.External_Record_Id__c=(String) mMap.get('Id'); // Server Medication ID
                                m.Name=(String) mMap.get('MedicationName');
                                m.Dosage__c=(String) mMap.get('Dosage');
                                m.Frequency__c=(String) mMap.get('Frequency');
                                // Link to Parent Prescription via External ID Reference
                                m.Prescription__r=new Prescription__c(Prescription_External_ID__c=serverPId);
                                medicationsToUpsert.add(m);
                            }
                        }
                         // Store Attachment Data if available
                        if(pMap.containsKey('Attachment')){
                            attachmentDataMap.put(serverPId,(Map<String, Object>) pMap.get('Attachment'));
                        }
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
        if(!attachmentDataMap.isEmpty()){
            handleAttachments(attachmentDataMap);
        }
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   handleAttachments
     * @param1:     Map<String,Map<String,Object>> attachmentDataMap
     * @Description:  This method handles the creation of ContentVersion records for attachments
     *                associated with prescriptions.
     **************************************************************************************************************/
    private void handleAttachments(Map<String,Map<String,Object>> attachmentDataMap){
        // Get Local IDs for the Server Prescription IDs
        List<Prescription__c> localPrescriptions=[
            SELECT
                Id,Prescription_External_ID__c 
            FROM
                Prescription__c 
            WHERE
                Prescription_External_ID__c
            IN
                :attachmentDataMap.keySet()
        ];
        List<ContentVersion> cvToInsert=new List<ContentVersion>();
        for(Prescription__c p:localPrescriptions){
            Map<String,Object> fileData=attachmentDataMap.get(p.Prescription_External_ID__c);
            if(fileData!=null){
                String fileName=(String) fileData.get('fileName');
                String bodyBase64=(String) fileData.get('body');
                // Create ContentVersion (File)
                ContentVersion cv=new ContentVersion();
                cv.Title=fileName;
                cv.PathOnClient=fileName;
                cv.VersionData=EncodingUtil.base64Decode(bodyBase64);
                cv.FirstPublishLocationId=p.Id; // Automatically links to the Prescription record
                cvToInsert.add(cv);
            }
        }
        if(!cvToInsert.isEmpty()){
            insert cvToInsert;
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