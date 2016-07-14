@IsTest
public class BluewolfSObjectFactory
{
    public static User ADMIN_USER
    {
        get
        {
            if (ADMIN_USER == null)
            {
                ADMIN_USER = [
                    SELECT Id FROM User
                    WHERE Profile.Name = 'System Administrator'
                    AND IsActive = true
                    LIMIT 1
                ];
            }
            return ADMIN_USER;
        }
        private set;
    }

    public static sObject create(Schema.SObjectType objectType) { return create(1, objectType)[0]; }
    public static sObject build(Schema.SObjectType objectType) { return build(1, objectType)[0]; }

    public static List<sObject> create(Integer recordCount, Schema.SObjectType objectType)
    {
        return create(recordCount, objectType, null);
    }
    public static List<sObject> build(Integer recordCount, Schema.SObjectType objectType)
    {
        return build(recordCount, objectType, null);
    }

    public static sObject create(Schema.SObjectType objectType, Schema.SObjectField field, Object value)
    {
        return create(objectType, new Map<Schema.SObjectField, Object> { field => value });
    }
    public static sObject build(Schema.SObjectType objectType, Schema.SObjectField field, Object value)
    {
        return build(objectType, new Map<Schema.SObjectField, Object> { field => value });
    }

    public static sObject create(Schema.SObjectType objectType, Map<Schema.SObjectField, Object> fieldToValue)
    {
        return create(1, objectType, fieldToValue)[0];
    }
    public static sObject build(Schema.SObjectType objectType, Map<Schema.SObjectField, Object> fieldToValue)
    {
        return build(1, objectType, fieldToValue)[0];
    }

    public static List<sObject> create(Integer recordCount, Schema.SObjectType objectType, Schema.SObjectField field, Object value)
    {
        return create(recordCount, objectType, new Map<Schema.SObjectField, Object> { field => value });
    }
    public static List<sObject> build(Integer recordCount, Schema.SObjectType objectType, Schema.SObjectField field, Object value)
    {
        return build(recordCount, objectType, new Map<Schema.SObjectField, Object> { field => value });
    }

    public static List<sObject> create(Integer recordCount, Schema.SObjectType objectType, Map<Schema.SObjectField, Object> fieldToValue)
    {
        List<sObject> records = build(recordCount, objectType, fieldToValue);
        insert records;
        return records;
    }
    public static List<sObject> build(Integer recordCount, Schema.SObjectType objectType, Map<Schema.SObjectField, Object> fieldToValue)
    {
        Map<Schema.SObjectField, Object> fieldMap = BluewolfRequiredFieldsCache.get(objectType);
        if (fieldToValue != null) fieldMap.putAll(fieldToValue);

        List<sObject> records = new List<sObject>();
        for (Integer i = 0; i < recordCount; i++)
        {
            sObject record = objectType.newSObject();
            setSObjectFields(record, fieldMap);
            records.add(record);
        }
        return records;
    }

    /********** FIELD PROVIDERS **********/

    public static BluewolfIFieldProvider provideStandardProfile()
    {
        return provideParent(
            'SELECT Id FROM Profile WHERE Name = \'Standard User\' LIMIT 1'
        );
    }

    public static BluewolfIFieldProvider provideList(List<Object> values)
    {
        return new BluewolfSObjectFieldProviders.ListProvider(values);
    }

    public static BluewolfIFieldProvider provideUniqueString()
    {
        return provideUniqueString('');
    }
    public static BluewolfIFieldProvider provideUniqueString(String base)
    {
        return new BluewolfSObjectFieldProviders.UniqueStringProvider(base);
    }
    public static BluewolfIFieldProvider provideDummyId(Schema.SObjectType sObjectType)
    {
        return new BluewolfSObjectFieldProviders.DummyIdProvider(sObjectType);
    }

    public static BluewolfIFieldProvider provideParent(Schema.SObjectType sObjectType)
    {
        return new BluewolfSObjectFieldProviders.GenericParentProvider(sObjectType);
    }

    public static BluewolfIFieldProvider provideParent(String query)
    {
        return new BluewolfSObjectFieldProviders.SpecificParentProvider(query);
    }

    public static BluewolfIFieldProvider provideParents(List<SObject> records)
    {
        List<Id> values = new List<Id> ( BluewolfPluck.ids(records) );
        return new BluewolfSObjectFieldProviders.ListProvider((List<Object>)values);
    }
    public static BluewolfIFieldProvider provideParents(Schema.SObjectType sObjectType, Integer count)
    {
        return new BluewolfSObjectFieldProviders.MultiParentProvider(sObjectType, count);
    }

    /********** FIELD PROVIDERS **********/

    private static void setSObjectFields(sObject record, Map<Schema.SObjectField, Object> fieldMap)
    {
        for (Schema.SObjectField field : fieldMap.keySet())
        {
            Object value = fieldMap.get(field);
            if (value != null && value instanceof BluewolfIFieldProvider) value = ((BluewolfIFieldProvider)value).getValue();
            record.put(field, value);
        }
    }
}