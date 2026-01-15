public without sharing class InvoicePDFController{
    public BillWrapper bill{get;set;}
    public String errorMessage{get;set;}
    public void loadData(){ 
        String prescriptionId=ApexPages.currentPage().getParameters().get('id');
        if(String.isBlank(prescriptionId)){
            errorMessage='No Prescription ID provided.';    
            return;
        }
        String externalId;
        try{
            Prescription__c pres=[SELECT
                                        Prescription_External_ID__c
                                FROM
                                    Prescription__c
                                WHERE
                                    Id=:prescriptionId LIMIT 1];
            externalId=pres.Prescription_External_ID__c;
            if(String.isBlank(externalId)){
                errorMessage='External ID is missing on the Prescription record.';
                return;
            }
        }catch(Exception e){
            errorMessage='Prescription record not found.';
            
            return;
        }
        try{
            HttpRequest req=new HttpRequest();
            // Ensure 'HealthSystemServer' is configured in Named Credentials
            req.setEndpoint('callout:Hospital_Server/services/apexrest/Bill/'+externalId);
            req.setMethod('GET');
            Http http=new Http();
            HttpResponse res=http.send(req);
            if(res.getStatusCode()==200){
                Map<String,Object> result=(Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                bill=new BillWrapper(result);
            }else{
                errorMessage='Failed to retrieve Bill data: '+res.getStatus();
            }
        }catch(Exception e){
            errorMessage='Error: '+e.getMessage();
            
        }
    }
    public class BillWrapper{
        public String Name{get;set;}
        public String BillingDate{get;set;}
        public Decimal SubTotal{get;set;}
        public Decimal TaxPercentage{get;set;}
        public Decimal TotalAmount{get;set;}
        public String PatientName{get;set;}
        public String DoctorName{get;set;}
        public String PrescriptionName{get;set;}
        public List<LineItemWrapper> items{get;set;}
        public BillWrapper(Map<String,Object> data){
            this.Name=(String)data.get('Name');
            this.BillingDate=(String)data.get('Billing_Date__c');
            this.SubTotal=(Decimal)data.get('Sub_Total__c');
            this.TaxPercentage=(Decimal)data.get('Tax_Percentage__c');
            this.TotalAmount=(Decimal)data.get('Total_Amount__c');
            Map<String,Object> patient=(Map<String,Object>)data.get('Patient__r');
            if(patient!=null)this.PatientName=(String)patient.get('Name');
            Map<String,Object> consultation=(Map<String,Object>)data.get('Consultation__r');
            if(consultation!=null){
                Map<String,Object> doctor=(Map<String,Object>)consultation.get('Doctor__r');
                if(doctor!=null)this.DoctorName=(String)doctor.get('Name');
            }
            Map<String,Object> prescription=(Map<String,Object>)data.get('Prescription__r');
            if(prescription!=null)this.PrescriptionName=(String)prescription.get('Name');
            this.items=new List<LineItemWrapper>();
            Map<String,Object> lineItemsMap=(Map<String,Object>)data.get('Bill_Line_Items__r');
            if(lineItemsMap!=null && lineItemsMap.containsKey('records')){
                List<Object> lines=(List<Object>)lineItemsMap.get('records');
                for(Object line:lines){
                    this.items.add(new LineItemWrapper((Map<String,Object>)line));
                }
            }
        }
    }
    public class LineItemWrapper{
        public String MedicationName{get;set;}
        public Decimal UnitPrice{get;set;}
        public Decimal Quantity{get;set;}
        public Decimal LineTotal{get;set;}
        public LineItemWrapper(Map<String,Object> data){
            this.UnitPrice=(Decimal)data.get('Unit_Price__c');
            this.Quantity=(Decimal)data.get('Quantity__c');
            this.LineTotal=(Decimal)data.get('Line_Total__c');
            Map<String,Object> med=(Map<String,Object>)data.get('Medication__r');
            if(med!=null)this.MedicationName=(String)med.get('Name');
        }
    }
}