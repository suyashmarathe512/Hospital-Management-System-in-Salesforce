import{LightningElement,wire,track}from 'lwc';
import{CurrentPageReference}from 'lightning/navigation';
import{refreshApex}from '@salesforce/apex';
import{ShowToastEvent}from 'lightning/platformShowToastEvent';
import getAppointments from '@salesforce/apex/PortalAppointmentController.getAppointments';
import bookAppointment from '@salesforce/apex/PortalAppointmentController.bookAppointment';
const COLUMNS=[
{label:'Appointment ID',fieldName:'Name',sortable:true},
{label:'Type',fieldName:'Appointment_Type__c',sortable:true},
{label:'Date',fieldName:'Appointment_Date__c',type:'date',sortable:true},
{label:'Status',fieldName:'Appointment_Status__c',sortable:true},
{label:'Reason',fieldName:'Reason_for_Visit__c',sortable:true}
];
export default class PortalAppointment extends LightningElement{
    @track accountId;
    @track isModalOpen=false;
    @track appointmentDate;
    @track reason;
    @track appointmentType;
    @track sortedBy;
    @track sortedDirection='asc';
    columns=COLUMNS;
    wiredAppointmentsResult;
    appointments=[];
    appointmentTypeOptions=[
{label:'Follow-up',value:'Follow-up'},
{label:'Emergency',value:'Emergency'},
{label:'Routine Checkup',value:'Routine Checkup'}
    ];
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference){
        if (currentPageReference&&currentPageReference.state.accountId){
            this.accountId=currentPageReference.state.accountId;
    }
}
    connectedCallback(){
        const storedAccountId=window.sessionStorage.getItem('portalAccountId');
        if (!this.accountId&&storedAccountId){
            this.accountId=storedAccountId;
    }
}
    @wire(getAppointments,{accountId:'$accountId'})
    wiredAppointments(result){
        this.wiredAppointmentsResult=result;
        if (result.data){
            this.appointments=result.data.map(record=>({
                ...record,
                // Ensure the Type column binds even if backend omits the field
                Appointment_Type__c:record.Appointment_Type__c||'—'
        }));
}else if (result.error){
            console.error('Error loading appointments',result.error);
    }
}
    handleBookAppointment(){
        this.isModalOpen=true;
}
    closeModal(){
        this.isModalOpen=false;
        this.clearForm();
}
    handleChange(event){
        const field=event.target.dataset.id;
        if (field==='type') this.appointmentType=event.target.value;
        if (field==='date') this.appointmentDate=event.target.value;
        if (field==='reason') this.reason=event.target.value;
}
    saveAppointment(){
        if (!this.appointmentDate||!this.appointmentType){
            this.dispatchEvent(new ShowToastEvent({title:'Error',message:'Please select appointment type and date',variant:'error'}));
            return;
    }
        bookAppointment({
                accountId:this.accountId,
                appointmentDate:this.appointmentDate,
                reason:this.reason,
                appointmentType:this.appointmentType
        })
            .then(() =>{
                this.dispatchEvent(new ShowToastEvent({title:'Success',message:'Appointment Scheduled Successfully. You will receive an email shortly after 15 mins about confirmation of appointment.',variant:'success'}));
                this.closeModal();
                return refreshApex(this.wiredAppointmentsResult);
        })
            .catch(error=>this.dispatchEvent(new ShowToastEvent({title:'Error',message:error.body?.message||'Unknown error',variant:'error'})));
}
    clearForm(){this.appointmentDate=null;this.reason=null;this.appointmentType=null;}

    handleSort(event){
        this.sortedBy=event.detail.fieldName;
        this.sortedDirection=event.detail.sortDirection;
        this.sortData(this.sortedBy,this.sortedDirection);
}
    sortData(fieldname,direction){
        let parseData=JSON.parse(JSON.stringify(this.appointments));
        let keyValue=(a) =>{return a[fieldname];};
        let isReverse=direction==='asc'?1 :-1;
        parseData.sort((x,y) =>{
            x=keyValue(x)?keyValue(x) :'';
            y=keyValue(y)?keyValue(y) :'';
            return isReverse * ((x > y) - (y > x));
    });
        this.appointments=parseData;
}
}
