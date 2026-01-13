import { LightningElement, track } from 'lwc';
import getConsultations from '@salesforce/apex/PortalConsultationsController.getConsultations';

const COLUMNS = [
    { 
        label: 'Consultation Number', 
        fieldName: 'Name', 
        type: 'button', 
        typeAttributes: { label: { fieldName: 'Name' }, variant: 'base' },
        sortable: true 
    },
    { label: 'Doctor Name', fieldName: 'DoctorName', type: 'text', sortable: true },
    { label: 'Date of Visit', fieldName: 'Date_of_Visit__c', type: 'date', sortable: true },
    { label: 'Visit Charges', fieldName: 'Visit_Charges__c', type: 'currency', sortable: true }
];

export default class PortalConsultation extends LightningElement {
    @track consultations = [];
    @track columns = COLUMNS;
    @track sortedBy;
    @track sortedDirection = 'asc';
    
    // Modal State
    @track isModalOpen = false;
    @track selectedConsultation = {};

    connectedCallback() {
        this.fetchData();
    }

    async fetchData() {
        // Retrieve AccountId from session storage (set by portalLogin)
        const accountId = window.sessionStorage.getItem('portalAccountId');
        
        try {
            const data = await getConsultations({ accountId: accountId });
            // Flatten the data for the datatable
            this.consultations = data;
        } catch (error) {
            console.error('Error fetching consultations', error);
        }
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.consultations];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.consultations = cloneData;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) { return primer(x[field]); }
            : function (x) { return x[field]; };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    handleRowAction(event) {
        const row = event.detail.row;
        this.selectedConsultation = row;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }
}
