@IsTest
public class RequiredFieldsCache
{
    public static Map<Schema.SObjectField, Object> get(Schema.SObjectType sObjectType)
    {
        return objectTypeToFields.containsKey(sObjectType) ?
            objectTypeToFields.get(sObjectType) :
            new Map<Schema.SObjectField, Object>();
    }

    static Map<Schema.SObjectType, Map<Schema.SObjectField, Object>> objectTypeToFields =
        new Map<Schema.SObjectType, Map<Schema.SObjectField, Object>>
    {
        Lead.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Lead.State => 'CO',
            Lead.LastName => 'Coyote',
            Lead.Company => 'ACME, Inc.'
        },
        Group.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Group.Name => 'Some group'
        },
        Account.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Account.Name => 'Some account'
        },
        Opportunity.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Opportunity.StageName => 'Stage',
            Opportunity.Name => 'Some opportunity',
            Opportunity.CloseDate => Date.today().addMonths(1),
            Opportunity.AccountId => new SObjectFieldProviders.GenericParentProvider(Account.sObjectType)
        },
        User.sObjectType => new Map<Schema.SObjectField, Object>
        {
            User.IsActive => true,
            User.LastName => 'Doe',
            User.LocaleSidKey => 'en_US',
            User.LanguageLocaleKey => 'en_US',
            User.EmailEncodingKey => 'ISO-8859-1',
            User.Email => 'testxxx000' +'@test.com',
            User.TimeZoneSidKey => 'America/New_York',
            User.ProfileId => FieldProviderFactory.standardProfileProvider,
            User.Alias => new SObjectFieldProviders.UniqueFixedLengthStringProvider('abc', 7),
            User.CommunityNickname => new SObjectFieldProviders.UniqueStringProvider('johndoe'),
            User.Username => new SObjectFieldProviders.UniqueStringProvider('test_xyz=test@example.com')
        },
        Vehicle__c.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Vehicle__c.Listing_Region_ID__c => new SObjectFieldProviders.GenericParentProvider(Region__c.sObjectType)
        },
        Vehicle_Interest__c.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Vehicle_Interest__c.Vehicle_Id__c => new SObjectFieldProviders.GenericParentProvider(Vehicle__c.sObjectType),
            Vehicle_Interest__c.Buyer_Opportunity_ID__c => new SObjectFieldProviders.GenericParentProvider(Opportunity.SObjectType)
        },
        Region__c.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Region__c.Shift_Key__c => new SObjectFieldProviders.UniqueStringProvider('SHIFT')
        },
        Test_Drive__c.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Test_Drive__c.Test_Drive_By_ID__c => UserInfo.getUserId(),
            Test_Drive__c.Vehicle_Interest_ID__c => new SObjectFieldProviders.GenericParentProvider(Vehicle_Interest__c.SObjectType)
        },
        Vehicle_Order__c.sObjectType => new Map<Schema.SObjectField, Object>
        {
            Vehicle_Order__c.Buyer_Opportunity_ID__c => new SObjectFieldProviders.GenericParentProvider(Opportunity.SObjectType),
            Vehicle_Order__c.Vehicle_ID__c => new SObjectFieldProviders.GenericParentProvider(Vehicle__c.SObjectType)
        }
    };
}