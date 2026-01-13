import { LightningElement, track } from 'lwc';
import getPrescriptions from '@salesforce/apex/PortalPrescriptionsController.getPrescriptions';
const COLUMNS = [
    { 
        label: 'Prescription Number', 
        fieldName: 'Name', 
        type: 'button', 
        typeAttributes: { label: { fieldName: 'Name' }, variant: 'base' },
        sortable: true 
    },
    { label: 'Doctor Name', fieldName: 'DoctorName', type: 'text', sortable: true },
    { label: 'Date', fieldName: 'Prescription_Date__c', type: 'date', sortable: true }
];
export default class PortalPrescription extends LightningElement {
    @track prescriptions = [];
    @track columns = COLUMNS;
    @track groupedPrescriptions = [];
    @track sortedBy;
    @track sortedDirection = 'asc';
    
    // Modal State
    @track isModalOpen = false;
    @track selectedPrescription = {};
    @track selectedMedications = [];

    connectedCallback() {
        this.fetchData();
    }

    async fetchData() {
        const accountId = window.sessionStorage.getItem('portalAccountId');
        try {
            const data = await getPrescriptions({ accountId: accountId });
            this.prescriptions = data;
            this.processConsultationGroups(data);
        } catch (error) {
            console.error('Error fetching prescriptions', error);
        }
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.prescriptions];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.prescriptions = cloneData;
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
        this.selectedPrescription = row;
        
        // Parse medications if they are not already an array (though they should be from controller)
        if (row.Medications) {
            this.selectedMedications = Array.isArray(row.Medications) ? row.Medications : [];
        } else {
            this.selectedMedications = [];
        }
        
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    processConsultationGroups(data) {
        const groups = {};
        data.forEach(item => {
            // Group by Date and Doctor to simulate a Consultation view
            const date = item.Prescription_Date__c || 'Unknown Date';
            const doctor = item.DoctorName || 'Unknown Doctor';
            const key = `${date}-${doctor}`;

            if (!groups[key]) {
                groups[key] = {
                    id: key,
                    title: `${date} - ${doctor}`,
                    items: []
                };
            }
            groups[key].items.push(item);
        });
        // Sort groups by date descending (newest consultations first)
        this.groupedPrescriptions = Object.values(groups).sort((a, b) => b.id.localeCompare(a.id));
    }
}
