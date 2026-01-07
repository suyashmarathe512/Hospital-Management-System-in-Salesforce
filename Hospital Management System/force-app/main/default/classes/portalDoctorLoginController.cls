/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   portalDoctorLoginController
 * @Description: Controller for the portal doctor login,providing a method to verify the doctor's email address.
 *****************************************************************************************************/
public with sharing class portalDoctorLoginController{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   verifyDoctorEmail
 * @param1 :      String email
 * @Description: This method verifies the doctor's email address.
 *****************************************************************************************************/
    @AuraEnabled
    public static Doctor__c verifyDoctorEmail(String email){
        if(String.isBlank(email)){
            throw new AuraHandledException('Email address is required.');
        }
        List<Doctor__c> doctors=[
            SELECT
                Id,Name,Email__c 
            FROM
                Doctor__c
            WHERE
                Email__c=:email
            WITH
                SECURITY_ENFORCED 
            LIMIT 1
        ];
        if(doctors.isEmpty()){
            throw new AuraHandledException('No doctor account found with that email address.');
        }
        return doctors[0];
    }
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   reportIssueToAdmin
 * @param1 :      String doctorEmail
 * @param2 :      String issueDescription
 * @Description: This method reports an issue to the admin.
 *****************************************************************************************************/
    @AuraEnabled
    public static void reportIssueToAdmin(String doctorEmail,String issueDescription){
        try{
            Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{'suyashmarathe1092003@gmail.com'}); 
            mail.setSubject('Doctor Portal Issue Report');
            mail.setPlainTextBody('Issue reported by: ' +(String.isBlank(doctorEmail)?'Unknown':doctorEmail)+'\n\nDescription:\n' + issueDescription);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        }catch(Exception e){
            throw new AuraHandledException('Failed to send report: '+e.getMessage());
        }
    }
}