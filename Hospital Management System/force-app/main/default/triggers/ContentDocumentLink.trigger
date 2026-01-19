trigger ContentDocumentLink on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        new ContentDocumentTriggerHandler().handleAfterInsert(Trigger.new);
    }
}