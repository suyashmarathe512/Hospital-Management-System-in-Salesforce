import{LightningElement,wire,track} from 'lwc';
import{CurrentPageReference}from 'lightning/navigation';
import{getRecord,getFieldValue} from 'lightning/uiRecordApi';
// Appointment Fields
import APPT_NAME_FIELD from '@salesforce/schema/Appointment__c.Name';
import APPT_DATE_FIELD from '@salesforce/schema/Appointment__c.Appointment_Date__c';
import APPT_STATUS_FIELD from '@salesforce/schema/Appointment__c.Appointment_Status__c';
import APPT_REASON_FIELD from '@salesforce/schema/Appointment__c.Reason_for_Visit__c';
import PATIENT_NAME_FIELD from '@salesforce/schema/Appointment__c.Patient__r.Name';
// Patient(Person Account) Fields fetched via Relationship
import PATIENT_EMAIL_FIELD from '@salesforce/schema/Appointment__c.Patient__r.PersonEmail';
import PATIENT_PHONE_FIELD from '@salesforce/schema/Appointment__c.Patient__r.Phone';
import PATIENT_AGE_FIELD from '@salesforce/schema/Appointment__c.Patient__r.Age__c';
import PATIENT_DOB_FIELD from '@salesforce/schema/Appointment__c.Patient__r.PersonBirthdate';
const FIELDS=[
    APPT_NAME_FIELD,
    APPT_DATE_FIELD,
    APPT_STATUS_FIELD,
    APPT_REASON_FIELD,
    PATIENT_NAME_FIELD,
    PATIENT_EMAIL_FIELD,
    PATIENT_PHONE_FIELD,
    PATIENT_AGE_FIELD,
    PATIENT_DOB_FIELD
];
export default class AppoinmentViewer extends LightningElement{
    @track recordId;
    @track isModalOpen=false;
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference){
        if(currentPageReference&&currentPageReference.state){
            this.recordId=currentPageReference.state.recordId;
        }
    }
    @wire(getRecord,{recordId:'$recordId',fields:FIELDS })
    appointment;
    get isLoading(){
        return !this.appointment || (!this.appointment.data && !this.appointment.error);
    }
    get appointmentData(){return this.appointment.data; }
    get patientName(){return getFieldValue(this.appointment.data,PATIENT_NAME_FIELD);}
    get patientEmail(){return getFieldValue(this.appointment.data,PATIENT_EMAIL_FIELD);}
    get patientPhone(){return getFieldValue(this.appointment.data,PATIENT_PHONE_FIELD);}
    get patientAge(){return getFieldValue(this.appointment.data,PATIENT_AGE_FIELD);}
    get patientDob(){return getFieldValue(this.appointment.data,PATIENT_DOB_FIELD);}
    openModal(){
        this.isModalOpen=true;
    }
    closeModal(){
        this.isModalOpen=false;
    }
    handleBack(){
        window.location.href='/DoctorsHealthXi/dashboard';
    }
}