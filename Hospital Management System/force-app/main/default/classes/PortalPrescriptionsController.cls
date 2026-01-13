/*********************************************************************************************************
 * @Author:      CRM Team Innovation
 * @ClassName:  PortalPrescriptionsController
 * @Description: Controller for managing prescription data in the patient portal,
 *                  providing summaries and detailed views of prescriptions.
 *****************************************************************************************************/
public with sharing class PortalPrescriptionsController{
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   getPrescriptionSummaries
     * @Param:        Id accountId
     * Description:  Retrieves a list of prescription summaries for a given account.
     ******************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<PrescriptionSummaryDto> getPrescriptionSummaries(Id accountId){
        List<PrescriptionSummaryDto> summaries=new List<PrescriptionSummaryDto>();
        try{
            List<Prescription__c> records=[
                SELECT
                    Id,Name,Doctor_s_Name__c,CreatedDate,Notes__c,
                (SELECT 
                        Id 
                    FROM
                        ContentDocumentLinks LIMIT 1)
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
                    ? p.Notes__c.substring(0,60) + '...' 
                :p.Notes__c;
                dto.hasBilling=(p.ContentDocumentLinks!=null&&!p.ContentDocumentLinks.isEmpty());
                // Logic for "Active" status(e.g.,created in last 30 days)
                dto.isActive=(p.CreatedDate >= System.now().addDays(-30));
                summaries.add(dto);
            }
        }catch(Exception e){
            throw new AuraHandledException('Unable to fetch prescriptions: ' + e.getMessage());
        }
        return summaries;
    }
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   getPrescriptionDetails
     * @Param:        Id prescriptionId
     * Description:  Retrieves detailed information for a specific prescription,
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
                                        Medications__r),
                                (SELECT
                                        ContentDocumentId,ContentDocument.Title,ContentDocument.LatestPublishedVersionId
                                    FROM
                                        ContentDocumentLinks
                                LIMIT 1)
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
            throw new AuraHandledException('Unable to fetch prescription details: ' + e.getMessage());
        }
        return detail;
    }
    /*****************************************************************************************************
     *@Author:       CRM Team Innovation
     *@ClassName:   PrescriptionSummaryDto
      *@Description: Data Transfer Object for Prescription Summary
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
     *@Author:       CRM Team Innovation
     *@ClassName:   PrescriptionDetailDto
      *@Description: Data Transfer Object for Prescription Details
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
    *@Author:       CRM Team Innovation
    *@ClassName:   MedicationDto
    *@Description: Data Transfer Object for Medication Details
    ******************************************************************************************************/
    public class MedicationDto{
        @AuraEnabled public String name;
        @AuraEnabled public String dosage;
        @AuraEnabled public String frequency;
        @AuraEnabled public Decimal durationdays;
    }
}