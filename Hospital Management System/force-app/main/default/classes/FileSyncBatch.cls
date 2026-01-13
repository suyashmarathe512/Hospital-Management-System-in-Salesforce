/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @ClassName:    FileSyncBatch
 * @Description:  This Class belongs to client org.
 *                This batch class syncs files from the server org based on External_Record_Id__c.
 **************************************************************************************************************/
public with sharing class FileSyncBatch implements Database.Batchable<sObject>,Database.AllowsCallouts,Schedulable{
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   start
     * @Param:        Database.BatchableContext BC
     * @Description:  Queries Person Accounts with a populated External_Record_Id__c.
     * @Return:       Database.QueryLocator
     ******************************************************************************************************/
    public Database.QueryLocator start(Database.BatchableContext BC){
        // Query Accounts that have the External Record ID populated
        return Database.getQueryLocator([
            SELECT
                Id,External_Record_Id__c 
            FROM
                Account 
            WHERE
                External_Record_Id__c!=null
            AND
                IsPersonAccount=true
        ]);
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   execute
     * @Param:        Database.BatchableContext BC
     * @Param:        List<Account> scope
     * @Description:  Makes a callout to the server to fetch files and inserts them as ContentVersions.
     ******************************************************************************************************/
    public void execute(Database.BatchableContext BC,List<Account> scope){
        List<ContentVersion> filesToInsert=new List<ContentVersion>();
        
        // Map to store existing file titles for each Account to prevent duplicates
        Map<Id,Set<String>> existingFileTitles=new Map<Id,Set<String>>();
        Set<Id> accountIds=new Set<Id>();
        for(Account acc:scope){
            accountIds.add(acc.Id);
        }
        // Fetch existing file titles linked to these accounts
        for(ContentDocumentLink link:[SELECT
                                            LinkedEntityId,ContentDocument.Title
                                        FROM
                                            ContentDocumentLink
                                        WHERE
                                            LinkedEntityId
                                        IN
                                            :accountIds]){
            if(!existingFileTitles.containsKey(link.LinkedEntityId)){
                existingFileTitles.put(link.LinkedEntityId,new Set<String>());
            }
            existingFileTitles.get(link.LinkedEntityId).add(link.ContentDocument.Title);
        }
        Http http=new Http();
        for(Account acc:scope){
            HttpRequest req=new HttpRequest();
            // Use a Named Credential(e.g.,Hospital_Server) for the endpoint
            req.setEndpoint('callout:Hospital_Server/services/apexrest/FileService?ExternalRecordId='+EncodingUtil.urlEncode(acc.External_Record_Id__c,'UTF-8'));
            req.setMethod('GET');
            try{
                HttpResponse res=http.send(req);
                if(res.getStatusCode() == 200){
                    // Deserialize the response: Map<ExternalId,List<FileResponseWrapper>>
                    Map<String,List<FileResponseWrapper>> responseMap=(Map<String,List<FileResponseWrapper>>) JSON.deserialize(res.getBody(),Map<String,List<FileResponseWrapper>>.class);
                    if(responseMap!=null && responseMap.containsKey(acc.External_Record_Id__c)){
                        List<FileResponseWrapper> incomingFiles=responseMap.get(acc.External_Record_Id__c);
                        if(incomingFiles!=null){
                            Set<String> currentAccountTitles=existingFileTitles.containsKey(acc.Id)? existingFileTitles.get(acc.Id):new Set<String>();
                            for(FileResponseWrapper fw:incomingFiles){
                                // Skip if a file with this title already exists for this account
                                if(currentAccountTitles.contains(fw.title)){
                                    continue;
                                }
                                ContentVersion newFile=new ContentVersion();
                                newFile.Title=fw.title;
                                newFile.PathOnClient=fw.title+'.'+fw.fileExtension;
                                newFile.VersionData=EncodingUtil.base64Decode(fw.versionData);
                                newFile.FirstPublishLocationId=acc.Id; // Automatically creates ContentDocumentLink
                                filesToInsert.add(newFile);
                                // Add to set to prevent duplicates within the same batch run
                                currentAccountTitles.add(fw.title);
                            }
                        }
                    }
                }
            }catch(Exception e){
                System.debug('Error syncing files for Account '+acc.Id+': '+e.getMessage());
            }
        }
        if(!filesToInsert.isEmpty()){
            insert filesToInsert;
        }
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   finish
     * @Param:        Database.BatchableContext BC
     * @Description:  Logs completion of the batch job.
     ******************************************************************************************************/
    public void finish(Database.BatchableContext BC){
        System.debug('File Sync Batch Finished');
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   execute
     * @Param:        SchedulableContext sc
     * @Description:  Schedules the batch execution with a batch size of 1 to avoid heap limits.
     ******************************************************************************************************/
    public void execute(SchedulableContext sc){
        // Run with batch size 10 to avoid heap limits with file data
        Database.executeBatch(new FileSyncBatch(),10);
    }
/*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   FileResponseWrapper
     * @Description:  Wrapper class for file response.
     ******************************************************************************************************/
    public class FileResponseWrapper{
        public String title;
        public String fileExtension;
        public String versionData;
    }
}