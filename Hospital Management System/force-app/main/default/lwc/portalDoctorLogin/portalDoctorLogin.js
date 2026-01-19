import{LightningElement}from 'lwc';
import{NavigationMixin}from 'lightning/navigation';
import{ShowToastEvent}from 'lightning/platformShowToastEvent';
import verifyDoctorEmail from '@salesforce/apex/portalDoctorLoginController.verifyDoctorEmail';
import reportIssueToAdmin from '@salesforce/apex/portalDoctorLoginController.reportIssueToAdmin';
export default class PortalDoctorLogin extends NavigationMixin(LightningElement){
    email='';
    isContactModalOpen=false;
    issueName='';
    issueEmail='';
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
        this.issueEmail = this.email;
    }
    closeContactModal(){
        this.isContactModalOpen=false;
        this.issueName='';
        this.issueEmail='';
        this.issueDescription='';
    }
    handleIssueNameChange(event){
        this.issueName=event.target.value;
    }
    handleIssueEmailChange(event){
        this.issueEmail=event.target.value;
    }
    handleIssueChange(event){
        this.issueDescription=event.target.value;
    }
    submitIssue(){
        const inputs = [...this.template.querySelectorAll('.slds-modal__content lightning-input, .slds-modal__content lightning-textarea')];
        const allValid = inputs.reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (allValid){
            this.isLoading=true;
            reportIssueToAdmin({ 
                doctorName:this.issueName,
                doctorEmail:this.issueEmail,
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