import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getPrescriptions from '@salesforce/apex/c/PortalPrescriptionController.getPrescriptions';
const MEDICATION_COLUMNS = [
    { label: 'Medication Name', fieldName: 'Name' },
    { label: 'Dosage', fieldName: 'Dosage__c' },
    { label: 'Quantity', fieldName: 'Quantity__c', type: 'number' }
];
export default class PatientPrescriptions extends LightningElement {
    @track accountId; 
    @track prescriptions;
    columns = MEDICATION_COLUMNS;
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
    @wire(getPrescriptions, { accountId: '$accountId' })
    wiredPrescriptions({ error, data }) {
        if (data) {
            this.prescriptions = data.map(record => ({
                ...record,
                label: `${record.Name} - ${new Date(record.CreatedDate).toLocaleDateString()}`,
                hasMedications: record.Medication_Line_Items__r && record.Medication_Line_Items__r.length > 0,
                Medication_Line_Items__r: record.Medication_Line_Items__r || []
            }));
        } else if (error) {
            console.error('Error loading prescriptions', error);
        }
    }
}