/**********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   PortalAppointmentController
 * @Description: Controller of the portalAppoinment showing the Appoinment details.
 *               It also allows the patient to insert an appointment.
 ****************************************************************************************************/
public without sharing class PortalAppointmentController{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getAppointments
 * @param1:     String accountId
 * @Description: This method is querying the appoinments from org which belogs to particular account.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Appointment__c> getAppointments(String accountId){
        List<Appointment__c> appointments=[SELECT 
                                                    Id,Name,Appointment_Type__c,Appointment_Date__c,Appointment_Status__c,
                                                    Reason_for_Visit__c,Doctor__r.Name
                                                FROM 
                                                    Appointment__c 
                                                WHERE 
                                                    Patient__c=:accountId 
                                                ORDER BY 
                                                    Appointment_Date__c DESC];
        for(Appointment__c appt:appointments){
            if(appt.Appointment_Date__c < Date.today()&&appt.Appointment_Status__c!='Cancelled'){
                appt.Appointment_Status__c='Completed';
            }
        }
        return appointments;
    }
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getConsultations
 * @Description: Fetches consultation history for the patient.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Consultation__c> getConsultations(String accountId){
        return [SELECT 
                    Id,Name,Date_of_Visit__c 
                FROM 
                    Consultation__c 
                WHERE 
                    Patient__c=:accountId 
                ORDER BY 
                    Date_of_Visit__c DESC];
    }

/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   bookAppointment
 * @param1:     String accountId
 * @param2:     Date appointmentDate
 * @param3:     String reason
 * @param4:     String appointmentType
 * @Description: This method responsible to insert the appointment record in org.
 *****************************************************************************************************/
    @AuraEnabled
    public static void bookAppointment(String accountId,Date appointmentDate,String reason,String appointmentType){
        Appointment__c newAppt=new Appointment__c(
            Patient__c=accountId,
            Appointment_Type__c=appointmentType,
            Appointment_Date__c=appointmentDate,
            Reason_for_Visit__c=reason,
            Appointment_Status__c='Scheduled'
        );
        insert newAppt;
    }
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   cancelAppointment
 * @param1:     String appointmentId
 * @param2:     String accountId
 * @param3:     String reason
 * @Description: Validates patient,updates status to Cancelled,and notifies Server Org.
 *****************************************************************************************************/
    @AuraEnabled
    public static void cancelAppointment(String appointmentId,String accountId,String reason){
        List<Appointment__c> appts=[SELECT
                                        Id,External_Record_Id__c
                                    FROM
                                        Appointment__c
                                    WHERE
                                        Id=:appointmentId
                                    AND
                                        Patient__c=:accountId
                                    LIMIT 1];
        if(appts.isEmpty()){
            throw new AuraHandledException('Appointment not found or access denied.');
        }
        Appointment__c appt=appts[0];
        appt.Appointment_Status__c='Cancelled';
        update appt;
        if(String.isNotBlank(appt.External_Record_Id__c)){
            notifyServerCancellation(appt.External_Record_Id__c,reason);
        }
    }
    @future(callout=true)
    private static void notifyServerCancellation(String externalId,String reason){
        Http http=new Http();
        HttpRequest req=new HttpRequest();
        // Use Named Credential for the Server Org connection
        req.setEndpoint('callout:Hospital_Server/services/apexrest/AppointmentService');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        // Prepare JSON payload matching Server Org's AppointmentService structure
        Map<String,Object> apptPayload=new Map<String,Object>();
        apptPayload.put('serverAppointmentId',externalId);
        apptPayload.put('status','Cancelled');
        apptPayload.put('reason',reason);
        Map<String,Object> requestBody=new Map<String,Object>();
        requestBody.put('appointments',new List<Object>{ apptPayload });
        req.setBody(JSON.serialize(requestBody));
        HttpResponse res=http.send(req);
    }
}