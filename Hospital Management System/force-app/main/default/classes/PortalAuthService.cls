/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName: PortalAuthService
 * @Description: This class provides authentication and account creation services for the patient portal.
 *****************************************************************************************************/
public with sharing class PortalAuthService{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName: AuthResult
 * @Description: This class is used to store the result of the authentication process.
 *****************************************************************************************************/
    public class AuthResult{
        @AuraEnabled public String accountId;
        @AuraEnabled public String message;
}
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName: authenticate
 * @param1 :    String email
 * @param2 :    String password
 * @Description: Validates user credentials against Person Account records.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=false)
    public static AuthResult authenticate(String email,String password){
        // Run SOQL in user mode to respect guest user access
        // and avoid elevated access when invoked from guest context.
        if(String.isBlank(email)||String.isBlank(password)){
            throw new AuraHandledException('Invalid email or password');
    }
        // Query Person Account by exact match
        // Run SOQL using Database.query with USER_MODE to respect guest access
        List<Account> matches=(List<Account>)Database.queryWithBinds(
            'SELECT Id FROM Account '+
            'WHERE RecordType.DeveloperName=:paDevName '+
            'AND PersonEmail=:email '+
            'AND Login_Password__c=:password '+
            'LIMIT 1',
            new Map<String,Object>{'paDevName'=>'PersonAccount','email'=>email,'password'=>password},
            AccessLevel.SYSTEM_MODE
        );
        if(matches.isEmpty()){
            throw new AuraHandledException('Invalid email or password');
    }
        AuthResult res=new AuthResult();
        res.accountId=matches[0].Id;
        res.message='OK';
        return res;
}
    public class CreateRequest{
        @AuraEnabled public String firstName{get;set;}
        @AuraEnabled public String lastName{get;set;}
        @AuraEnabled public String email{get;set;}
        @AuraEnabled public String password{get;set;}
        @AuraEnabled public String salutation{get;set;}
        @AuraEnabled public String birthdate{get;set;}
        @AuraEnabled public String mobile{get;set;}
        @AuraEnabled public String phone{get;set;}
        @AuraEnabled public String otherPhone{get;set;}
        @AuraEnabled public String mailingStreet{get;set;}
        @AuraEnabled public String mailingCity{get;set;}
        @AuraEnabled public String mailingState{get;set;}
        @AuraEnabled public String mailingPostalCode{get;set;}
        @AuraEnabled public String mailingCountry{get;set;}
        @AuraEnabled public String otherStreet{get;set;}
        @AuraEnabled public String otherCity{get;set;}
        @AuraEnabled public String otherState{get;set;}
        @AuraEnabled public String otherPostalCode{get;set;}
        @AuraEnabled public String otherCountry{get;set;}
}

/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName: createPersonAccount
 * @param1 :    CreateRequest req
 * @Description: Creates a new Person Account record based on the provided request data.
 *****************************************************************************************************/
    @AuraEnabled
    public static String createPersonAccount(CreateRequest req){
        // DML below must be in USER_MODE to honor guest profile permissions
        // Minimal validation
        System.debug('createPersonAccount req: '+ JSON.serialize(req));
        if(req==null||String.isBlank(req.email)||String.isBlank(req.password)){
            System.debug('Validation failed. Req: '+ req);
            throw new AuraHandledException('Validation failed: Email and Password are required.');
    }
        String lastName=req.lastName;
        // Create a Person Account record via Person Account record type
        // Retrieve Person Account record type in USER_MODE
        List<RecordType> paRts=(List<RecordType>)Database.queryWithBinds(
            'SELECT Id FROM RecordType WHERE SObjectType=:sobj AND DeveloperName=:paDevName LIMIT 1',
            new Map<String,Object>{'sobj'=>'Account','paDevName'=>'PersonAccount'},
            AccessLevel.SYSTEM_MODE
        );
        if(paRts.isEmpty()){
            throw new AuraHandledException('Person Account record type not available');
    }
        RecordType paRt=paRts[0];
        Account pa=new Account();
        pa.RecordTypeId=paRt.Id;
        pa.LastName=lastName;
        if(!String.isBlank(req.firstName)){
            pa.FirstName=req.firstName;
    }
        pa.Salutation=req.salutation;
        pa.PersonEmail=req.email;
        pa.Login_Password__c=req.password;
        
        if(String.isNotBlank(req.birthdate)){
            pa.PersonBirthdate=Date.valueOf(req.birthdate);
    }
        pa.PersonMobilePhone=req.mobile;
        pa.Phone=req.phone;
        pa.PersonOtherPhone=req.otherPhone;
        
        // Map Mailing Address to Billing Address(standard for Person Accounts)
        pa.BillingStreet=req.mailingStreet;
        pa.BillingCity=req.mailingCity;
        pa.BillingState=req.mailingState;
        pa.BillingPostalCode=req.mailingPostalCode;
        pa.BillingCountry=req.mailingCountry;
        // Map Other Address to Shipping Address
        pa.ShippingStreet=req.otherStreet;
        pa.ShippingCity=req.otherCity;
        pa.ShippingState=req.otherState;
        pa.ShippingPostalCode=req.otherPostalCode;
        pa.ShippingCountry=req.otherCountry;
        try{
            Database.insert(pa,AccessLevel.SYSTEM_MODE);
    }catch(DmlException e){
            for(Integer i=0;i < e.getNumDml();i++){
                if(e.getDmlType(i)==StatusCode.DUPLICATES_DETECTED||e.getDmlType(i)==StatusCode.DUPLICATE_VALUE){
                    throw new AuraHandledException('An account with this email address already exists.');
            }
        }
            throw new AuraHandledException('Error: '+ e.getMessage());
    }catch(Exception e){
            System.debug('Insert failed: '+ e.getMessage());
            throw new AuraHandledException('Error: '+ e.getMessage());
    }
        return 'Account created successfully. Please log in with your email and password.';
}
}
