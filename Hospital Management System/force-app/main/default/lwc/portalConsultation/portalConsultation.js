import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getConsultations from '@salesforce/apex/PortalConsultationsController.getConsultations';

export default class PortalConsultations extends NavigationMixin(LightningElement) {
    @track accountId;
    @track consultations = [];
    @track currentDetail = {};
    @track isLoading = true;
    @track detailsLoading = false;
    // Track which card is expanded
    expandedId = null;
    connectedCallback() {
        // Retrieve Account ID from session storage (consistent with other portal components)
        this.accountId = sessionStorage.getItem('portalAccountId');
    }

    @wire(getConsultations, { accountId: '$accountId' })
    wiredSummaries({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.consultations = data.map(con => ({
                id: con.Id,
                name: con.Name,
                doctorName: con.DoctorName,
                visitDate: con.Date_of_Visit__c,
                visitCharges: con.Visit_Charges__c,
                status: this.calculateStatus(con.Next_Visit__c),
                isExpanded: false,
                badgeClass: this.getBadgeClass(this.calculateStatus(con.Next_Visit__c))
            }));
            this.sortConsultations();
        } else if (error) {
            console.error('Error fetching consultations:', error);
            this.consultations = [];
        }
    }

    get sortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    handleSort() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortConsultations();
    }

    sortConsultations() {
        let data = [...this.consultations];
        const isAsc = this.sortDirection === 'asc';
        data.sort((a, b) => {
            return isAsc ? new Date(a.visitDate) - new Date(b.visitDate) : new Date(b.visitDate) - new Date(a.visitDate);
        });
        this.consultations = data;
    }

    calculateStatus(nextVisitDate) {
        if (nextVisitDate && new Date(nextVisitDate) > new Date()) {
            return 'Follow-up';
        }
        return 'Completed';
    }

    get hasConsultations() {
        return this.consultations && this.consultations.length > 0;
    }

    getBadgeClass(status) {
        // SLDS Badge styling
        if (status === 'Completed') {
            return 'slds-badge slds-theme_success';
        } else if (status === 'Follow-up') {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge';
    }

    async handleToggle(event) {
        const id = event.currentTarget.dataset.id;

        // If clicking the already expanded card, collapse it
        if (this.expandedId === id) {
            this.expandedId = null;
            this.updateExpansionState();
            return;
        }

        // Expand new card
        this.expandedId = id;
        this.updateExpansionState();
        this.setDetails(id);
    }

    updateExpansionState() {
        this.consultations = this.consultations.map(con => ({
            ...con,
            isExpanded: con.id === this.expandedId
        }));
    }

    setDetails(id) {
        const selected = this.consultations.find(c => c.id === id);
        if (selected) {
            this.currentDetail = {
                appointmentName: selected.name,
                visitCharges: selected.visitCharges,
                // Prescription and Billing are not available in the current Apex controller
                prescription: null,
                billing: null
            };
        }
    }

    handleViewBill(event) {
        const docId = event.target.dataset.docId;
        if (docId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: docId
                }
            });
        }
    }
}
