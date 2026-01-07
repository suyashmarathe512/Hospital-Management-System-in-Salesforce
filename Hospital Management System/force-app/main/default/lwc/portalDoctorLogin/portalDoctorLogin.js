import{LightningElement}from 'lwc';
import{NavigationMixin}from 'lightning/navigation';
import{ShowToastEvent}from 'lightning/platformShowToastEvent';
import verifyDoctorEmail from '@salesforce/apex/portalDoctorLoginController.verifyDoctorEmail';
import reportIssueToAdmin from '@salesforce/apex/portalDoctorLoginController.reportIssueToAdmin';
export default class PortalDoctorLogin extends NavigationMixin(LightningElement){
    email='';
    isContactModalOpen=false;
    issueDescription='';
    isLoading=false;
    handleEmailChange(event){
        this.email=event.target.value;
    }
    handleLogin(){
        const emailInput=this.template.querySelector('lightning-input');
        if (emailInput.reportValidity()){
            this.isLoading=true;
            verifyDoctorEmail({email:this.email})
                .then(result =>{
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title:'Success',
                            message:`Welcome,Dr. ${result.Name}`,
                            variant:'success'
                        })
                    );
                    sessionStorage.setItem('doctorEmail', this.email);
                    window.location.href = '/DoctorsHealthXi/dashboard';
                })
                .catch(error =>{
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title:'Login Failed',
                            message:error.body.message,
                            variant:'error'
                        })
                    );
                })
                .finally(() =>{
                    this.isLoading=false;
                });
        }
    }
    openContactModal(){
        this.isContactModalOpen=true;
    }
    closeContactModal(){
        this.isContactModalOpen=false;
        this.issueDescription='';
    }
    handleIssueChange(event){
        this.issueDescription=event.target.value;
    }
    submitIssue(){
        const textarea=this.template.querySelector('lightning-textarea');
        if (textarea.reportValidity()){
            this.isLoading=true;
            reportIssueToAdmin({ 
                doctorEmail:this.email,
                issueDescription:this.issueDescription 
            })
                .then(() =>{
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title:'Success',
                            message:'Your issue has been reported to the administrator.',
                            variant:'success'
                        })
                    );
                    this.closeContactModal();
                })
                .catch(error =>{
                    console.error('Error reporting issue:',error);
                })
                .finally(() =>{
                    this.isLoading=false;
                });
        }
    }
}