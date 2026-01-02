import { LightningElement, track } from 'lwc';
import getProfileData from '@salesforce/apex/PortalProfileController.getProfileData';
export default class PortalProfile extends LightningElement {
    @track loading = true;
    @track error;
    @track account;
    @track appointments = [];
    @track consultations = [];
    @track prescriptions = [];
    connectedCallback() {
        try {
            const accountId = window.sessionStorage.getItem('portalAccountId');
            if (!accountId) {
                this.error = 'No account session found. Please login again.';
                this.loading = false;
                return;
            }
            this.fetchData(accountId);
        } catch (e) {
            this.error = 'Unable to read session. Please enable cookies/storage and try again.';
            this.loading = false;
        }
    }
    async fetchData(accountId) {
        this.loading = true;
        this.error = undefined;
        try {
            const data = await getProfileData({ accountId });
            console.log('Profile Data:', JSON.stringify(data)); 
            // CHECK CONSOLE: If fields are null here, update your Apex SOQL query to include:
            // Salutation, FirstName, LastName, PersonBirthdate, PersonMobilePhone, PersonEmail, Phone, Other_Phone__c, External_Record_Id__c
            // PersonMailingStreet, PersonMailingCity, PersonMailingState, PersonMailingPostalCode, PersonMailingCountry, PersonOtherStreet...
            
            this.account = data?.account;
            this.appointments = data?.appointments || [];
            this.consultations = data?.consultations || [];
            this.prescriptions = data?.prescriptions || [];
        } catch (e) {
            this.error = (e && e.body && e.body.message) ? e.body.message : 'Error loading profile.';
        } finally {
            this.loading = false;
        }
    }
    get hasData() {
        return !!this.account;
    }
    get accountName() {
        return this.account ? `${this.account.FirstName || ''} ${this.account.LastName || ''}` : 'My Profile';
    }
}