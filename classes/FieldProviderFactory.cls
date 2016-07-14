@IsTest
public class FieldProviderFactory
{
    public static IFieldProvider standardProfileProvider
    {
        get
        {
            if (standardProfileProvider == null)
            {
                standardProfileProvider = new SObjectFieldProviders.SpecificParentProvider(
                    'SELECT Id FROM Profile WHERE Name = \'Standard User\' LIMIT 1'
                );
            }
            return standardProfileProvider;
        }
        set;
    }

    public static IFieldProvider provideList(List<Object> values)
    {
        return new SObjectFieldProviders.ListProvider(values);
    }
    public static IFieldProvider provideList(Set<Id> ids)
    {
        List<Id> values = new List<Id> ( ids );
        return new SObjectFieldProviders.ListProvider((List<Object>)values);
    }

    public static IFieldProvider provideUniqueString()
    {
        return provideUniqueString('');
    }
    public static IFieldProvider provideUniqueString(String base)
    {
        return new SObjectFieldProviders.UniqueStringProvider(base);
    }

    public static IFieldProvider provideGenericId(Schema.SObjectType sObjectType)
    {
        return new SObjectFieldProviders.GenericParentProvider(sObjectType);
    }
}