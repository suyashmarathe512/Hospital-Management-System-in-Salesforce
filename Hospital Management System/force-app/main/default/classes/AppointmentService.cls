/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   AppointmentService
 * @Description:  This class belongs to Server Org,where the data is being synced from Client Org to Server Org.
 *                This class is responsible for creating/updating Appointment records in Server Org.
 **************************************************************************************************************/
@RestResource(urlMapping='/AppointmentService/*')
global with sharing class AppointmentService{
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   syncAppointments
 * @Description:  This method is responsible for creating/updating Appointment records in Server Org.
 *                This method is called from client org.In return,we get the External_Record_Id__c(record Id of server) 
 *                  from server org and update it in client org.
 **************************************************************************************************************/
    @HttpPost
    global static void syncAppointments(){
        RestRequest req=RestContext.request;
        RestResponse res=RestContext.response;
        Map<String,Object> responseMap=new Map<String,Object>();
        try{
            Map<String,Object> root=(Map<String,Object>)JSON.deserializeUntyped(req.requestBody.toString());
            List<Object> apptList=(List<Object>)root.get('appointments');
            List<Appointment__c> upsertList=new List<Appointment__c>();
            List<String> clientIds=new List<String>();
            // Collect External IDs for lookup resolution
            Set<String> patientExtIds=new Set<String>();
            Set<String> clientApptIds=new Set<String>();
            Set<String> serverApptIds=new Set<String>();
            for(Object obj:apptList){
                Map<String,Object> apptMap=(Map<String,Object>)obj;
                String pId=(String)apptMap.get('patientExternalId');
                if(String.isNotBlank(pId)){
                    patientExtIds.add(pId);
                }
                String cId=(String)apptMap.get('clientAppointmentId');
                String sId=(String)apptMap.get('serverAppointmentId');
                if(String.isNotBlank(cId)){
                    clientApptIds.add(cId);
                }
                if(String.isNotBlank(sId)){
                    serverApptIds.add(sId);
                }
            }
            // Optimize: Single query for Patients
            Map<Id,Account> validPatients=new Map<Id,Account>([SELECT
                                                                    Id
                                                                FROM
                                                                    Account
                                                                WHERE
                                                                    Id
                                                                IN
                                                                    :patientExtIds
                                                                WITH
                                                                    SECURITY_ENFORCED]);
            // Optimize: Single query for Appointments (Server ID or External ID)
            Map<String,Appointment__c> existingApptMap=new Map<String,Appointment__c>();
            if(!clientApptIds.isEmpty()||!serverApptIds.isEmpty()){
                for(Appointment__c a:[SELECT
                                            Id,External_Record_Id__c,Appointment_Status__c
                                        FROM
                                            Appointment__c 
                                        WHERE
                                            Id
                                        IN
                                            :serverApptIds
                                        OR
                                            External_Record_Id__c
                                        IN
                                            :clientApptIds 
                                        WITH
                                            SECURITY_ENFORCED]){
                    existingApptMap.put(a.Id,a);
                    if(String.isNotBlank(a.External_Record_Id__c)){
                        existingApptMap.put(a.External_Record_Id__c,a);
                    }
                }
            }
            // Build Appointment records
            for(Object obj:apptList){
                Map<String,Object> w=(Map<String,Object>)obj;
                Appointment__c appt=new Appointment__c();
                String clientId=(String)w.get('clientAppointmentId');
                if(String.isNotBlank(clientId)){
                    appt.External_Record_Id__c=clientId;
                }
                // Use Server Id if provided(Upsert logic)
                String serverId=(String)w.get('serverAppointmentId');
                Appointment__c existingRecord=null;
                if(String.isNotBlank(serverId)&&existingApptMap.containsKey(serverId)){
                    // Set Id directly to update existing record
                    existingRecord=existingApptMap.get(serverId);
                    appt.Id=serverId;
                }else if(String.isNotBlank(clientId)&&existingApptMap.containsKey(clientId)){
                    // Match by External ID if Server ID is missing
                    existingRecord=existingApptMap.get(clientId);
                    appt.Id=existingRecord.Id;
                }
                if(existingRecord!=null&&(existingRecord.Appointment_Status__c=='Confirmed'||existingRecord.Appointment_Status__c=='Completed')){
                    Map<String,String> details=new Map<String,String>();
                    details.put('serverAppointmentId',existingRecord.Id);
                    details.put('status',existingRecord.Appointment_Status__c);
                    responseMap.put(clientId,details);
                    continue;
                }
                // Map fields
                Object dateObj=w.get('appointmentDate');
                if(dateObj != null){
                    // Optimize: Direct Date conversion
                    appt.Appointment_Date__c=Date.valueOf((String)dateObj);
                }
                appt.Appointment_Status__c=(String)w.get('status');
                appt.Reason_for_Visit__c=(String)w.get('reason');
                // Resolve lookups using maps
                String pExtId=(String)w.get('patientExternalId');
                if(String.isNotBlank(pExtId)&&validPatients.containsKey(pExtId)){
                    appt.Patient__c=pExtId;
                }
                upsertList.add(appt);
                clientIds.add((String)w.get('clientAppointmentId'));
            }
            if(!upsertList.isEmpty()){
                // Bulk upsert
                upsert upsertList;
                
                // Re-query to get the latest status determined by Server Triggers (e.g. Queued)
                Map<Id, Appointment__c> latestInfo=new Map<Id, Appointment__c>([SELECT
                                                                                    Id, Appointment_Status__c
                                                                                FROM
                                                                                    Appointment__c
                                                                                WHERE
                                                                                    Id
                                                                                IN
                                                                                    :upsertList]);
                for(Integer i=0; i<upsertList.size(); i++){
                    // Map ClientId to newly saved SF Id and Status for response
                    Map<String,String> details=new Map<String,String>();
                    details.put('serverAppointmentId',upsertList[i].Id);
                    // Use the re-queried status
                    Appointment__c fresh=latestInfo.get(upsertList[i].Id);
                    details.put('status', fresh != null ? fresh.Appointment_Status__c : upsertList[i].Appointment_Status__c);
                    responseMap.put(clientIds[i],details);
                }
            }
        }catch(Exception e){
            res.statusCode=500;
            responseMap.put('error',e.getMessage());
        }
        res.addHeader('Content-Type','application/json');
        res.responseBody=Blob.valueOf(JSON.serialize(responseMap));
    }
}
