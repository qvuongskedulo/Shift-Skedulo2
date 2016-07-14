@IsTest
public class BluewolfSObjectFieldProviders
{
    public static Integer counter = 0;
    public static Integer getUniqueCounter() { return counter++; }

    public abstract class ParentProvider implements BluewolfIFieldProvider
    {
        public Object getValue() { return getRecord().Id; }
        public abstract SObject getRecord();
    }
    public class SpecificParentProvider
        extends ParentProvider
        implements BluewolfIFieldProvider
    {
        public final String query;
        sObject record;

        public SpecificParentProvider(String query)
        {
            this.query = query;
        }
        public override SObject getRecord()
        {
            if (record == null)
                record = Database.query(query);
            return record;
        }
    }
    public class GenericParentProvider
        extends ParentProvider
        implements BluewolfIFieldProvider
    {
        public final Schema.SObjectType sObjectType;
        SObject record;

        public GenericParentProvider(Schema.SObjectType sObjectType)
        {
            this.sObjectType = sObjectType;
        }
        public override SObject getRecord()
        {
            if (record == null) record = BluewolfSObjectFactory.create(sObjectType);
            return record;
        }
    }

    public virtual class UniqueStringProvider implements BluewolfIFieldProvider
    {
        public final String base;

        public UniqueStringProvider(String base)
        {
            this.base = base;
        }
        public virtual Object getValue()
        {
            return base + String.valueOf(getUniqueCounter());
        }
    }
    public virtual class UniqueFixedLengthStringProvider
        implements BluewolfIFieldProvider
    {
        public final String base;
        public final Integer length;

        public UniqueFixedLengthStringProvider(String base, Integer length)
        {
            this.length = length;
            this.base = base;
        }
        public virtual Object getValue()
        {
            String uniqueCounter = String.valueOf(getUniqueCounter());
            String value = base + uniqueCounter;
            Integer delta = value.length() - this.length;
            if (delta < 0)
            {
                Integer gap = this.length - base.length();
                value = base + uniqueCounter.leftPad(gap).replace(' ', '0');
            }
            else
            {
                Integer overlap = this.length - uniqueCounter.length();
                value = base.substring(0, overlap) + uniqueCounter;
            }
            return value;
        }
    }
    public class DummyIdProvider
        extends UniqueFixedLengthStringProvider
        implements BluewolfIFieldProvider
    {
        public DummyIdProvider(Schema.SObjectType sObjectType)
        {
            this(sObjectType.getDescribe().getKeyPrefix(), 18);
        }
        public DummyIdProvider(Schema.SObjectType sObjectType, Integer length)
        {
            this(sObjectType.getDescribe().getKeyPrefix(), length);
        }
        public DummyIdProvider(String sObjectType, Integer length)
        {
            super(sObjectType, length);
        }
    }

    public virtual class ListProvider implements BluewolfIFieldProvider
    {
        public Integer index = 0;
        final List<Object> values;
        final Integer size;

        public ListProvider(List<Object> values)
        {
            this.values = values;
            this.size = values.size();
        }
        public Object getValue()
        {
            Object value = values[index];
            index = math.mod(++index, size);
            return value;
        }
    }
    public class MultiParentProvider
        extends ListProvider
        implements BluewolfIFieldProvider
    {
        public MultiParentProvider(Schema.SObjectType sObjectType, Integer count)
        {
            super(new List<Id>( BluewolfPluck.ids(BluewolfSObjectFactory.create(count, sObjectType)) ));
        }
    }
}