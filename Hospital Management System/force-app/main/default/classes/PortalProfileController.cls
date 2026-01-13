/*********************************************************************************************************
 * @Author:      CRM Team Innovation
 * @ClassName:   PortalProfileController
 * @Description: Controller for the portal profile view,providing a summary of account data,
 *                  appointments,consultations,and prescriptions.
 *****************************************************************************************************/
public with sharing class PortalProfileController{
    public class AccountSummary{
        @AuraEnabled public Account account;
    }
/*********************************************************************************************************
 * @Author:      CRM Team Innovation
 * @MethodName:  getProfileData
 * @param1 :     Id accountId
 * @Description: Retrieves a comprehensive summary of profile data for a specific account,
 *                  including recent appointments,consultations,and prescriptions.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static AccountSummary getProfileData(Id accountId){
        if(accountId==null){
            throw new AuraHandledException('Account Id is required.');
        }
        AccountSummary result=new AccountSummary();
        // Account details
        result.account=[SELECT
                            Id,Name,PersonEmail,Phone,Website,Rating,Industry,
                            BillingStreet,BillingCity,BillingState,BillingPostalCode,BillingCountry,
                            ShippingStreet,ShippingCity,ShippingState,ShippingPostalCode,ShippingCountry
                        FROM
                            Account
                        WHERE
                            Id=:accountId
                        WITH
                            SECURITY_ENFORCED
                        LIMIT 1];
        return result;
    }
/*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   updateProfile
     * @Param:        Account accountData
     * @Description:  Updates the patient's Account record with new information.
     ******************************************************************************************************/
    @AuraEnabled
    public static void updateProfile(Account accountData){
        try{
            // Create a new Account instance to update only editable fields.
            Account accToUpdate=new Account(Id=accountData.Id);
            
            accToUpdate.Salutation=accountData.Salutation;
            accToUpdate.FirstName=accountData.FirstName;
            accToUpdate.LastName=accountData.LastName;
            accToUpdate.PersonBirthdate=accountData.PersonBirthdate;
            accToUpdate.PersonMobilePhone=accountData.PersonMobilePhone;
            accToUpdate.PersonEmail=accountData.PersonEmail;
            accToUpdate.Phone=accountData.Phone;
            accToUpdate.PersonOtherPhone=accountData.PersonOtherPhone;
            
            accToUpdate.PersonMailingStreet=accountData.PersonMailingStreet;
            accToUpdate.PersonMailingCity=accountData.PersonMailingCity;
            accToUpdate.PersonMailingState=accountData.PersonMailingState;
            accToUpdate.PersonMailingPostalCode=accountData.PersonMailingPostalCode;
            accToUpdate.PersonMailingCountry=accountData.PersonMailingCountry;
            
            accToUpdate.PersonOtherStreet=accountData.PersonOtherStreet;
            accToUpdate.PersonOtherCity=accountData.PersonOtherCity;
            accToUpdate.PersonOtherState=accountData.PersonOtherState;
            accToUpdate.PersonOtherPostalCode=accountData.PersonOtherPostalCode;
            accToUpdate.PersonOtherCountry=accountData.PersonOtherCountry;
            
            update accToUpdate;
        }catch(Exception e){
            throw new AuraHandledException('Error updating profile: ' + e.getMessage());
        }
    }
}