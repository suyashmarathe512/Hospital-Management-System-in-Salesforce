public with sharing class AppointmentSyncBatchScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AppointmentSyncBatch(), 100);
        Datetime nextRun = Datetime.now().addMinutes(15);
        String cronExp = '0 ' + nextRun.minute() + ' ' + nextRun.hour() + ' * * ?';
        String jobName = 'AppointmentSync_' + nextRun.getTime();
        System.schedule(jobName, cronExp, new AppointmentSyncBatchScheduler());
        System.abortJob(sc.getTriggerId());
    }
}