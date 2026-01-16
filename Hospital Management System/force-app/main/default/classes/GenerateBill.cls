/*****************************************************************************************************
 * @Author:      CRM Team Innovation
 * @ClassName:   GenerateBill
 * @Description: Controller for the Generate Bill LWC. Handles fetching prescription context and creating bill records.
 ******************************************************************************************************/
public with sharing class GenerateBill{
    
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  getPrescriptionDetails
     * @Param:       Id prescriptionId
     * @Description: Fetches prescription details including patient,doctor,and medications.
     * @Return:      Map<String,Object>
     ******************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getPrescriptionDetails(Id prescriptionId){
        if(String.isBlank(prescriptionId)){
            throw new AuraHandledException('Prescription ID is required.');
        }
        // Fetch Prescription with parent details
        List<Prescription__c> prescriptions=[SELECT
                                                Id,Account__r.Name,Doctor__r.Name
                                            FROM
                                                Prescription__c
                                            WHERE
                                                Id=:prescriptionId LIMIT 1];
        if(prescriptions.isEmpty()){
            throw new AuraHandledException('Prescription record not found.');
        }
        Prescription__c pres=prescriptions[0];
        List<Medication__c> meds=[SELECT
                                    Id,Name,Quantity__c
                                FROM
                                    Medication__c
                                WHERE
                                    Prescription__c=:prescriptionId];
        // Return combined result map
        return new Map<String,Object>{
            'Patient__r'=>pres.Account__r,
            'Doctor__r'=>pres.Doctor__r,
            'medications'=>meds
        };
    }
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  createBill
     * @Param:       Map<String,Object> billData
     * @Param:       List<Map<String,Object>> lineItems
     * @Description: Creates a Bill and associated Bill Line Items.
     * @Return:      Id
     ******************************************************************************************************/
    @AuraEnabled
    public static Id createBill(Map<String,Object> billData,List<Map<String,Object>> lineItems){
        Savepoint sp=Database.setSavepoint();
        try{
            Id prescriptionId=(Id)billData.get('prescriptionId');
            if(String.isBlank(prescriptionId)){
                throw new AuraHandledException('Prescription ID is required.');
            }
            // Query Prescription to get context(Patient and Consultation)
            List<Prescription__c> prescriptions=[SELECT
                                                    Id,Account__c,Consultation__c
                                                FROM
                                                    Prescription__c
                                                WHERE
                                                    Id=:prescriptionId
                                                LIMIT 1];
            if(prescriptions.isEmpty()){
                throw new AuraHandledException('Prescription record not found.');
            }
            Prescription__c pres=prescriptions[0];
            // Initialize Bill with context from Prescription
            Bill__c bill=new Bill__c(
                Prescription__c=pres.Id,
                Patient__c=pres.Account__c,
                Consultation__c=pres.Consultation__c,
                Tax_Percentage__c=getDecimal(billData.get('taxPercentage'))
            );
            String dateStr=(String)billData.get('billDate');
            if(String.isNotBlank(dateStr)){
                bill.Billing_Date__c=Date.valueOf(dateStr);
            }
            insert bill;
            List<Bill_line__c> itemsToInsert=new List<Bill_line__c>();
            Set<Id> medicationIds = new Set<Id>();
            
            for(Map<String,Object> item:lineItems){
                String medId=(String)item.get('medicationId');
                if(String.isNotBlank(medId)){
                    medicationIds.add((Id)medId);
                }
                itemsToInsert.add(new Bill_line__c(
                    Bill__c=bill.Id,
                    Quantity__c=getDecimal(item.get('quantity')),
                    Unit_Price__c=getDecimal(item.get('price')),
                    Medication__c=String.isNotBlank(medId)?(Id)medId:null
                ));
            }
            
            // Ensure all referenced medications are linked to this prescription
            if(!medicationIds.isEmpty()){
                List<Medication__c> medsToUpdate = [SELECT Id FROM Medication__c WHERE Id IN :medicationIds AND Prescription__c = null];
                for(Medication__c med : medsToUpdate){
                    med.Prescription__c = prescriptionId;
                }
                if(!medsToUpdate.isEmpty()){
                    update medsToUpdate;
                }
            }
            
            if(!itemsToInsert.isEmpty()){
                insert itemsToInsert;
            }
            return bill.Id;
        }catch(Exception e){
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }
    /*****************************************************************************************************
     * @Author:      CRM Team Innovation
     * @MethodName:  getDecimal
     * @Param:       Object obj
     * @Description: Helper to safely convert object to Decimal.
     * @Return:      Decimal
     ******************************************************************************************************/
    private static Decimal getDecimal(Object obj){
        return obj!=null?Decimal.valueOf(String.valueOf(obj)):null;
    }
}