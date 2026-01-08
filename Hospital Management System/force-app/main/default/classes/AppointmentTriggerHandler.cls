/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @ClassName:   AppointmentTriggerHandler
 * @Description:  This Class belongs to server org.
 *                 It runs in context of trigger,and performs the following operations:
 *                 1. Assignment Notification Logic(Assignment): Doctor is notified when an appointment is assigned to them.
 *                 2. Confirmation Notification Logic(Confirmation): Patient is notified when an appointment is confirmed.
 *                 2. Assignment Logic(Assignment): Doctor is assigned to an appointment if they have available quota.
 *                 4. Daily Quota Logic(Assignment): doctors cannot have more than 10 appointments per day.
 *                                                      If not then Appoinment is queued
 **************************************************************************************************************/
public with sharing class AppointmentTriggerHandler{
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   onAfterInsert
 * @param1:     List<Appointment__c> newAppointments
 * @Description:  This method is responsible for calling the sendAssignmentNotifications method.
 **************************************************************************************************************/
    public static void onAfterInsert(List<Appointment__c> newAppointments){
        sendAssignmentNotifications(newAppointments,null);
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   onAfterUpdate
 * @param1:     List<Appointment__c> newAppointments
 * @param2:     Map<Id,Appointment__c> oldMap
 * @Description:  This method is responsible for calling the sendAssignmentNotifications method.
 **************************************************************************************************************/
    public static void onAfterUpdate(List<Appointment__c> newAppointments,Map<Id,Appointment__c> oldMap){
        promoteQueuedAppointments(newAppointments,oldMap);
        sendAssignmentNotifications(newAppointments,oldMap);
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   enforceDailyQuota
 * @param1:     List<Appointment__c> newAppointments
 * @param2:     Map<Id,Appointment__c> oldMap
 * @Description:  This method ensures doctors do not exceed a daily quota of 10 appointments. 
 *                It handles auto-assignment and moves appointments to a queue if the quota is met.
 **************************************************************************************************************/
    public static void enforceDailyQuota(List<Appointment__c> newAppointments,Map<Id,Appointment__c> oldMap){
        final Integer DAILY_QUOTA=10;
        final String STATUS_CONFIRMED='Confirmed';
        final String STATUS_COMPLETED='Completed';
        final String STATUS_WAITING='Queued';
        Set<Id> doctorIdsToCheck=new Set<Id>();
        Set<Date> relevantDates=new Set<Date>();
        List<Appointment__c> apptsToAssign=new List<Appointment__c>();
        List<Appointment__c> apptsToValidate=new List<Appointment__c>();
        for(Appointment__c appt:newAppointments){
            // Ensure Date is present
            if(appt.Appointment_Date__c!=null){
                Boolean isRelevant=false;
                if(oldMap==null){
                    isRelevant=true;
                }else{
                    Appointment__c oldAppt=oldMap.get(appt.Id);
                    if(appt.Doctor__c!=oldAppt.Doctor__c||
                        appt.Appointment_Date__c!=oldAppt.Appointment_Date__c||
                        appt.Appointment_Status__c!=oldAppt.Appointment_Status__c){
                        isRelevant=true;
                    }
                }
                // Only process if status is not explicitly Cancelled or Completed
                if(isRelevant&&appt.Appointment_Status__c!='Cancelled'&&appt.Appointment_Status__c!='Completed'){
                    if(appt.Doctor__c==null){
                        apptsToAssign.add(appt);
                    }else{
                        apptsToValidate.add(appt);
                        doctorIdsToCheck.add(appt.Doctor__c);
                    }
                    relevantDates.add(appt.Appointment_Date__c);
                }
            }
        }
        if(!apptsToAssign.isEmpty()||!apptsToValidate.isEmpty()){
            // If we need to auto-assign,we need to look at ALL doctors
            List<Doctor__c> allDoctors=new List<Doctor__c>();
            if(!apptsToAssign.isEmpty()){
                allDoctors=[SELECT
                                Id 
                            FROM
                                Doctor__c];
                for(Doctor__c doc:allDoctors){
                    doctorIdsToCheck.add(doc.Id);
                }
            }
            Map<String,Integer> doctorDateCounts=new Map<String,Integer>();
            Set<Id> scopeIds=(oldMap!=null)?oldMap.keySet():new Set<Id>();
            // Count existing Confirmed appointments(excluding current trigger records)
            for(AggregateResult ar:[SELECT 
                                            Doctor__c,Appointment_Date__c,COUNT(Id) cnt 
                                       FROM 
                                            Appointment__c 
                                       WHERE 
                                            Doctor__c IN :doctorIdsToCheck 
                                       AND 
                                            Appointment_Date__c IN :relevantDates 
                                       AND 
                                            Appointment_Status__c IN(:STATUS_CONFIRMED,:STATUS_COMPLETED)
                                       AND 
                                            Id NOT IN :scopeIds 
                                       GROUP BY 
                                            Doctor__c,Appointment_Date__c]){
                doctorDateCounts.put((Id)ar.get('Doctor__c')+'_' +(Date)ar.get('Appointment_Date__c'),(Integer)ar.get('cnt'));
            }
            // 1. Handle Auto-Assignment
            for(Appointment__c appt:apptsToAssign){
                if(allDoctors.isEmpty()){
                    appt.addError('No doctors available for assignment.');
                    continue;
                }
                Boolean assigned=false;
                // Try to find a doctor with available quota
                for(Doctor__c doc:allDoctors){
                    String key=doc.Id+'_'+appt.Appointment_Date__c;
                    Integer currentCount=doctorDateCounts.containsKey(key)?doctorDateCounts.get(key):0;
                    if(currentCount < DAILY_QUOTA){
                        appt.Doctor__c=doc.Id;
                        appt.Appointment_Status__c=STATUS_CONFIRMED;
                        doctorDateCounts.put(key,currentCount+1);
                        assigned=true;
                        break;
                    }
                }
                // If no doctor has space,assign to the first one and set to Waiting Queue
                if(!assigned){
                    Doctor__c fallbackDoc=allDoctors[0];
                    appt.Doctor__c=fallbackDoc.Id;
                    appt.Appointment_Status__c=STATUS_WAITING;
                    // Do not increment count as Waiting Queue doesn't consume quota
                }
            }
            // 2. Handle Manual Assignment / Validation
            for(Appointment__c appt:apptsToValidate){
                String key=appt.Doctor__c+'_'+appt.Appointment_Date__c;
                Integer currentCount=doctorDateCounts.containsKey(key)?doctorDateCounts.get(key):0;
                if(currentCount < DAILY_QUOTA){
                    // Automatically accept if quota allows
                    if(appt.Appointment_Status__c!=STATUS_CONFIRMED){
                        appt.Appointment_Status__c=STATUS_CONFIRMED;
                    }
                    // Increment count for the next iteration in this transaction
                    doctorDateCounts.put(key,currentCount+1);
                }else{
                    // Move to Waiting Queue if quota reached
                    appt.Appointment_Status__c=STATUS_WAITING;
                }
            }
        }
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   promoteQueuedAppointments
 * @param1:     List<Appointment__c> newAppointments
 * @param2:     Map<Id,Appointment__c> oldMap
 * @Description:  Promotes queued appointments when a slot opens up due to cancellation.
 **************************************************************************************************************/
    private static void promoteQueuedAppointments(List<Appointment__c> newAppointments,Map<Id,Appointment__c> oldMap){
        Set<Id> doctorIds=new Set<Id>();
        Set<Date> dates=new Set<Date>();
        Map<String,Integer> openSlotsMap=new Map<String,Integer>();

        for(Appointment__c appt:newAppointments){
            Appointment__c oldAppt=oldMap.get(appt.Id);
            // Check if appointment is cancelled
            if(appt.Appointment_Status__c=='Cancelled'&&oldAppt.Appointment_Status__c!='Cancelled'
               &&appt.Doctor__c!=null&&appt.Appointment_Date__c!=null){
                doctorIds.add(appt.Doctor__c);
                dates.add(appt.Appointment_Date__c);
                
                // Track open slots per Doctor-Date combination
                String key=appt.Doctor__c+'_'+appt.Appointment_Date__c;
                if(!openSlotsMap.containsKey(key)){
                    openSlotsMap.put(key,0);
                }
                openSlotsMap.put(key,openSlotsMap.get(key)+1);
            }
        }
        if(openSlotsMap.isEmpty()) return;
        // Find queued appointments for the affected doctors and dates
        List<Appointment__c> queuedAppts=[SELECT
                                            Id,Doctor__c,Appointment_Date__c
                                        FROM 
                                            Appointment__c 
                                        WHERE
                                            Appointment_Status__c='Queued' 
                                        AND
                                            Doctor__c IN :doctorIds 
                                        AND
                                            Appointment_Date__c IN :dates 
                                        ORDER BY
                                          CreatedDate ASC];
        
        Map<String,List<Appointment__c>> queuedMap=new Map<String,List<Appointment__c>>();
        for(Appointment__c qa:queuedAppts){
            String key=qa.Doctor__c+'_'+qa.Appointment_Date__c;
            if(!queuedMap.containsKey(key)){
                queuedMap.put(key,new List<Appointment__c>());
            }
            queuedMap.get(key).add(qa);
        }
        List<Appointment__c> toPromote=new List<Appointment__c>();
        for(String key:openSlotsMap.keySet()){
            if(queuedMap.containsKey(key)){
                List<Appointment__c> candidates=queuedMap.get(key);
                Integer slots=openSlotsMap.get(key);
                // Promote the next available queued appointments up to the number of open slots
                for(Integer i=0;i<slots&&i<candidates.size();i++){
                    Appointment__c prom=candidates[i];
                    prom.Appointment_Status__c='Confirmed';
                    toPromote.add(prom);
                }
            }
        }
        if(!toPromote.isEmpty()){
            update toPromote;
        }
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   sendAssignmentNotifications
 * @param1:     List<Appointment__c> newAppointments
 * @param2:     Map<Id,Appointment__c> oldMap
 * @Description:  This method sends email notifications to doctors upon assignment and to patients 
 *                upon appointment confirmation or significant updates(date/doctor changes).
 **************************************************************************************************************/
    private static void sendAssignmentNotifications(List<Appointment__c> newAppointments,Map<Id,Appointment__c> oldMap){
        Set<Id> patientIds=new Set<Id>();
        Set<Id> doctorIds=new Set<Id>();
        List<Appointment__c> appointmentsToProcess=new List<Appointment__c>();
        // 1. Identify appointments requiring notifications
        for(Appointment__c appt:newAppointments){
            Appointment__c oldAppt=(oldMap!=null)?oldMap.get(appt.Id):null;
            // Check if any relevant change occurred
            if(isNotificationTrigger(appt,oldAppt)){
                appointmentsToProcess.add(appt);
                if(appt.Patient__c!=null) patientIds.add(appt.Patient__c);
                if(appt.Doctor__c!=null) doctorIds.add(appt.Doctor__c);
            }
        }
        if(appointmentsToProcess.isEmpty()){
            return;
        }
        // 2. Query Recipient Data
        Map<Id,Account> patientMap=new Map<Id,Account>();
        if(!patientIds.isEmpty()){
            patientMap=new Map<Id,Account>([SELECT
                                                Id,Name,PersonEmail
                                            FROM
                                                Account
                                            WHERE
                                                Id
                                            IN
                                                :patientIds]);
        }
        Map<Id,Doctor__c> doctorMap=new Map<Id,Doctor__c>();
        if(!doctorIds.isEmpty()){
            doctorMap=new Map<Id,Doctor__c>([SELECT
                                                Id,Name,Email__c
                                            FROM
                                                Doctor__c
                                            WHERE
                                                Id
                                            IN
                                                :doctorIds]);
        }
        List<Messaging.SingleEmailMessage> emailsToSend=new List<Messaging.SingleEmailMessage>();
        // 3. Generate Emails
        for(Appointment__c appt:appointmentsToProcess){
            Appointment__c oldAppt=(oldMap!=null)?oldMap.get(appt.Id):null;
            Account patient=patientMap.get(appt.Patient__c);
            Doctor__c doctor=doctorMap.get(appt.Doctor__c);
            // Patient Notifications
            if(patient!=null&&String.isNotBlank(patient.PersonEmail)){
                Messaging.SingleEmailMessage patientEmail=generatePatientEmail(appt,oldAppt,patient,doctor);
                if(patientEmail!=null){
                    emailsToSend.add(patientEmail);
                }
            }
            // Doctor Notifications
            if(doctor!=null&&String.isNotBlank(doctor.Email__c)){
                Messaging.SingleEmailMessage doctorEmail=generateDoctorEmail(appt,oldAppt,doctor,patient);
                if(doctorEmail!=null){
                    emailsToSend.add(doctorEmail);
                }
            }
        }
        // 4. Send Emails
        if(!emailsToSend.isEmpty()){
            try{
                Messaging.sendEmail(emailsToSend);
            }catch(Exception e){
                System.debug('Error sending notification emails: '+e.getMessage());
            }
        }
    }
/********************************************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   isNotificationTrigger
 * @param1:     Appointment__c newAppt
 * @param2:     Appointment__c oldAppt
 * @Description:  Determines if notification emails need to be sent.
 ***************************************************************************************************************************/
    // Helper to check if processing is needed
    private static Boolean isNotificationTrigger(Appointment__c newAppt,Appointment__c oldAppt){
        // Insert
        if(oldAppt==null) return true;
        // Status Change
        if(newAppt.Appointment_Status__c!=oldAppt.Appointment_Status__c) return true;
        // Doctor Assignment Change
        if(newAppt.Doctor__c!=oldAppt.Doctor__c) return true;
        // Date Change
        if(newAppt.Appointment_Date__c!=oldAppt.Appointment_Date__c) return true;
        return false;
    }
/********************************************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   generatePatientEmail
 * @param1:     Appointment__c newAppt
 * @param2:     Appointment__c oldAppt
 * @param3:     Account patient
 * @param4:     Doctor__c doctor
 * @Description:  Generates email for patient based on appointment status change.
 *************************************************************************************************************************/
    // Helper for Patient Email Logic
    private static Messaging.SingleEmailMessage generatePatientEmail(Appointment__c newAppt,Appointment__c oldAppt,Account patient,Doctor__c doctor){
        String subject='';
        String bodyHeader='';
        String status=newAppt.Appointment_Status__c;
        String oldStatus=(oldAppt!=null)?oldAppt.Appointment_Status__c:'';
        Boolean isInsert=(oldAppt==null);
        Boolean isDetailChange=false;
        if(!isInsert&&(newAppt.Doctor__c!=oldAppt.Doctor__c||newAppt.Appointment_Date__c!=oldAppt.Appointment_Date__c)){
            isDetailChange=true;
        }
        // Determine Scenario
        if(status=='Cancelled'&&(isInsert||oldStatus!='Cancelled')){
            subject='Appointment Cancelled';
            bodyHeader='Your appointment has been cancelled.';
        }else if(status=='Confirmed'&&(isInsert||oldStatus!='Confirmed')){
            subject='Appointment Confirmed';
            bodyHeader='Your appointment has been confirmed.';
        }else if(status=='Accepted'&&(isInsert||oldStatus!='Accepted')){
            subject='Appointment Accepted';
            bodyHeader='Your appointment has been accepted.';
        }else if(isInsert){
            subject='Appointment Request Received';
            bodyHeader='Your appointment request has been received.';
        }else if(isDetailChange&&(status=='Confirmed'||status=='Accepted'||status=='Scheduled')){
            subject='Appointment Details Updated';
            bodyHeader='Your appointment details have been updated.';
        }else{
            return null; // No relevant status change for patient
        }
        return constructEmail(patient.PersonEmail,subject,bodyHeader,newAppt,patient.Name,(doctor!=null?doctor.Name:'Not Assigned'));
    }
/*******************************************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   generateDoctorEmail
 * @param1:     Appointment__c newAppt
 * @param2:     Appointment__c oldAppt
 * @param3:     Doctor__c doctor
 * @param4:     Account patient
 * @Description:  Generates email for doctor based on appointment status change.
 **********************************************************************************************************************************/
    // Helper for Doctor Email Logic
    private static Messaging.SingleEmailMessage generateDoctorEmail(Appointment__c newAppt,Appointment__c oldAppt,Doctor__c doctor,Account patient){
        String subject='';
        String bodyHeader='';
        Boolean isInsert=(oldAppt==null);
        Id oldDoctorId=(oldAppt!=null)?oldAppt.Doctor__c:null;
        // 1. Assignment (Insert with Doctor OR Update where Doctor changed)
        if((isInsert&&newAppt.Doctor__c!=null)
            ||(!isInsert&&newAppt.Doctor__c!=oldDoctorId&&newAppt.Doctor__c!=null)
            ||(!isInsert&&oldAppt.Appointment_Status__c=='Queued'&&newAppt.Appointment_Status__c=='Confirmed')){
            subject='New Appointment Assigned';
            bodyHeader='You have been assigned a new appointment.';
        } 
        // 2. Cancellation (Status changed to Cancelled)
        else if(!isInsert&&newAppt.Appointment_Status__c=='Cancelled'&&oldAppt.Appointment_Status__c!='Cancelled'){
            subject='Appointment Cancelled';
            bodyHeader='An appointment assigned to you has been cancelled.';
        }else{
            return null;
        }
        return constructEmail(doctor.Email__c,subject,bodyHeader,newAppt,doctor.Name,(patient!=null?patient.Name:'N/A'));
    }
/***************************************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   constructEmail
 * @param1:     String toAddress
 * @param2:     String subject
 * @param3:     String headerMsg
 * @param4:     Appointment__c appt
 * @param5:     String recipientName
 * @param6:     String otherPartyName
 * @Description:  Generic Email Constructor
 ***********************************************************************************************************************/
    // Generic Email Constructor
    private static Messaging.SingleEmailMessage constructEmail(String toAddress,String subject,String headerMsg,Appointment__c appt,String recipientName,String otherPartyName){
        Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{toAddress});
        mail.setSubject(subject);
        String body='<html><body style="font-family: Arial,sans-serif;">';
        body+='<h2 style="color: #2c3e50;">'+subject+'</h2>';
        body+='<p>Dear '+recipientName+',</p>';
        body+='<p>'+headerMsg+' Please find the details below:</p>';
        body+='<table style="border-collapse: collapse; width: 100%; max-width: 600px;">';
        body+='<tr style="background-color: #f2f2f2;"><td style="padding: 10px; border: 1px solid #ddd;"><strong>Related Party</strong></td><td style="padding: 10px; border: 1px solid #ddd;">'+otherPartyName+'</td></tr>';
        body+='<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Date</strong></td><td style="padding: 10px; border: 1px solid #ddd;">'+(appt.Appointment_Date__c!=null?String.valueOf(appt.Appointment_Date__c):'')+'</td></tr>';
        body+='<tr style="background-color: #f2f2f2;"><td style="padding: 10px; border: 1px solid #ddd;"><strong>Status</strong></td><td style="padding: 10px; border: 1px solid #ddd;">'+(appt.Appointment_Status__c!=null?appt.Appointment_Status__c:'')+'</td></tr>';
        body+='<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Reason for Visit</strong></td><td style="padding: 10px; border: 1px solid #ddd;">'+(appt.Reason_for_Visit__c!=null?appt.Reason_for_Visit__c:'N/A')+'</td></tr>';
        body+='</table>';
        body+='<br/><p>Regards,<br/><strong>Hospital Management System</strong></p>';
        body+='</body></html>';
        mail.setHtmlBody(body);
        return mail;
    }
}