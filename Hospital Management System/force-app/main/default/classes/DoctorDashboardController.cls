/**********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   DoctorDashboardController
 * @Description: Controller for the doctor dashboard,providing a list of today's appointments.
 ****************************************************************************************************/
 public with sharing class DoctorDashboardController{
/**********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @ClassName:   AppointmentDetail
 * @Description: Wrapper class for the Appoinment details.
 *************************************************************************************************/
    public class AppointmentDetail{
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String PatientName;
        @AuraEnabled public String ReasonForVisit;
        @AuraEnabled public String AppointmentStatus;
        @AuraEnabled public String FormattedTime;
    }
/**********************************************************************************************************
 * @Author:    CRM Team Innovation
 * @MethodName:   getTodayAppointments
 * @Description: This method queries the appointments for today and returns a list of AppointmentDetail objects.
 *               It also checks if the doctor is associated with the provided email address.
 *****************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<AppointmentDetail> getTodayAppointments(String email){
        try{
            if(String.isBlank(email)){
                throw new AuraHandledException('Email address is required.');
            }
            List<Doctor__c> doctors=[
                SELECT
                    Id 
                FROM
                    Doctor__c 
                WHERE
                    Email__c=:email 
                LIMIT 1];
            if(doctors.isEmpty()){
                AuraHandledException e=new AuraHandledException('Access Denied: No Doctor record associated with this email.');
                e.setMessage('Access Denied: No Doctor record associated with this email.');
                throw e;
            }
            Id doctorId=doctors[0].Id;
            // Query Appointments for Today(Removed Appointment_Time__c)
            List<Appointment__c> appointments=[
                SELECT
                    Id,Name,Patient__r.Name,Reason_for_Visit__c,Appointment_Status__c
                FROM
                    Appointment__c
                WHERE
                    Doctor__c=:doctorId
                AND
                    Appointment_Date__c=:System.today()
                AND
                    Appointment_Status__c != 'Cancelled'
                ORDER BY
                    Name ASC
                LIMIT 10];
            List<AppointmentDetail> results=new List<AppointmentDetail>();
            // Start time 9:00 AM
            Time slotTime=Time.newInstance(9,0,0,0);
            for(Appointment__c appt:appointments){
                AppointmentDetail detail=new AppointmentDetail();
                detail.Id=appt.Id;
                detail.Name=appt.Name;
                detail.PatientName=(appt.Patient__r != null)?appt.Patient__r.Name:'Unknown';
                detail.ReasonForVisit=appt.Reason_for_Visit__c;
                detail.AppointmentStatus=appt.Appointment_Status__c;
                // Create datetime instance to showcase time
                // 10 appointments from 9:00 AM to 7:00 PM -> 1 hour intervals
                DateTime dt=DateTime.newInstance(System.today(),slotTime);
                detail.FormattedTime=dt.format('h:mm a');
                results.add(detail);
                // Increment by 1 hour
                slotTime=slotTime.addHours(1);
            }
            return results;
        }catch(Exception e){
            throw new AuraHandledException('Error fetching appointments: '+e.getMessage());
        }
    }
}