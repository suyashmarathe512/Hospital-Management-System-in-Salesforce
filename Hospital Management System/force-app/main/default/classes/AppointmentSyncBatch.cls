/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   AppointmentSyncBatch
 * @Description:  This class belongs to client org, where the data is being synced from client org to server org.
 *                This class is responsible for calling the server org.
 **************************************************************************************************************/
public with sharing class AppointmentSyncBatch implements Database.Batchable<SObject>,Database.AllowsCallouts,Schedulable{
/*****************************************************************************************************
 * @Author:      CRM Team Innovation
 * @MethodName:   execute
 * @param1 :     SchedulableContext sc
 * @Description: This method is responsible calling the batch class for further logic.
 **************************************************************************************************************/
    public void execute(SchedulableContext sc){
        // Execute batch with a manageable chunk size for callouts
       
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   start
 * @param1 :      Database.BatchableContext bc
 * @Description:  This method is responsible fetching the Appoinment__c records from 
 *                Client Org which needs to be updated in Server Org.
 **************************************************************************************************************/
    public Database.QueryLocator start(Database.BatchableContext bc){
        // Sync if External_Record_Id__c is null(New Record) OR modified in last 20 mins(Update)
        DateTime timeThreshold=DateTime.now().addMinutes(-20);
        return Database.getQueryLocator([
            SELECT 
                Id,Appointment_Date__c,Appointment_Status__c,Reason_for_Visit__c,
                   External_Record_Id__c,Patient__r.External_Record_Id__c
            FROM
                Appointment__c
            WHERE
                External_Record_Id__c=NULL 
            OR
                LastModifiedDate >= :timeThreshold
        ]);
    }
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   execute
 * @param1 :      Database.BatchableContext bc
 * @param2 :      List<Appointment__c> scope
 * @Description:  This method is responsible creating the payload that need to be sent to server org.
 *                 In response, we get the External_Record_Id__c(record Id of server) 
 *                  from server org and update it in client org.
 **************************************************************************************************************/
    public void execute(Database.BatchableContext bc,List<Appointment__c> scope){
        List<Map<String,Object>> payload=new List<Map<String,Object>>();
        for(Appointment__c appt:scope){
            Map<String,Object> apptMap=new Map<String,Object>();
            apptMap.put('clientAppointmentId',appt.Id);
            // If we have an External_Record_Id__c,it means it exists on Server. Send it to perform update.
            if(String.isNotBlank(appt.External_Record_Id__c)){
                apptMap.put('serverAppointmentId',appt.External_Record_Id__c);
            }
            apptMap.put('appointmentDate',appt.Appointment_Date__c);
            apptMap.put('status',appt.Appointment_Status__c);
            apptMap.put('reason',appt.Reason_for_Visit__c);
            // Map Patient via External ID
            if(appt.Patient__r != null){
                apptMap.put('patientExternalId',appt.Patient__r.External_Record_Id__c);
            }
            payload.add(apptMap);
        }
        if(payload.isEmpty()) return;
        Map<String,Object> requestBody=new Map<String,Object>();
        requestBody.put('appointments',payload);
        HttpRequest req=new HttpRequest();
        req.setEndpoint('callout:Hospital_Server/services/apexrest/AppointmentService/');
        req.setMethod('POST');
        req.setBody(JSON.serialize(requestBody));
        req.setHeader('Content-Type','application/json');
        try{
            Http http=new Http();
            HttpResponse res=http.send(req);
            if(res.getStatusCode()==200){
                Map<String,Object> responseMap=(Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                List<Appointment__c> toUpdate=new List<Appointment__c>();
                for(String clientId:responseMap.keySet()){
                    Object val=responseMap.get(clientId);
                    if(val instanceof Map<String,Object>){
                        Map<String,Object> details=(Map<String,Object>) val;
                        toUpdate.add(new Appointment__c(
                            Id=clientId,
                            External_Record_Id__c=(String) details.get('serverAppointmentId'),
                            Appointment_Status__c=(String) details.get('status')
                        ));
                    }
                }
                if(!toUpdate.isEmpty()){
                    update toUpdate;
                }
            }else{
                System.debug('Sync failed with status: '+res.getStatusCode()+' '+res.getBody());
            }
        }catch(Exception e){
            System.debug('Sync Exception: '+e.getMessage());
        }
    }
/********************************************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   finish
 * @param1 :      Database.BatchableContext bc
 * @Description:  This method is responsible for logging the success or failure of the batch job.
 ***************************************************************************************************************************/
    public void finish(Database.BatchableContext bc){
    }
}