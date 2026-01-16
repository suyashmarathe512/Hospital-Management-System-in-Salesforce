import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getPrescriptionDetails from '@salesforce/apex/GenerateBill.getPrescriptionDetails';
// Import createBill from the dedicated GenerateBill controller
import createBill from '@salesforce/apex/GenerateBill.createBill';

export default class GenerateBill extends NavigationMixin(LightningElement) {
    _recordId;
    @api 
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (this._recordId) {
            this.fetchPrescriptionData();
        }
    }
    
    @track isLoading = true;
    @track billDate = new Date().toISOString().slice(0, 10);
    @track taxPercentage = 0;
    @track billItems = [];
    @track patientName;
    @track doctorName;
    @track showMedicationModal = false;

    connectedCallback() {
        // If recordId is not available yet, the setter will trigger the fetch.
    }

    fetchPrescriptionData() {
        getPrescriptionDetails({ prescriptionId: this._recordId })
            .then(data => {
                if (data) {
                    // Handle potential differences in returned object structure
                    this.patientName = data.Patient__r ? data.Patient__r.Name : (data.patientName || 'Unknown');
                    this.doctorName = data.Doctor__r ? data.Doctor__r.Name : (data.doctorName || 'Unknown');
                    
                    if (data.medications && data.medications.length > 0) {
                        this.billItems = data.medications.map(med => ({
                            id: med.Id,
                            medicationId: med.Id,
                            quantity: med.Quantity__c || 1,
                            price: 0, // Price to be filled by user
                            total: 0
                        }));
                    } else {
                        this.handleAddItem(); // Add one empty row if no meds
                    }
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching prescription:', error);
                const message = error.body ? error.body.message : 'Failed to load prescription details.';
                this.showToast('Error', message, 'error');
                this.isLoading = false;
            });
    }

    handleDateChange(event) {
        this.billDate = event.target.value;
    }

    handleTaxChange(event) {
        this.taxPercentage = parseFloat(event.target.value) || 0;
    }

    handleItemChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.dataset.field;
        const value = event.target.value;

        // Create a copy of the item to mutate
        let item = { ...this.billItems[index] };
        
        if (field === 'quantity' || field === 'price') {
            item[field] = parseFloat(value) || 0;
            item.total = item.quantity * item.price;
        } else if (field === 'medicationId') {
            // lightning-input-field returns value in event.detail.value (array or string)
            item.medicationId = event.detail.value[0] || event.detail.value;
        } else {
            item[field] = value;
        }

        // Update the array
        let newItems = [...this.billItems];
        newItems[index] = item;
        this.billItems = newItems;
    }

    handleAddItem() {
        this.billItems = [...this.billItems, {
            id: Date.now(),
            medicationId: null,
            quantity: 1,
            price: 0,
            total: 0
        }];
    }

    handleRemoveItem(event) {
        const index = event.target.dataset.index;
        this.billItems = this.billItems.filter((_, i) => i != index);
    }

    get subTotal() {
        return this.billItems.reduce((sum, item) => sum + (item.total || 0), 0);
    }

    get taxAmount() {
        return this.subTotal * (this.taxPercentage / 100);
    }

    get grandTotal() {
        return this.subTotal + this.taxAmount;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleOpenMedicationModal() {
        this.showMedicationModal = true;
    }

    handleCloseMedicationModal() {
        this.showMedicationModal = false;
    }

    handleMedicationSuccess(event) {
        const newMedId = event.detail.id;
        const fields = event.detail.fields;
        const quantity = fields.Quantity__c ? parseFloat(fields.Quantity__c.value) : 1;

        this.showToast('Success', 'Medication created successfully', 'success');
        this.showMedicationModal = false;

        this.billItems = [...this.billItems, {
            id: newMedId,
            medicationId: newMedId,
            quantity: quantity,
            price: 0,
            total: 0
        }];
    }

    handleSave() {
        // Basic Validation
        const validItems = this.billItems.filter(item => item.medicationId && item.price > 0);
        
        if (validItems.length === 0) {
            this.showToast('Warning', 'Please add at least one valid bill item with a price.', 'warning');
            return;
        }

        this.isLoading = true;
        
        const billData = {
            prescriptionId: this.recordId,
            billDate: this.billDate,
            taxPercentage: this.taxPercentage,
            subTotal: this.subTotal,
            totalAmount: this.grandTotal
        };

        const lineItems = validItems.map(item => ({
            quantity: item.quantity,
            price: item.price,
            medicationId: item.medicationId
        }));

        createBill({ billData: billData, lineItems: lineItems })
            .then((newBillId) => {
                this.showToast('Success', 'Bill generated successfully!', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
                
                // Navigate to the newly created Bill record
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: newBillId,
                        objectApiName: 'Bill__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(error => {
                console.error('Error creating bill:', error);
                this.showToast('Error', error.body ? error.body.message : 'Error creating bill', 'error');
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}