import{LightningElement, track, wire }from 'lwc';
import{NavigationMixin }from 'lightning/navigation';
import{ShowToastEvent }from 'lightning/platformShowToastEvent';
import getPrescriptionSummaries from '@salesforce/apex/PortalPrescriptionsController.getPrescriptionSummaries';
import getPrescriptionDetails from '@salesforce/apex/PortalPrescriptionsController.getPrescriptionDetails';
import getBillDetails from '@salesforce/apex/PortalPrescriptionsController.getBillDetails';
import emailInvoicePdf from '@salesforce/apex/PortalPrescriptionsController.emailInvoicePdf';
export default class PortalPrescription extends NavigationMixin(LightningElement){
    @track accountId;
    @track allPrescriptions=[];
    @track isModalOpen=false;
    @track selectedPrescription ={ };
    @track selectedMedications=[];
    // Loading states
    @track summaryLoading=true;
    @track detailsLoading=false;
    @track billData=null;
    @track showInvoice=false;
    // Filter state
    @track filterType='Active'; // 'Active' or 'All'
    // Modal Toast state
    @track modalMessage = '';
    @track modalMessageType = '';
    @track showModalMessage = false;
    connectedCallback(){
        this.accountId=sessionStorage.getItem('portalAccountId');
        console.log('PortalPrescription:Loaded accountId from session:', this.accountId);
        if(!this.accountId){
            console.warn('PortalPrescription:No accountId found. Please ensure you have logged in via the Portal Login component.');
     }
 }
    @wire(getPrescriptionSummaries,{accountId:'$accountId' })
    wiredPrescriptions({error, data }){
        this.summaryLoading=false;
        if(data){
            this.allPrescriptions=data;
     }else if(error){
            console.error('Error fetching prescriptions:', error);
            this.allPrescriptions=[];
            this.dispatchEvent(
                new ShowToastEvent({
                    title:'Error',
                    message:'Unable to load prescriptions. Please try again later.',
                    variant:'error'
             })
            );
     }
 }
    get filteredPrescriptions(){
        if(this.filterType==='Active'){
            return this.allPrescriptions.filter(p=>p.isActive);
     }
        return this.allPrescriptions;
 }
    get hasPrescriptions(){
        return this.filteredPrescriptions&&this.filteredPrescriptions.length > 0;
 }
    get activeVariant(){
        return this.filterType==='Active'?'brand':'neutral';
 }
    get allVariant(){
        return this.filterType==='All'?'brand':'neutral';
 }
    handleFilterActive(){
        this.filterType='Active';
 }

    handleFilterAll(){
        this.filterType='All';
 }
    handleViewDetails(event){
        const prescriptionId=event.currentTarget.dataset.id;
        this.isModalOpen=true;
        this.detailsLoading=true;
        this.selectedPrescription ={ }; // Clear previous
        this.showModalMessage = false;
        this.showInvoice=false;
        this.billData=null;
        this.selectedMedications=[];
        getPrescriptionDetails({prescriptionId })
            .then(result=>{
                this.selectedPrescription=result;
                this.selectedMedications=result.medications || [];
                this.detailsLoading=false;
         })
            .catch(error=>{
                console.error('Error fetching details:', error);
                this.detailsLoading=false;
         });
 }
    handlePreview(){
        if(this.selectedPrescription.id){
            this.detailsLoading=true;
            getBillDetails({prescriptionId:this.selectedPrescription.id })
                .then(data=>{
                    console.log('Fetched Bill Data:', data);
                    this.billData=this.processBillData(data);
                    this.showInvoice=true;
                    this.detailsLoading=false;
             })
                .catch(error=>{
                    console.error('Error fetching bill details:', error);
                    this.detailsLoading=false;
             });
     }
 }
    handleEmailPdf(){
        if(this.selectedPrescription.id){
            this.detailsLoading=true;
            emailInvoicePdf({prescriptionId:this.selectedPrescription.id })
                .then(()=>{
                    this.triggerModalToast('Email will be sent shortly.', 'success');
                    this.detailsLoading=false;
             })
                .catch(error=>{
                    console.error('Error sending email:', error);
                    this.triggerModalToast(error.body?error.body.message:'Error sending email', 'error');
                    this.detailsLoading=false;
             });
     }
 }
    processBillData(data){
        // Flatten the JSON structure for easier use in the template
        let rawItems = [];
        if (data.Bill_Line_Items__r) {
            if (Array.isArray(data.Bill_Line_Items__r)) {
                rawItems = data.Bill_Line_Items__r;
            } else if (data.Bill_Line_Items__r.records && Array.isArray(data.Bill_Line_Items__r.records)) {
                rawItems = data.Bill_Line_Items__r.records;
            }
        }
        const items = rawItems.map(item=>({
                id:item.Id || Math.random(),
                medication:item.Medication__r?item.Medication__r.Name:'Unknown',
                price:item.Unit_Price__c,
                quantity:item.Quantity__c,
                total:item.Line_Total__c
         }));
        return{
            name:data.Name,
            date:data.Billing_Date__c,
            patientName:data.Patient__r?data.Patient__r.Name:'',
            doctorName:data.Consultation__r&&data.Consultation__r.Doctor__r?data.Consultation__r.Doctor__r.Name:'',
            subTotal:data.Sub_Total__c,
            taxPercentage:data.Tax_Percentage__c || 0,
            taxAmount:(data.Sub_Total__c *((data.Tax_Percentage__c || 0) / 100)).toFixed(2),
            totalAmount:data.Total_Amount__c,
            items:items
     };
 }
    get modalMessageClass() {
        return `slds-notify slds-notify_alert slds-theme_alert-texture slds-theme_${this.modalMessageType} slds-m-bottom_medium`;
    }
    get modalMessageIcon() {
        return this.modalMessageType === 'success' ? 'utility:success' : 'utility:error';
    }
    triggerModalToast(message, type) {
        this.modalMessage = message;
        this.modalMessageType = type;
        this.showModalMessage = true;
        // Auto-dismiss after 3 seconds
        setTimeout(() => {
            this.showModalMessage = false;
        }, 3000);
    }
    closeModal(){
        this.isModalOpen=false;
        this.showModalMessage = false;
 }
 }