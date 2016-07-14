public with sharing class ShiftCaseControllerExtension {

    final Case caseRecord;
    
    public ShiftCaseControllerExtension(ApexPages.StandardController stdController) {
        this.caseRecord = (Case) stdController.getRecord();
    }

    public PageReference closeAndRedirect() {
    	this.caseRecord.Status = 'Closed';

    	update this.caseRecord;

    	PageReference casePage = new ApexPages.StandardController(this.caseRecord).view();
    	casePage.setRedirect(true);

    	return casePage;
    }
}