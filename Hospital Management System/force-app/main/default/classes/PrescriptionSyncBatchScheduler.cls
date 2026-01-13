/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @ClassName:   PrescriptionSyncBatchScheduler
 * @Description:  This Class belongs to client org.
 *                This class is responsible for scheduling the batch class for every 15 minutes.
 **************************************************************************************************************/
public with sharing class PrescriptionSyncBatchScheduler implements Schedulable{
    public void execute(SchedulableContext sc){
        Database.executeBatch(new PrescriptionSyncBatch(),200);
        Datetime nextRun=Datetime.now().addMinutes(15);
        String cronExp='0 '+nextRun.minute()+' ' +nextRun.hour()+' * * ?';
        String jobName='PrescriptionSync_'+nextRun.getTime();
        System.schedule(jobName,cronExp, new PrescriptionSyncBatchScheduler());
        System.abortJob(sc.getTriggerId());
    }
}