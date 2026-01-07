import{LightningElement,track,wire}from 'lwc';
import{CurrentPageReference}from 'lightning/navigation';
import getProfileData from '@salesforce/apex/PortalProfileController.getProfileData';
import{getRecord,getFieldValue}from 'lightning/uiRecordApi';
import SALUTATION_FIELD from '@salesforce/schema/Account.Salutation';
import FIRSTNAME_FIELD from '@salesforce/schema/Account.FirstName';
import LASTNAME_FIELD from '@salesforce/schema/Account.LastName';
import DOB_FIELD from '@salesforce/schema/Account.PersonBirthdate';
import AGE_FIELD from '@salesforce/schema/Account.Age__c';
import MOBILE_FIELD from '@salesforce/schema/Account.PersonMobilePhone';
import EMAIL_FIELD from '@salesforce/schema/Account.PersonEmail';
import PHONE_FIELD from '@salesforce/schema/Account.Phone';
import MAILING_STREET_FIELD from '@salesforce/schema/Account.PersonMailingStreet';
import MAILING_CITY_FIELD from '@salesforce/schema/Account.PersonMailingCity';
import MAILING_STATE_FIELD from '@salesforce/schema/Account.PersonMailingState';
import MAILING_POSTAL_CODE_FIELD from '@salesforce/schema/Account.PersonMailingPostalCode';
import MAILING_COUNTRY_FIELD from '@salesforce/schema/Account.PersonMailingCountry';
import OTHER_STREET_FIELD from '@salesforce/schema/Account.PersonOtherStreet';
import OTHER_CITY_FIELD from '@salesforce/schema/Account.PersonOtherCity';
import OTHER_STATE_FIELD from '@salesforce/schema/Account.PersonOtherState';
import OTHER_POSTAL_CODE_FIELD from '@salesforce/schema/Account.PersonOtherPostalCode';
import OTHER_COUNTRY_FIELD from '@salesforce/schema/Account.PersonOtherCountry';
const FIELDS=[
    SALUTATION_FIELD,FIRSTNAME_FIELD,LASTNAME_FIELD,DOB_FIELD,AGE_FIELD,MOBILE_FIELD,
    EMAIL_FIELD,PHONE_FIELD,MAILING_STREET_FIELD,MAILING_CITY_FIELD,
    MAILING_STATE_FIELD,MAILING_POSTAL_CODE_FIELD,MAILING_COUNTRY_FIELD,OTHER_STREET_FIELD,
    OTHER_CITY_FIELD,OTHER_STATE_FIELD,OTHER_POSTAL_CODE_FIELD,OTHER_COUNTRY_FIELD
];
export default class PortalProfile extends LightningElement{
    @track loading=true;
    @track error;
    @track caccount={};
    @track accountId;
    @track appointments=[];
    @track consultations=[];
    @track prescriptions=[];
    // Retrieve Account ID from URL parameters
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference){
        if(currentPageReference && currentPageReference.state.accountId){
            const urlId=currentPageReference.state.accountId;
            if(this.accountId !== urlId){
                this.accountId=urlId;
                this.fetchData(this.accountId,null);
            }
        }
    }
    connectedCallback(){
        const storedAccountId=window.sessionStorage.getItem('portalAccountId');
        const email=window.sessionStorage.getItem('portalEmail');
        // Fallback to session if URL ID is not present yet
        if(!this.accountId &&(storedAccountId||email)){
            this.accountId=storedAccountId;
            this.fetchData(storedAccountId,email);
        }
    }
    @wire(getRecord,{recordId:'$accountId',fields:FIELDS })
    wiredAccount({error,data }){
        if(data){
            this.caccount={
                ...this.caccount,
                Salutation:getFieldValue(data,SALUTATION_FIELD),
                FirstName:getFieldValue(data,FIRSTNAME_FIELD),
                LastName:getFieldValue(data,LASTNAME_FIELD),
                PersonBirthdate:getFieldValue(data,DOB_FIELD),
                PersonMobilePhone:getFieldValue(data,MOBILE_FIELD),
                Age__c:getFieldValue(data,AGE_FIELD),
                PersonEmail:getFieldValue(data,EMAIL_FIELD),
                Phone:getFieldValue(data,PHONE_FIELD),
                PersonMailingStreet:getFieldValue(data,MAILING_STREET_FIELD),
                PersonMailingCity:getFieldValue(data,MAILING_CITY_FIELD),
                PersonMailingState:getFieldValue(data,MAILING_STATE_FIELD),
                PersonMailingPostalCode:getFieldValue(data,MAILING_POSTAL_CODE_FIELD),
                PersonMailingCountry:getFieldValue(data,MAILING_COUNTRY_FIELD),
                PersonOtherStreet:getFieldValue(data,OTHER_STREET_FIELD),
                PersonOtherCity:getFieldValue(data,OTHER_CITY_FIELD),
                PersonOtherState:getFieldValue(data,OTHER_STATE_FIELD),
                PersonOtherPostalCode:getFieldValue(data,OTHER_POSTAL_CODE_FIELD),
                PersonOtherCountry:getFieldValue(data,OTHER_COUNTRY_FIELD)
            };
    }else if(error){
            console.error('Error loading account fields',error);
        }
    }
    async fetchData(accountId,email){
        this.loading=true;
        this.error=undefined;
        try{
            const data=await getProfileData({accountId,email });
            if(data){
                if(data.account){
                    this.caccount ={...data.account,...this.caccount };
                    if(!this.accountId) this.accountId=data.account.Id;
                }
                this.appointments=data.appointments||[];
                this.consultations=data.consultations||[];
                this.prescriptions=data.prescriptions||[];
            }
    }catch(e){
            this.error=e?.body?.message||'Error loading profile.';
    }finally{
            this.loading=false;
        }
    }
    get hasData(){
        return this.caccount &&(Object.keys(this.caccount).length > 0||this.accountId);
    }
    get accountName(){
        return this.caccount ? `${this.caccount.FirstName||''} ${this.caccount.LastName||''}` :'My Profile';
    }
}