import{LightningElement,wire,track}from 'lwc';
import{NavigationMixin}from 'lightning/navigation';
import getTodayAppointments from '@salesforce/apex/DoctorDashboardController.getTodayAppointments';
const COLUMNS=[
{label:'Time',fieldName:'FormattedTime',type:'text',initialWidth:100 },
{label:'Patient Name',fieldName:'PatientName',type:'text',initialWidth:200,wrapText:true },
{label:'Reason for Visit',fieldName:'ReasonForVisit',type:'text',wrapText:true },
{label:'Status',fieldName:'AppointmentStatus',type:'text',initialWidth:120 },
{
        type:'button',
        typeAttributes:{
            label:'View',
            name:'view_details',
            variant:'base'
        },
        initialWidth:80
    }
];
export default class DoctorDashboard extends NavigationMixin(LightningElement){
    @track appointments=[];
    @track error;
    @track isLoading = true;
    columns=COLUMNS;
    // Retrieve the email stored during the custom login process
    doctorEmail=sessionStorage.getItem('doctorEmail');
    get errorMessage(){
        if(this.error){
            return(this.error.body&&this.error.body.message)?this.error.body.message :'Unable to load appointments.';
        }
        return '';
    }
    // Get today's date for the header
    get todayDate(){
        return new Date().toLocaleDateString(undefined,{
            weekday:'long',
            year:'numeric',
            month:'long',
            day:'numeric'
        });
    }
    @wire(getTodayAppointments,{email:'$doctorEmail'})
    wiredAppointments({error,data}){
        this.isLoading = false;
        if(data){
            this.appointments=data;
            this.error=undefined;
    }else if(error){
            this.error=error;
            this.appointments=[];
            console.error('Error loading appointments:',error);
        }
    }
    handleRowAction(event){
        const row=event.detail.row;
        window.location.href='/DoctorsHealthXi/appointmentviewer?recordId='+row.Id;
    }
}