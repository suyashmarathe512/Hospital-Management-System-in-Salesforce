public with sharing class AppointmentTriggerHandler {
    public static void onAfterInsert(List<Appointment__c> newAppointments) {
        sendAssignmentNotifications(newAppointments, null);
    }
    public static void onAfterUpdate(List<Appointment__c> newAppointments, Map<Id, Appointment__c> oldMap) {
        sendAssignmentNotifications(newAppointments, oldMap);
    }
    public static void enforceDailyQuota(List<Appointment__c> newAppointments, Map<Id, Appointment__c> oldMap) {
        final Integer DAILY_QUOTA = 10;
        final String STATUS_CONFIRMED = 'Confirmed';
        final String STATUS_COMPLETED = 'Completed';
        final String STATUS_WAITING = 'Queued';
        Set<Id> doctorIdsToCheck = new Set<Id>();
        Set<Date> relevantDates = new Set<Date>();
        List<Appointment__c> apptsToAssign = new List<Appointment__c>();
        List<Appointment__c> apptsToValidate = new List<Appointment__c>();
        for (Appointment__c appt : newAppointments) {
            // Ensure Date is present
            if (appt.Appointment_Date__c != null) {
                Boolean isRelevant = false;
                if (oldMap == null) {
                    isRelevant = true;
                } else {
                    Appointment__c oldAppt = oldMap.get(appt.Id);
                    if (appt.Doctor__c != oldAppt.Doctor__c ||
                        appt.Appointment_Date__c != oldAppt.Appointment_Date__c ||
                        appt.Appointment_Status__c != oldAppt.Appointment_Status__c) {
                        isRelevant = true;
                    }
                }
                // Only process if status is not explicitly Cancelled or Completed
                if (isRelevant && appt.Appointment_Status__c != 'Cancelled' && appt.Appointment_Status__c != 'Completed') {
                    if (appt.Doctor__c == null) {
                        apptsToAssign.add(appt);
                    } else {
                        apptsToValidate.add(appt);
                        doctorIdsToCheck.add(appt.Doctor__c);
                    }
                    relevantDates.add(appt.Appointment_Date__c);
                }
            }
        }
        if (!apptsToAssign.isEmpty() || !apptsToValidate.isEmpty()) {
            // If we need to auto-assign, we need to look at ALL doctors
            List<Doctor__c> allDoctors = new List<Doctor__c>();
            if (!apptsToAssign.isEmpty()) {
                allDoctors = [SELECT Id FROM Doctor__c];
                for (Doctor__c doc : allDoctors) {
                    doctorIdsToCheck.add(doc.Id);
                }
            }
            Map<String, Integer> doctorDateCounts = new Map<String, Integer>();
            Set<Id> scopeIds = (oldMap != null) ? oldMap.keySet() : new Set<Id>();
            // Count existing Confirmed appointments (excluding current trigger records)
            for (AggregateResult ar : [SELECT 
                                            Doctor__c, Appointment_Date__c, COUNT(Id) cnt 
                                       FROM 
                                            Appointment__c 
                                       WHERE 
                                            Doctor__c IN :doctorIdsToCheck 
                                       AND 
                                            Appointment_Date__c IN :relevantDates 
                                       AND 
                                            Appointment_Status__c IN (:STATUS_CONFIRMED, :STATUS_COMPLETED)
                                       AND 
                                            Id NOT IN :scopeIds 
                                       GROUP BY 
                                            Doctor__c, Appointment_Date__c]) {
                doctorDateCounts.put((Id)ar.get('Doctor__c') + '_' + (Date)ar.get('Appointment_Date__c'), (Integer)ar.get('cnt'));
            }
            // 1. Handle Auto-Assignment
            for (Appointment__c appt : apptsToAssign) {
                if (allDoctors.isEmpty()) {
                    appt.addError('No doctors available for assignment.');
                    continue;
                }
                Boolean assigned = false;
                // Try to find a doctor with available quota
                for (Doctor__c doc : allDoctors) {
                    String key = doc.Id + '_' + appt.Appointment_Date__c;
                    Integer currentCount = doctorDateCounts.containsKey(key) ? doctorDateCounts.get(key) : 0;
                    if (currentCount < DAILY_QUOTA) {
                        appt.Doctor__c = doc.Id;
                        appt.Appointment_Status__c = STATUS_CONFIRMED;
                        doctorDateCounts.put(key, currentCount + 1);
                        assigned = true;
                        break;
                    }
                }
                // If no doctor has space, assign to the first one and set to Waiting Queue
                if (!assigned) {
                    Doctor__c fallbackDoc = allDoctors[0];
                    appt.Doctor__c = fallbackDoc.Id;
                    appt.Appointment_Status__c = STATUS_WAITING;
                    // Do not increment count as Waiting Queue doesn't consume quota
                }
            }
            // 2. Handle Manual Assignment / Validation
            for (Appointment__c appt : apptsToValidate) {
                String key = appt.Doctor__c + '_' + appt.Appointment_Date__c;
                Integer currentCount = doctorDateCounts.containsKey(key) ? doctorDateCounts.get(key) : 0;
                if (currentCount < DAILY_QUOTA) {
                    // Automatically accept if quota allows
                    if (appt.Appointment_Status__c != STATUS_CONFIRMED) {
                        appt.Appointment_Status__c = STATUS_CONFIRMED;
                    }
                    // Increment count for the next iteration in this transaction
                    doctorDateCounts.put(key, currentCount + 1);
                } else {
                    // Move to Waiting Queue if quota reached
                    appt.Appointment_Status__c = STATUS_WAITING;
                }
            }
        }
    }
    private static void sendAssignmentNotifications(List<Appointment__c> newAppointments, Map<Id, Appointment__c> oldMap) {
        Set<Id> doctorIds = new Set<Id>();
        Set<Id> patientIds = new Set<Id>();
        List<Appointment__c> doctorNotificationAppts = new List<Appointment__c>();
        List<Appointment__c> patientNotificationAppts = new List<Appointment__c>();
        for (Appointment__c appt : newAppointments) {
            // 1. Doctor Notification Logic (Assignment)
            if (appt.Doctor__c != null) {
                Boolean isAssigned = false;
                if (oldMap == null) {
                    isAssigned = true;
                } else {
                    Appointment__c oldAppt = oldMap.get(appt.Id);
                    if (appt.Doctor__c != oldAppt.Doctor__c) {
                        isAssigned = true;
                    }
                }
                if (isAssigned) {
                    doctorIds.add(appt.Doctor__c);
                    if (appt.Patient__c != null) patientIds.add(appt.Patient__c);
                    doctorNotificationAppts.add(appt);
                }
            }
            // 2. Patient Notification Logic (Confirmation)
            if (appt.Patient__c != null && appt.Appointment_Status__c == 'Confirmed') {
                Boolean isConfirmed = false;
                if (oldMap == null) {
                    isConfirmed = true;
                } else {
                    Appointment__c oldAppt = oldMap.get(appt.Id);
                    // Notify if status changed to Confirmed, or if Confirmed and Doctor/Date changed
                    if (appt.Appointment_Status__c != oldAppt.Appointment_Status__c || 
                        appt.Doctor__c != oldAppt.Doctor__c ||
                        appt.Appointment_Date__c != oldAppt.Appointment_Date__c) {
                        isConfirmed = true;
                    }
                }
                if (isConfirmed) {
                    patientIds.add(appt.Patient__c);
                    if (appt.Doctor__c != null) doctorIds.add(appt.Doctor__c);
                    patientNotificationAppts.add(appt);
                }
            }
        }
        if (!doctorNotificationAppts.isEmpty() || !patientNotificationAppts.isEmpty()) {
            Map<Id, Doctor__c> doctorsMap = new Map<Id, Doctor__c>(
                [SELECT 
                    Id, Name, Email__c
                FROM
                    Doctor__c
                WHERE
                    Id IN :doctorIds]
            );
            Map<Id, Account> patientsMap = new Map<Id, Account>();
            if (!patientIds.isEmpty()) {
                patientsMap = new Map<Id, Account>([SELECT Id, Name, PersonEmail FROM Account WHERE Id IN :patientIds]);
            }
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            // Generate Doctor Emails
            for (Appointment__c appt : doctorNotificationAppts) {
                Doctor__c doc = doctorsMap.get(appt.Doctor__c);
                if (doc != null && String.isNotBlank(doc.Email__c)) {
                    String patientName = (appt.Patient__c != null && patientsMap.containsKey(appt.Patient__c)) 
                                         ? patientsMap.get(appt.Patient__c).Name 
                                         : 'N/A';
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{doc.Email__c});
                    mail.setSubject('New Appointment Assigned');
                    String body = '<html><body style="font-family: Arial, sans-serif;">';
                    body += '<h2 style="color: #2c3e50;">New Appointment Assigned</h2>';
                    body += '<p>Dear Dr. ' + doc.Name + ',</p>';
                    body += '<p>You have been assigned a new appointment. Please find the details below:</p>';
                    body += '<table style="border-collapse: collapse; width: 100%; max-width: 600px;">';
                    body += '<tr style="background-color: #f2f2f2;"><td style="padding: 10px; border: 1px solid #ddd;"><strong>Patient Name</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + patientName + '</td></tr>';
                    body += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Date</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + (appt.Appointment_Date__c != null ? String.valueOf(appt.Appointment_Date__c) : '') + '</td></tr>';
                    body += '<tr style="background-color: #f2f2f2;"><td style="padding: 10px; border: 1px solid #ddd;"><strong>Status</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + (appt.Appointment_Status__c != null ? appt.Appointment_Status__c : '') + '</td></tr>';
                    body += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Reason for Visit</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + (appt.Reason_for_Visit__c != null ? appt.Reason_for_Visit__c : 'N/A') + '</td></tr>';
                    body += '</table>';
                    body += '<br/><p>Regards,<br/><strong>Hospital Management System</strong></p>';
                    body += '</body></html>';
                    mail.setHtmlBody(body);
                    emails.add(mail);
                }
            }
            // Generate Patient Emails
            for (Appointment__c appt : patientNotificationAppts) {
                Account patient = patientsMap.get(appt.Patient__c);
                if (patient != null && String.isNotBlank(patient.PersonEmail)) {
                    String doctorName = (appt.Doctor__c != null && doctorsMap.containsKey(appt.Doctor__c)) 
                                        ? doctorsMap.get(appt.Doctor__c).Name 
                                        : 'Not Assigned';
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new List<String>{patient.PersonEmail});
                    mail.setSubject('Appointment Confirmed');
                    String body = '<html><body style="font-family: Arial, sans-serif;">';
                    body += '<h2 style="color: #2c3e50;">Appointment Confirmed</h2>';
                    body += '<p>Dear ' + patient.Name + ',</p>';
                    body += '<p>Your appointment has been confirmed. Please find the details below:</p>';
                    body += '<table style="border-collapse: collapse; width: 100%; max-width: 600px;">';
                    body += '<tr style="background-color: #f2f2f2;"><td style="padding: 10px; border: 1px solid #ddd;"><strong>Doctor</strong></td><td style="padding: 10px; border: 1px solid #ddd;">Dr. ' + doctorName + '</td></tr>';
                    body += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Date</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + (appt.Appointment_Date__c != null ? String.valueOf(appt.Appointment_Date__c) : '') + '</td></tr>';
                    body += '<tr style="background-color: #f2f2f2;"><td style="padding: 10px; border: 1px solid #ddd;"><strong>Status</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + (appt.Appointment_Status__c != null ? appt.Appointment_Status__c : '') + '</td></tr>';
                    body += '<tr><td style="padding: 10px; border: 1px solid #ddd;"><strong>Reason for Visit</strong></td><td style="padding: 10px; border: 1px solid #ddd;">' + (appt.Reason_for_Visit__c != null ? appt.Reason_for_Visit__c : 'N/A') + '</td></tr>';
                    body += '</table>';
                    body += '<br/><p>Regards,<br/><strong>Hospital Management System</strong></p>';
                    body += '</body></html>';
                    
                    mail.setHtmlBody(body);
                    emails.add(mail);
                }
            }
            if (!emails.isEmpty()) {
                try {
                    Messaging.sendEmail(emails);
                } catch (Exception e) {
                    System.debug('Error sending emails: ' + e.getMessage());
                }
            }
        }
    }
}