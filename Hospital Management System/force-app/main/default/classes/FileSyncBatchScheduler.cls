/*****************************************************************************************************
 * @Author:       CRM Team Innovation
 * @ClassName:   FileSyncBatchScheduler.cls
 * @Description:  This Class belongs to client org.
 *                This class is responsible for scheduling the batch class for every 15 minutes.
 **************************************************************************************************************/
public with sharing class FileSyncBatchScheduler implements Schedulable{
    /*****************************************************************************************************
     * @Author:       CRM Team Innovation
     * @MethodName:   execute
     * @Param:        SchedulableContext sc
     * @Description:  Executes the batch and schedules the next run in 15 minutes.
     ******************************************************************************************************/
    public void execute(SchedulableContext sc){
        Database.executeBatch(new FileSyncBatch(),1);
        Datetime nextRun=Datetime.now().addMinutes(15);
        String cronExp='0 '+nextRun.minute()+' '+nextRun.hour()+' * * ?';
        String jobName='FileSync_'+nextRun.getTime();
        System.schedule(jobName,cronExp,new FileSyncBatchScheduler());
        System.abortJob(sc.getTriggerId());
    }
}