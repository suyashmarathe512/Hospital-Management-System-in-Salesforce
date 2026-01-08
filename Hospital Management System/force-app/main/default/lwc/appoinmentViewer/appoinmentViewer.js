import{LightningElement,wire,track} from 'lwc';
import{CurrentPageReference}from 'lightning/navigation';
import{ShowToastEvent}from 'lightning/platformShowToastEvent';
import getAppointmentDetails from '@salesforce/apex/AppointmentViewerController.getAppointmentDetails';
import saveConsultation from '@salesforce/apex/AppointmentViewerController.saveConsultation';
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
    get todayDate(){return new Date().toISOString().split('T')[0]; }
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
            name:'',
            dosage:'',
            frequency:'',
            duration:''
        }];
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
            name:'',
            dosage:'',
            frequency:'',
            duration:''
        }];
    }
    removeMedication(event){
        const index=event.target.dataset.index;
        this.medications=this.medications.filter((_, i) => i != index);
    }
    handleMedicationChange(event){
        const{index, field }=event.target.dataset;
        const updatedMedications=[...this.medications];
        updatedMedications[index]={...updatedMedications[index], [field]:event.target.value };
        this.medications=updatedMedications;
    }
    handleSaveConsultation(){
        // Optimization:Filter out empty medication rows
        const validMedications=this.medications.filter(med => med.name && med.name.trim().length > 0);
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