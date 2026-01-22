import{LightningElement,wire,track} from 'lwc';
import{CurrentPageReference}from 'lightning/navigation';
import{ShowToastEvent}from 'lightning/platformShowToastEvent';
import getAppointmentDetails from '@salesforce/apex/AppointmentViewerController.getAppointmentDetails';
import saveConsultation from '@salesforce/apex/AppointmentViewerController.saveConsultation';
import getConsultationFee from '@salesforce/apex/AppointmentViewerController.getConsultationFee';
import getConsultationHistory from '@salesforce/apex/AppointmentViewerController.getConsultationHistory';
import getPatientPrescriptions from '@salesforce/apex/AppointmentViewerController.getPatientPrescriptions';
export default class AppoinmentViewer extends LightningElement{
    @track recordId;
    @track isModalOpen=false;
    @track isConsultationModalOpen=false;
    @track medications=[];
    @track consultationNotes='';
    @track nextVisitDate='';
    @track numberOfVisits='';
    @track visitCharges='';
    @track isSaving=false;
    @track consultationHistory=[];
    @track upcomingAppointments=[];
    @track prescriptionHistory=[];
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference){
        if(currentPageReference&&currentPageReference.state){
            this.recordId=currentPageReference.state.recordId;
        }
    }
    @wire(getAppointmentDetails,{recordId:'$recordId'})
    appointment;
    get isLoading(){
        return !this.appointment || (!this.appointment.data && !this.appointment.error);
    }
    get appointmentData(){return this.appointment.data; }
    get patientName(){return this.appointment.data?.Patient__r?.Name;}
    get patientEmail(){return this.appointment.data?.Patient__r?.PersonEmail;}
    get patientPhone(){return this.appointment.data?.Patient__r?.Phone;}
    get patientAge(){return this.appointment.data?.Patient__r?.Age__c;}
    get patientDob(){return this.appointment.data?.Patient__r?.PersonBirthdate;}
    get doctorName(){return this.appointment.data?.Doctor__r?.Name; }
    get doctorId(){return this.appointment.data?.Doctor__c; }
    get patientId(){return this.appointment.data?.Patient__c; }
    get todayDate(){
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }
    @wire(getConsultationHistory, { patientId: '$patientId' })
    wiredHistory({ error, data }) {
        if (data) {
            this.consultationHistory = data.map(record => ({
                ...record,
                DoctorName: record.Doctor__r ? record.Doctor__r.Name : '',
                consultationUrl: '/' + record.Id,
                statusClass: record.Next_Visit__c ? 'slds-badge slds-theme_warning' : 'slds-badge slds-theme_success',
                statusLabel: record.Next_Visit__c ? 'Follow-up Required' : 'Completed'
            }));
        } else if (error) {
            console.error('Error loading history', error);
            this.consultationHistory = [];
        }
    }
    @wire(getPatientPrescriptions, { patientId: '$patientId' })
    wiredPrescriptions({ error, data }) {
        if (data) {
            this.prescriptionHistory = data.map(record => ({
                ...record,
                prescriptionUrl: '/' + record.Id,
                hasMedications: record.medications && record.medications.length > 0,
                hasNotes: !!record.Notes__c
            }));
        } else if (error) {
            console.error('Error loading prescriptions', error);
            this.prescriptionHistory = [];
        }
    }
    get hasHistory() { return this.consultationHistory && this.consultationHistory.length > 0; }
    get hasUpcoming() { return this.upcomingAppointments && this.upcomingAppointments.length > 0; }
    get hasPrescriptions() { return this.prescriptionHistory && this.prescriptionHistory.length > 0; }
    openModal(){
        this.isModalOpen=true;
    }
    closeModal(){
        this.isModalOpen=false;
    }
    handleBack(){
        window.location.href='/DoctorsHealthXi/dashboard';
    }
    // Consultation & Prescription Logic
    openConsultationModal(){
        this.isConsultationModalOpen=true;
        this.consultationNotes='';
        this.nextVisitDate='';
        this.numberOfVisits='';
        this.visitCharges='';
        this.medications=[{
            id:Date.now(),
            productId:'',
            quantity:1,
            instructions:''
        }];
        getConsultationFee({doctorId:this.doctorId,patientId:this.patientId,visitDate:this.todayDate})
        .then(result=>{
            this.visitCharges=result.fee;
            if(result.message && (result.message.includes('Discount') || result.message.includes('Free'))){
                this.dispatchEvent(new ShowToastEvent({
                    title:'Fee Adjusted',
                    message:result.message,
                    variant:'info'
                }));
            }
        })
        .catch(error=>{
            console.error('Error fetching fee:',error);
        });
    }
    closeConsultationModal(){
        this.isConsultationModalOpen=false;
    }
    handleNotesChange(event){
        this.consultationNotes=event.target.value;
    }
    handleGenericChange(event){
        const field=event.target.dataset.field;
        this[field]=event.target.value;
    }
    addMedication(){
        this.medications=[...this.medications,{
            id:Date.now(),
            productId:'',
            quantity:1,
            instructions:''
        }];
    }
    removeMedication(event){
        const index=event.target.dataset.index;
        this.medications=this.medications.filter((_, i) => i != index);
    }
    handleMedicationChange(event){
        const{index, field }=event.target.dataset;
        const value = field === 'productId' ? event.detail.value[0] : event.target.value;

        // Prevent duplicate medicine selection
        if (field === 'productId' && value) {
            const isDuplicate = this.medications.some((med, i) => i != index && med.productId === value);
            if (isDuplicate) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Duplicate Medicine',
                    message: 'This medicine has already been added to the prescription.',
                    variant: 'error'
                }));
                // Reset the field (requires re-render or manual reset, simplified here by not updating state)
                // In a real scenario, we might want to clear the input explicitly.
                return;
            }
        }

        const updatedMedications=[...this.medications];
        updatedMedications[index]={...updatedMedications[index], [field]: value };
        this.medications=updatedMedications;
    }
    handleSaveConsultation(){
        // Optimization:Filter out empty medication rows
        const validMedications=this.medications.filter(med => med.productId && med.quantity > 0);
        
        // Optimization:Validation to ensure meaningful data is saved
        if (!this.consultationNotes && validMedications.length === 0){
            this.dispatchEvent(new ShowToastEvent({
                title:'Validation Error',
                message:'Please enter clinical notes or at least one medication.',
                variant:'warning'
            }));
            return;
        }
        this.isSaving=true;
        const consultationData={
            doctorId:this.doctorId,
            patientId:this.patientId,
            visitDate:this.todayDate,
            notes:this.consultationNotes,
            nextVisitDate:this.nextVisitDate,
            numberOfVisits:this.numberOfVisits,
            visitCharges:this.visitCharges,
            appointmentId:this.recordId
        };
        saveConsultation({
            consultationData:consultationData, 
            medications:validMedications 
        })
        .then(() =>{
            this.dispatchEvent(new ShowToastEvent({
                title:'Success',
                message:'Consultation and Prescription saved successfully.',
                variant:'success'
            }));
            this.closeConsultationModal();
        })
        .catch(error =>{
            this.dispatchEvent(new ShowToastEvent({
                title:'Error',
                message:error.body ? error.body.message :'Error saving record',
                variant:'error'
            }));
        })
        .finally(() =>{
            this.isSaving=false;
        });
    }
}