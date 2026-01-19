trigger AppointmentTrigger on Appointment__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.onBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.onAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}