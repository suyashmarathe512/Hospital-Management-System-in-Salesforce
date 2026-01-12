/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @ClassName:    FileService
 * @Description:  This Class belongs to server org.
 *                This class exposes a REST API to fetch files associated with an Account.
 **************************************************************************************************************/
@RestResource(urlMapping='/FileService/*')
global with sharing class FileService{
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   getFiles
     * @Return:       Map<String,List<FileResponseWrapper>>
     * @Description:  HttpGet method to retrieve files linked to an Account via ExternalRecordId.
     ******************************************************************************************************/
    @HttpGet
    global static Map<String,List<FileResponseWrapper>> getFiles(){
        RestRequest req=RestContext.request;
        String accountId=req.params.get('ExternalRecordId');
        Map<String,List<FileResponseWrapper>> result=new Map<String,List<FileResponseWrapper>>();
        if(String.isNotBlank(accountId)){
            Set<Id> contentDocumentIds=new Set<Id>();
            for(ContentDocumentLink link:[SELECT 
                                                ContentDocumentId
                                            FROM
                                                ContentDocumentLink
                                            WHERE
                                                LinkedEntityId=:accountId]){
                contentDocumentIds.add(link.ContentDocumentId);
            }
            if(!contentDocumentIds.isEmpty()){
                List<ContentVersion> files=[
                    SELECT
                        Id,Title,FileType,FileExtension,VersionData,ContentDocumentId 
                    FROM
                        ContentVersion 
                    WHERE
                        ContentDocumentId
                    IN
                        :contentDocumentIds
                    AND
                        IsLatest=true
                ];
                List<FileResponseWrapper> wrappers=new List<FileResponseWrapper>();
                for(ContentVersion cv:files){
                    FileResponseWrapper wrapper=new FileResponseWrapper();
                    wrapper.title=cv.Title;
                    wrapper.fileExtension=cv.FileExtension;
                    wrapper.versionData=EncodingUtil.base64Encode(cv.VersionData);
                    wrappers.add(wrapper);
                }
                result.put(accountId,wrappers);
            }
        }
        return result;
    }
/*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   FileResponseWrapper
     * @Description:  Wrapper class for file response.
     ******************************************************************************************************/
    global class FileResponseWrapper{
        public String title;
        public String fileExtension;
        public String versionData;
    }
}