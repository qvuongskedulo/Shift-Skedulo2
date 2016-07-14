@isTest
private class BluewolfFieldReferenceTest
{
    private static testMethod void testBuild_Schema()
    {
        final Schema.SObjectField FIELD = Lead.FirstName;

        Test.startTest();

            BluewolfFieldReference ref = BluewolfFieldReference.build( FIELD );

        Test.stopTest();

        System.assert( ref instanceof BluewolfFieldReference.SchemaBluewolfFieldReference,
            'When the field is a schema object it should build a schema reference' );
        System.assertEquals( FIELD, ((BluewolfFieldReference.SchemaBluewolfFieldReference)ref).field,
            'The field passed in should be the field reference' );
    }

    private static testMethod void testBuild_Simple()
    {
        final String FIELD = 'Some_Field__c';

        Test.startTest();

            BluewolfFieldReference ref = BluewolfFieldReference.build( FIELD );

        Test.stopTest();

        System.assert( ref instanceof BluewolfFieldReference.SimpleBluewolfFieldReference,
            'When the field has no period it should build a simple reference' );
        System.assertEquals( FIELD, ((BluewolfFieldReference.SimpleBluewolfFieldReference)ref).field,
            'The field passed in should be the field reference' );
    }

    private static testMethod void testBuild_Chained()
    {
        final String RELATIONSHIP = 'Parent_Object__c';
        final String FIELD = 'Some_Field__c';
        final String REFERENCE = RELATIONSHIP + '.' + FIELD;

        Test.startTest();

            BluewolfFieldReference ref = BluewolfFieldReference.build( REFERENCE );

        Test.stopTest();

        System.assert( ref instanceof BluewolfFieldReference.ChainedBluewolfFieldReference,
            'When the field has a period it should build a chained reference' );

        BluewolfFieldReference.ChainedBluewolfFieldReference parent = (BluewolfFieldReference.ChainedBluewolfFieldReference)ref;

        System.assertEquals( RELATIONSHIP, parent.field,
            'The relationship name should by the chained reference field' );

        System.assert( parent.next instanceof BluewolfFieldReference.SimpleBluewolfFieldReference,
            'The chained reference should be the rest of the string' );
        System.assertEquals( FIELD, ((BluewolfFieldReference.SimpleBluewolfFieldReference)parent.next).field,
            'The field passed in should be the field reference' );
    }

    private static testMethod void testGetFrom_Schema()
    {
        final String NAME = 'Snoopy';

        Lead snoopy = new Lead( FirstName = NAME );
        BluewolfFieldReference firstName = new BluewolfFieldReference.SchemaBluewolfFieldReference( Lead.FirstName );

        Test.startTest();

            Object retrieved = firstName.getFrom( snoopy );

        Test.stopTest();

        System.assertEquals( NAME, retrieved,
            'The value from the referenced field should be retrieved' );
    }

    private static testMethod void testGetFrom_Simple()
    {
        final String NAME = 'Snoopy';

        Lead snoopy = new Lead( FirstName = NAME );
        BluewolfFieldReference firstName = new BluewolfFieldReference.SimpleBluewolfFieldReference( 'FirstName' );

        Test.startTest();

            Object retrieved = firstName.getFrom( snoopy );

        Test.stopTest();

        System.assertEquals( NAME, retrieved,
            'The value from the referenced field should be retrieved' );
    }

    private static testMethod void testGetFrom_Chained()
    {
        final String COMPANY = 'Wayne Industries';

        Account wayneIndustries = new Account( Name = COMPANY );
        Contact batman = new Contact( FirstName = 'Bruce' );
        batman.putSObject( 'Account', wayneIndustries );

        BluewolfFieldReference child = new BluewolfFieldReference.SimpleBluewolfFieldReference( 'Name' );
        BluewolfFieldReference accountName = new BluewolfFieldReference.ChainedBluewolfFieldReference( 'Account', child );

        Test.startTest();

            Object retrieved = accountName.getFrom( batman );

        Test.stopTest();

        System.assertEquals( COMPANY, retrieved,
            'The value from the referenced field should be retrieved' );
    }

    private static testMethod void testGetFrom_Chained_Null()
    {
        Contact orphan = new Contact( FirstName = 'Oliver' );

        BluewolfFieldReference child = new BluewolfFieldReference.SimpleBluewolfFieldReference( 'Name' );
        BluewolfFieldReference accountName = new BluewolfFieldReference.ChainedBluewolfFieldReference( 'Account', child );

        Test.startTest();

            Object retrieved = accountName.getFrom( orphan );

        Test.stopTest();

        System.assertEquals( null, retrieved,
            'Null should be returned if any chained reference is null' );
    }

    private static testMethod void testToString_Schema()
    {
        BluewolfFieldReference firstName = new BluewolfFieldReference.SchemaBluewolfFieldReference( Lead.FirstName );

        Test.startTest();

            String field = firstName.toString();

        Test.stopTest();

        System.assertEquals( 'FirstName', field,
            'The field name should be returned' );
    }

    private static testMethod void testToString_Simple()
    {
        BluewolfFieldReference firstName = new BluewolfFieldReference.SimpleBluewolfFieldReference( 'FirstName' );

        Test.startTest();

            String field = firstName.toString();

        Test.stopTest();

        System.assertEquals( 'FirstName', field,
            'The field name should be returned' );
    }

    private static testMethod void testToString_Chained()
    {
        BluewolfFieldReference child = new BluewolfFieldReference.SimpleBluewolfFieldReference( 'Name' );
        BluewolfFieldReference accountName = new BluewolfFieldReference.ChainedBluewolfFieldReference( 'Account', child );

        Test.startTest();

            String field = accountName.toString();

        Test.stopTest();

        System.assertEquals( 'Account.Name', field,
            'The field name should be returned' );
    }
}