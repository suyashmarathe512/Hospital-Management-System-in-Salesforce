import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPrescriptionSummaries from '@salesforce/apex/PortalPrescriptionsController.getPrescriptionSummaries';
import getPrescriptionDetails from '@salesforce/apex/PortalPrescriptionsController.getPrescriptionDetails';

export default class PortalPrescription extends NavigationMixin(LightningElement) {
    @track accountId;
    @track allPrescriptions = [];
    @track isModalOpen = false;
    @track selectedPrescription = {};
    @track selectedMedications = [];
    // Loading states
    @track summaryLoading = true;
    @track detailsLoading = false;
    // Filter state
    @track filterType = 'Active'; // 'Active' or 'All'

    connectedCallback() {
        this.accountId = sessionStorage.getItem('portalAccountId');
    }
    @wire(getPrescriptionSummaries, { accountId: '$accountId' })
    wiredPrescriptions({ error, data }) {
        this.summaryLoading = false;
        if (data) {
            this.allPrescriptions = data;
        } else if (error) {
            console.error('Error fetching prescriptions:', error);
            this.allPrescriptions = [];
        }
    }
    get filteredPrescriptions() {
        if (this.filterType === 'Active') {
            return this.allPrescriptions.filter(p => p.isActive);
        }
        return this.allPrescriptions;
    }
    get hasPrescriptions() {
        return this.filteredPrescriptions && this.filteredPrescriptions.length > 0;
    }
    get activeVariant() {
        return this.filterType === 'Active' ? 'brand' : 'neutral';
    }
    get allVariant() {
        return this.filterType === 'All' ? 'brand' : 'neutral';
    }
    handleFilterActive() {
        this.filterType = 'Active';
    }

    handleFilterAll() {
        this.filterType = 'All';
    }
    handleViewDetails(event) {
        const prescriptionId = event.currentTarget.dataset.id;
        this.isModalOpen = true;
        this.detailsLoading = true;
        this.selectedPrescription = {}; // Clear previous
        this.selectedMedications = [];
        getPrescriptionDetails({ prescriptionId })
            .then(result => {
                this.selectedPrescription = result;
                this.selectedMedications = result.medications || [];
                this.detailsLoading = false;
            })
            .catch(error => {
                console.error('Error fetching details:', error);
                this.detailsLoading = false;
            });
    }

    handlePreview() {
        if (this.selectedPrescription.contentDocumentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: this.selectedPrescription.contentDocumentId
                }
            });
        }
    }
    closeModal() {
        this.isModalOpen = false;
    }
}