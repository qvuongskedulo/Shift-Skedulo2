public with sharing class ShiftVehicleDetailController {
	static final Integer TRUNCATE_AFTER_MAX_LINES = 30;
	
	public Vehicle__c vehicle { get; private set; }

	public Opportunity sellerOpportunity { get { return vehicle.Seller_Opportunity_ID__r; } }

	private List<Vehicle_Order__c> vehicleOrders;

	public List<OpportunityNoteDisplay> opportunityNoteDisplays { get; private set; }

	public Boolean hasOpportunityNotes { get { return !opportunityNoteDisplays.isEmpty(); } }

	public List<Attachment> attachments { get; private set; }

	public Boolean hasAttachments { get { return !attachments.isEmpty(); } }

	public Integer vehicleOrdersSize { get { return vehicleOrders.size(); } }

	public Vehicle_Order__c vehicleOrder { 
		get { return vehicleOrders.isEmpty() ? null : vehicleOrders.get(0); } 
	}

	public Contact sellerContact { get; private set; }

	public List<String> inspectionUrls { get; private set; }

	public Boolean hasInspections { get { return !inspectionUrls.isEmpty(); } }

	private void setupVehicleDetails() {
		Id vehicleId = ApexPages.currentPage().getParameters().get('id');
		vehicle = [
			SELECT 
				Id, 
				Seller_Opportunity_ID__c, 
				Seller_Opportunity_ID__r.AccountId,
				Seller_Opportunity_ID__r.Base_Deal_ID__c
			FROM Vehicle__c 
			WHERE Id = :vehicleId
		];
	}

	private void setupSellerDetails() {
		sellerContact = [
			SELECT Id 
			FROM Contact 
			WHERE AccountId = :vehicle.Seller_Opportunity_ID__r.AccountId
		];

		attachments = [
			SELECT Id, Name, ContentType, LastModifiedDate, CreatedById
			FROM Attachment 
			WHERE ParentId = :vehicle.Seller_Opportunity_ID__c
		];
		
		opportunityNoteDisplays = new List<OpportunityNoteDisplay>();
		for (Opportunity_Note__c note : [
				SELECT Id, Content__c, CreatedById, CreatedDate, Call_Outcome__c
				FROM Opportunity_Note__c
				WHERE Opportunity_Id__c = :vehicle.Seller_Opportunity_ID__c
			]) {
			opportunityNoteDisplays.add(new OpportunityNoteDisplay(note));
		}
	}

	private void setupVehicleOrders() {
		// Per the current spec, we only intend to show the full detail of the (at most one)
		// completed order. But our current system doesn't enforce the "at most one" requirement
		// yet, so we entertain the fact that we could have more and handle that on the page
		vehicleOrders = [
			SELECT Id 
			FROM Vehicle_Order__c 
			WHERE 
				Vehicle_ID__c = :vehicle.Id AND 
				Vehicle_Purchased__c = TRUE AND
				Vehicle_Returned__c = FALSE
		];
		if (vehicleOrders.size() <= 1) {
			return;
		}
		ApexPages.addMessage(new ApexPages.Message(
			ApexPages.Severity.WARNING, 
			'Vehicle is associated with ' + vehicleOrders.size() + ' completed orders'
		));
	}

	void setupInspectionUrls() {
		List<Inspection__c> inspections = [
				SELECT Id
				FROM Inspection__c
				WHERE
					Vehicle_ID__C = :vehicle.Id OR
					Forcebase_Deal_ID__c IN (:vehicle.Seller_Opportunity_ID__c, :vehicle.Seller_Opportunity_ID__r.Base_Deal_ID__c)
		];
		inspectionUrls = new List<String>();
		for (Inspection__c inspection : inspections) {
			inspectionUrls.add(ShiftProcessingPipeline.getInspectionUrl(inspection.Id, false));
		}
	}

	public ShiftVehicleDetailController() {
		setupVehicleDetails();
		setupSellerDetails();
		setupVehicleOrders();
		setupInspectionUrls();
	}

	public class OpportunityNoteDisplay {				
		Opportunity_Note__c source;
		String truncated;
		String full;

		public OpportunityNoteDisplay(Opportunity_Note__c note) {
			this.source = note;
			this.truncated = truncateLines(note.Content__c, TRUNCATE_AFTER_MAX_LINES);
			this.full = truncateLines(note.Content__c, -1);
			hasToggle = this.truncated !=null && this.full != null && !this.truncated.equals(this.full);		
		}

		public Opportunity_Note__c note { get { return source; } }

		public String truncatedContent { get { return truncated; } }

		public String fullContent { get { return full; } }

		public Boolean hasToggle { get; private set; }

		//public Boolean getHasToggle() { return false; }

		private String truncateLines(String value, Integer maxLines) {
			if (value == null) {
				return null;
			}
			List<String> lines = new List<String>();
			for (String line : value.split('\\r?\\n')) {
				if (maxLines >= 0 && lines.size() >= maxLines) {
					break;
				}
				lines.add(line.escapeHtml4());
			}
			return String.join(lines, '<br/>');
		}
	}
}