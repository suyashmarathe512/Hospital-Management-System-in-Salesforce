public with sharing class AccountSyncBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AccountSyncBatch(), 200);
        Datetime nextRun = Datetime.now().addMinutes(15);
        String cronExp = '0 ' +nextRun.minute() + ' ' +nextRun.hour() + ' * * ?';
        String jobName = 'AccountSync_' + nextRun.getTime();
        System.schedule(jobName, cronExp, new AccountSyncBatchScheduler());
        System.abortJob(sc.getTriggerId());
    }
}