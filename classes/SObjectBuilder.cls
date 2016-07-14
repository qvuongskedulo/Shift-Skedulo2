@IsTest
public class SObjectBuilder
{
    final Schema.SObjectType sObjectType;
    final Map<Schema.SObjectField, Object> fieldToValue;

    Integer recordCount;
    List<sObject> records;

    public SObjectBuilder(Schema.SObjectType sObjectType)
    {
        this.recordCount = 1;
        this.sObjectType = sObjectType;
        this.fieldToValue = new Map<Schema.SObjectField, Object>();
    }
    public SObjectBuilder count(Integer recordCount)
    {
        this.recordCount = recordCount;
        return this;
    }

    public SObjectBuilder put(Schema.SObjectField field, Object value)
    {
        this.fieldToValue.put(field, value);
        return this;
    }
    public SObjectBuilder putAll(Map<Schema.SObjectField, Object> fieldMap)
    {
        this.fieldToValue.putAll(fieldMap);
        return this;
    }

    public SObjectBuilder build()
    {
        records = SObjectFactory.build(recordCount, sObjectType, fieldToValue);
        return this;
    }

    public SObjectBuilder create()
    {
        records = SObjectFactory.create(recordCount, sObjectType, fieldToValue);
        return this;
    }

    public SObjectBuilder createAsAdmin()
    {
        system.runAs(SObjectFactory.ADMIN_USER)
        {
            this.create();
        }
        return this;
    }

    public sObject getRecord()
    {
        return (records == null || records.isEmpty()) ? null : records[0];
    }

    public List<sObject> getRecords()
    {
        return (records == null) ? new List<sObject>() : records;
    }
}