public with sharing class ShiftCxCarSearchController {

	public class SearchResult {
		public Map<String, List<Vehicle__c>> carsInStage { get; set; }
		public Map<String, Integer> carCountInStage { get; set; }

		public SearchResult(Map<String, List<Vehicle__c>> carsInStage) {
			this.carsInStage = carsInStage;
			carCountInStage = new Map<String, Integer>();
			for (String stage : carsInStage.keySet()) {
				carCountInStage.put(stage, carsInStage.get(stage).size());
			}
		}
	}

	// View state size limit is 135KB, so this can't be arbitrarily high.
	private static final Integer MAX_RESULTS_PER_STAGE = 99;

	public List<SelectOption> allStages { get; set; }
	public List<String> selectedStages { get; set; }
	public String searchQuery { get; set; }
	public SearchResult searchResult { get; set; }
	public String errorMessage { get; set; }

	private static List<String> stagesInCustomOrder() {
		List<String> out = new List<String>();
		// These stages are most important for CX, so show them first.
		out.add(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
		out.add(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE);
		for (String stage : ShiftConstants.SELLER_OPPORTUNITY_STAGES) {
			if (!new Set<String>(out).contains(stage)) { // inefficient, but N is small, and this runs infrequently
				out.add(stage);
			}
		}
		return out;
	}

	public ShiftCxCarSearchController() {
		searchQuery = '';
		allStages = new List<SelectOption>();
		for (String stage : stagesInCustomOrder()) {
			allStages.add(new SelectOption(stage, stage));
		}
		selectedStages = new List<String>();
		selectedStages.add(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE);
		selectedStages.add(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
		// initialize searchResult
		search();
	}

	public void search() {
		searchResult = doSearch(new Set<String>(selectedStages), searchQuery, MAX_RESULTS_PER_STAGE);
	}

	private static List<Vehicle__c> doSearchInStage(String stage, String searchQuery, Integer limt) {
		List<String> queryComponents = new List<String>();
		for (String token : searchQuery.split(' ')) {
			String queryComponent = '';
			if (ShiftUtil.isValidId(token)) {
				String tokenQ = ShiftUtil.soqlQuote(token);
				queryComponent +=
						'(Id = ' + tokenQ + ')'
						+ ' OR (Vehicle_Id__c = ' + tokenQ + ')'
						+ ' OR ';
			}
			String termQ = ShiftUtil.soqlQuote('%' + token + '%');
			queryComponent +=
					'(Name LIKE ' + termQ + ')'
					+ ' OR (Vehicle_Id__r.Body_Style__c LIKE ' + termQ + ')'
					+ ' OR (Vehicle_Id__r.VIN__c LIKE ' + termQ + ')'
					+ ' OR (Vehicle_Id__r.Driveshift_Listing_URL__c LIKE ' + termQ + ')'
					+ ' OR (Vehicle_Id__r.Base_Deal_ID__c LIKE ' + termQ + ')'
					+ ' OR (Vehicle_Id__r.Listing_Region_ID__r.Shift_Key__c LIKE ' + termQ + ')'
					+ ' OR (Vehicle_Id__r.Listing_Region_ID__r.Name LIKE ' + termQ + ')';
			queryComponents.add('(' + queryComponent + ')');
		}

		String dbQuery =
				'SELECT Id, Vehicle_Id__r.Name, Vehicle_Id__r.Exterior_Color__c, Vehicle_Id__r.Interior_Color__c, Vehicle_Id__r.Body_Style__c, Vehicle_Id__r.Mileage__c, Vehicle_Id__r.List_Price__c, Vehicle_Id__r.Coming_Soon__c, Vehicle_Id__r.Sale_Pending__c, Vehicle_Id__r.Listing_Region_Name__c'
				+ ' FROM Opportunity WHERE StageName = ' + ShiftUtil.soqlQuote(stage) + ' AND RecordType.DeveloperName = ' + ShiftUtil.soqlQuote(ShiftConstants.OPPORTUNITY_RECORD_TYPE_SELLER) + ' AND '
				+ '(' + String.join(queryComponents, ' AND ') + ')'
				+ ' ORDER BY Vehicle_Id__r.Coming_Soon__c ASC, Vehicle_Id__r.Listing_Region_Name__c DESC, Id ASC'
				+ ' LIMIT ' + limt;
		System.debug('searchInStage "' + stage + '": dbQuery: ' + dbQuery);
		List<Opportunity> results = Database.Query(dbQuery);
		List<Vehicle__c> out = new List<Vehicle__c>();
		for (Opportunity x : results) {
			out.add(x.Vehicle_Id__r);
		}
		return out;
	}

	public static SearchResult doSearch(Set<String> selectedStages, String searchQuery, Integer limt) {
		Map<String, List<Vehicle__c>> carsInStage = new Map<String, List<Vehicle__c>>();
		for (String stage : selectedStages) {
			carsInStage.put(stage, doSearchInStage(stage, searchQuery, limt));
		}
		return new SearchResult(carsInStage);
	}

}