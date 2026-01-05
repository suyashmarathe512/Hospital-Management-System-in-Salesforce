trigger AppointmentTrigger on Appointment__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            AppointmentTriggerHandler.onAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            AppointmentTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}