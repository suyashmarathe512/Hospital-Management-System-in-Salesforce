/**********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   PortalAppointmentController
 * @Description: Controller of the portalAppoinment showing the Appoinment details.
 *               It also allows the patient to insert an appointment.
 ****************************************************************************************************/
public with sharing class PortalAppointmentController{
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getAppointments
 * @param1 :      String accountId
 * @Description: This method is querying the appoinments from org which belogs to particular account.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Appointment__c> getAppointments(String accountId){
        return [SELECT 
                    Id,Name,Appointment_Type__c,Appointment_Date__c,Appointment_Status__c,Reason_for_Visit__c
                FROM 
                    Appointment__c 
                WHERE 
                    Patient__c=:accountId 
                ORDER BY 
                    Appointment_Date__c DESC];
    }
/*********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   bookAppointment
 * @param1 :      String accountId
 * @param2 :      Date appointmentDate
 * @param3 :      String reason
 * @param4 :      String appointmentType
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
}