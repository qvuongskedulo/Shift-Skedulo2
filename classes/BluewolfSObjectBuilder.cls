@IsTest
public class BluewolfSObjectBuilder
{
    final Schema.SObjectType sObjectType;
    final Map<Schema.SObjectField, Object> fieldToValue;

    Integer recordCount;
    List<sObject> records;

    public BluewolfSObjectBuilder(Schema.SObjectType sObjectType)
    {
        this.recordCount = 1;
        this.sObjectType = sObjectType;
        this.fieldToValue = new Map<Schema.SObjectField, Object>();
    }
    public BluewolfSObjectBuilder count(Integer recordCount)
    {
        this.recordCount = recordCount;
        return this;
    }

    public BluewolfSObjectBuilder put(Schema.SObjectField field, Object value)
    {
        this.fieldToValue.put(field, value);
        return this;
    }
    public BluewolfSObjectBuilder putAll(Map<Schema.SObjectField, Object> fieldMap)
    {
        this.fieldToValue.putAll(fieldMap);
        return this;
    }

    public BluewolfSObjectBuilder build()
    {
        records = BluewolfSObjectFactory.build(recordCount, sObjectType, fieldToValue);
        return this;
    }

    public BluewolfSObjectBuilder create()
    {
        records = BluewolfSObjectFactory.create(recordCount, sObjectType, fieldToValue);
        return this;
    }

    public BluewolfSObjectBuilder createAsAdmin()
    {
        system.runAs(BluewolfSObjectFactory.ADMIN_USER)
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