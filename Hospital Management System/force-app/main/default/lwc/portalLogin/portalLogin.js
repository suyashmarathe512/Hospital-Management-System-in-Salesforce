import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import authenticate from '@salesforce/apex/PortalAuthService.authenticate';
import createPersonAccount from '@salesforce/apex/PortalAuthService.createPersonAccount';

export default class PortalLogin extends NavigationMixin(LightningElement) {
    // UI state
    @track isCreateMode = false;
    @track isLoggingIn = false;
    @track isCreating = false;
    // Login form fields
    @track loginEmail = '';
    @track loginPassword = '';
    // Messages
    @track errorMessage = '';
    // Create form fields
    @track firstName = '';
    @track lastName = '';
    @track createEmail = '';
    @track createPassword = '';
    @track salutation = '';
    @track birthdate = '';
    @track mobile = '';
    @track phone = '';
    @track otherPhone = '';
    @track mailingStreet = '';
    @track mailingCity = '';
    @track mailingPostalCode = '';
    @track mailingState = '';
    @track mailingCountry = '';
    @track otherStreet = '';
    @track otherCity = '';
    @track otherPostalCode = '';
    @track otherState = '';
    @track otherCountry = '';
    // Create messages
    @track createMessage = '';
    @track createError = '';
    get salutationOptions() {
        return [
            { label: 'Mr.', value: 'Mr.' },
            { label: 'Ms.', value: 'Ms.' },
            { label: 'Mrs.', value: 'Mrs.' },
            { label: 'Dr.', value: 'Dr.' },
            { label: 'Prof.', value: 'Prof.' },
        ];
    }
    // Utility: validate inputs by data-id
    validateInputs(selectors = []) {
        let allValid = true;
        selectors.forEach((dataId) => {
            const input = this.template.querySelector(`[data-id="${dataId}"]`);
            if (input) {
                input.reportValidity();
                allValid = allValid && input.checkValidity();
            }
        });
        return allValid;
    }
    // Handlers: Login form
    handleLoginEmailChange = (e) => {
        this.loginEmail = e.target.value;
    };
    handleLoginPasswordChange = (e) => {
        this.loginPassword = e.target.value;
    };
    async handleLogin() {
        this.errorMessage = '';
        // Client-side validation first
        const ok = this.validateInputs(['loginEmail', 'loginPassword']);
        if (!ok) {
            this.errorMessage = 'Invalid email or password';
            return;
        }
        this.isLoggingIn = true;
        try {
            const result = await authenticate({ email: this.loginEmail, password: this.loginPassword });
            if (result && result.accountId) {
                // Store AccountId in sessionStorage
                try {
                    window.sessionStorage.setItem('portalAccountId', result.accountId);
                } catch (e) {
                    // ignore storage errors
                }
                window.location.href = '/Healthxi/portalprofile';
            } else {
                this.errorMessage = 'Invalid email or password';
            }
        } catch (e) {
            this.errorMessage = 'Invalid email or password';
        } finally {
            this.isLoggingIn = false;
        }
    }
    // Create flow
    openCreate = () => {
        this.isCreateMode = true;
        this.createMessage = '';
        this.createError = '';
    };
    closeCreate = () => {
        this.isCreateMode = false;
        this.createMessage = '';
        this.createError = '';
        // Reset create fields
        this.firstName = '';
        this.lastName = '';
        this.createEmail = '';
        this.createPassword = '';
        this.salutation = '';
        this.birthdate = '';
        this.mobile = '';
        this.phone = '';
        this.otherPhone = '';
        this.mailingStreet = '';
        this.mailingCity = '';
        this.mailingPostalCode = '';
        this.mailingState = '';
        this.mailingCountry = '';
        this.otherStreet = '';
        this.otherCity = '';
        this.otherPostalCode = '';
        this.otherState = '';
        this.otherCountry = '';
    };
    handleCreateChange = (e) => {
        const id = e.target.dataset.id;
        const val = e.target.value;
        const fieldMap = {
            'firstName': 'firstName',
            'lastName': 'lastName',
            'createEmail': 'createEmail',
            'createPassword': 'createPassword',
            'salutation': 'salutation',
            'birthdate': 'birthdate',
            'mobile': 'mobile',
            'phone': 'phone',
            'otherPhone': 'otherPhone',
            'mailingStreet': 'mailingStreet',
            'mailingCity': 'mailingCity',
            'mailingPostalCode': 'mailingPostalCode',
            'mailingState': 'mailingState',
            'mailingCountry': 'mailingCountry',
            'otherStreet': 'otherStreet',
            'otherCity': 'otherCity',
            'otherPostalCode': 'otherPostalCode',
            'otherState': 'otherState',
            'otherCountry': 'otherCountry'
        };
        if (fieldMap[id]) {
            this[fieldMap[id]] = val;
        }
        // live-validate the edited input
        const input = e.target;
        if (input && typeof input.reportValidity === 'function') {
            input.reportValidity();
        }
    };
    async handleCreateAccount() {
        this.createMessage = '';
        this.createError = '';
        // Sync values from DOM to ensure state is current (fixes autofill issues)
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox');
        inputs.forEach(input => {
            const id = input.dataset.id;
            if (id) {
                this[id] = input.value;
            }
        });
        // Also validate explicitly the two inputs to ensure browser validity runs
        const ok = this.validateInputs(['lastName', 'createEmail', 'createPassword']);
        if (!ok) {
            this.createError = 'Please check the required fields.';
            return;
        }
        this.isCreating = true;
        try {
            const requestPayload = {
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.createEmail,
                password: this.createPassword,
                salutation: this.salutation,
                birthdate: this.birthdate,
                mobile: this.mobile,
                phone: this.phone,
                otherPhone: this.otherPhone,
                mailingStreet: this.mailingStreet,
                mailingCity: this.mailingCity,
                mailingPostalCode: this.mailingPostalCode,
                mailingState: this.mailingState,
                mailingCountry: this.mailingCountry,
                otherStreet: this.otherStreet,
                otherCity: this.otherCity,
                otherPostalCode: this.otherPostalCode,
                otherState: this.otherState,
                otherCountry: this.otherCountry
            };
            console.log('Sending create request:', JSON.stringify(requestPayload));
            
            await createPersonAccount({ req: requestPayload });
            
            this.createMessage = 'Account created successfully. Please log in with your email and password.';
            // Return to login after short delay and refresh the page
            setTimeout(() => {
                // Reset all state and refresh
                this.closeCreate();
                // Force a page refresh per requirement
                try {
                    window.location.reload();
                } catch (e) {
                    // ignore
                }
            }, 1200);
        } catch (e) {
            console.error('Create error:', e);
            this.createError = (e && e.body && e.body.message) ? e.body.message : 'Failed to create account';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Registration Error',
                    message: this.createError,
                    variant: 'error'
                })
            );
        } finally {
            this.isCreating = false;
        }
    }
}
