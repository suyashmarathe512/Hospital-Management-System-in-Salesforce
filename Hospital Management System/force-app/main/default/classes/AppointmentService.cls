/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   AppointmentService
 * @Description:  This class belongs to Server Org, where the data is being synced from Client Org to Server Org.
 *                This class is responsible for creating/updating Appointment records in Server Org.
 **************************************************************************************************************/
@RestResource(urlMapping='/AppointmentService/*')
global with sharing class AppointmentService{
/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @MethodName:   syncAppointments
 * @Description:  This method is responsible for creating/updating Appointment records in Server Org.
 *                This method is called from client org.In return, we get the External_Record_Id__c(record Id of server) 
 *                  from server org and update it in client org.
 **************************************************************************************************************/
    @HttpPost
    global static Map<String,Object> syncAppointments(){
        RestRequest req=RestContext.request;
        Map<String,Object> responseMap=new Map<String,Object>();
        try{
            Map<String,Object> root=(Map<String,Object>)JSON.deserializeUntyped(req.requestBody.toString());
            List<Object> apptList=(List<Object>)root.get('appointments');
            List<Appointment__c> upsertList=new List<Appointment__c>();
            List<String> clientIds=new List<String>();
            // Collect External IDs for lookup resolution
            Set<String> patientExtIds=new Set<String>();
            Set<String> incomingClientApptIds=new Set<String>();
            Set<String> incomingServerIds=new Set<String>();
            for(Object obj:apptList){
                Map<String,Object> apptMap=(Map<String,Object>)obj;
                String pId=(String)apptMap.get('patientExternalId');
                if(String.isNotBlank(pId)){
                    patientExtIds.add(pId);
                }
                String cId=(String)apptMap.get('clientAppointmentId');
                String sId=(String)apptMap.get('serverAppointmentId');
                if(String.isNotBlank(cId)){
                    incomingClientApptIds.add(cId);
                }
                if(String.isNotBlank(sId)){
                    incomingServerIds.add(sId);
                }
            }
            Set<String> validPatientIds=new Set<String>();
            if(!patientExtIds.isEmpty()){
                for(Account acc:[SELECT
                                        Id 
                                    FROM
                                        Account 
                                    WHERE
                                        Id IN :patientExtIds
                                    WITH SECURITY_ENFORCED]){
                    validPatientIds.add(acc.Id);
                }
            }
            Map<String,Appointment__c> validServerAppts=new Map<String,Appointment__c>();
            if(!incomingServerIds.isEmpty()){
                for(Appointment__c a:[SELECT
                                            Id,Appointment_Status__c
                                        FROM
                                            Appointment__c
                                        WHERE
                                            Id
                                        IN :incomingServerIds WITH SECURITY_ENFORCED]){
                    validServerAppts.put(a.Id,a);
                }
            }
            // Check for existing appointments by External ID to prevent duplicates
            Map<String,Appointment__c> existingApptMap=new Map<String,Appointment__c>();
            if(!incomingClientApptIds.isEmpty()){
                for(Appointment__c exist:[SELECT 
                                            Id,External_Record_Id__c,Appointment_Status__c
                                        FROM
                                            Appointment__c
                                        WHERE
                                            External_Record_Id__c
                                        IN
                                            :incomingClientApptIds
                                        WITH SECURITY_ENFORCED]){
                    existingApptMap.put(exist.External_Record_Id__c,exist);
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
                if(String.isNotBlank(serverId)&&validServerAppts.containsKey(serverId)){
                    // Set Id directly to update existing record
                    existingRecord=validServerAppts.get(serverId);
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
                    // Safely convert date string to DateTime then Date
                    appt.Appointment_Date__c=((DateTime)JSON.deserialize('"'+dateObj+'"',DateTime.class)).date();
                }
                appt.Appointment_Status__c=(String)w.get('status');
                appt.Reason_for_Visit__c=(String)w.get('reason');
                // Resolve lookups using maps
                String pExtId=(String)w.get('patientExternalId');
                if(String.isNotBlank(pExtId)&&validPatientIds.contains(pExtId)){
                    appt.Patient__c=pExtId;
                }
                upsertList.add(appt);
                clientIds.add((String)w.get('clientAppointmentId'));
            }
            if(!upsertList.isEmpty()){
                // Bulk upsert
                upsert upsertList;
                for(Integer i=0; i<upsertList.size(); i++){
                    // Map ClientId to newly saved SF Id and Status for response
                    Map<String,String> details=new Map<String,String>();
                    details.put('serverAppointmentId',upsertList[i].Id);
                    details.put('status',upsertList[i].Appointment_Status__c);
                    responseMap.put(clientIds[i],details);
                }
            }
        }catch(Exception e){
            throw new StringException('Error: '+e.getMessage());
        }
        return responseMap;
    }
}
