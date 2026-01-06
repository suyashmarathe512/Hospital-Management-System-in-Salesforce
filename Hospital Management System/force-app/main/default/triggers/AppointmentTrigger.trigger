trigger AppointmentTrigger on Appointment__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.enforceDailyQuota(Trigger.new, null);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.enforceDailyQuota(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.onAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}