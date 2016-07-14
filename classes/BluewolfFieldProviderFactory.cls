@IsTest
public class BluewolfFieldProviderFactory
{
    public static BluewolfIFieldProvider standardProfileProvider
    {
        get
        {
            if (standardProfileProvider == null)
            {
                standardProfileProvider = new BluewolfSObjectFieldProviders.SpecificParentProvider(
                   'SELECT Id FROM Profile WHERE Name = \'Standard User\' LIMIT 1'
                );
            }
            return standardProfileProvider;
        }
        set;
    }

    public static BluewolfIFieldProvider provideList(List<Object> values)
    {
        return new BluewolfSObjectFieldProviders.ListProvider(values);
    }
    public static BluewolfIFieldProvider provideList(Set<Id> ids)
    {
        List<Id> values = new List<Id> ( ids );
        return new BluewolfSObjectFieldProviders.ListProvider((List<Object>)values);
    }

    public static BluewolfIFieldProvider provideUniqueString()
    {
        return provideUniqueString('');
    }
    public static BluewolfIFieldProvider provideUniqueString(String base)
    {
        return new BluewolfSObjectFieldProviders.UniqueStringProvider(base);
    }

    public static BluewolfIFieldProvider provideGenericId(Schema.SObjectType sObjectType)
    {
        return new BluewolfSObjectFieldProviders.GenericParentProvider(sObjectType);
    }
}