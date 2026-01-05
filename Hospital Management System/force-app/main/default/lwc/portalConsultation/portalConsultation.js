import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getConsultations from '@salesforce/apex/PortalConsultationController.getConsultations';
const COLUMNS = [
    { label: 'Consultation Number', fieldName: 'Name' },
    { label: 'Patient', fieldName: 'PatientName' },
    { label: 'Date of Visit', fieldName: 'Date_of_Visit__c', type: 'date' },
    { label: 'Next Visit', fieldName: 'Next_Visit__c', type: 'date' },
    { label: 'Doctor', fieldName: 'DoctorName' },
    { label: 'Visit Charges', fieldName: 'Visit_Charges__c', type: 'currency' }
];
export default class PortalConsultation extends LightningElement {
    @track accountId;
    @track consultations;
    columns = COLUMNS;
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state.accountId) {
            this.accountId = currentPageReference.state.accountId;
        }
    }
    connectedCallback() {
        const storedAccountId = window.sessionStorage.getItem('portalAccountId');
        if (!this.accountId && storedAccountId) {
            this.accountId = storedAccountId;
        }
    }
    @wire(getConsultations, { accountId: '$accountId' })
    wiredConsultations({ error, data }) {
        if (data) {
            this.consultations = data.map(record => ({
                ...record,
                PatientName: record.Patient__r ? record.Patient__r.Name : '',
                DoctorName: record.Doctor__r ? record.Doctor__r.Name : ''
            }));
        } else if (error) {
            console.error('Error loading consultations', error);
        }
    }
}