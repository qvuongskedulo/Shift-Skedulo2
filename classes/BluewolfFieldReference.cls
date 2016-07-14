global abstract class BluewolfFieldReference
{
    // BluewolfFieldReference interface

    global abstract Object getFrom( sObject record );

    // factory methods

    global static BluewolfFieldReference build( Schema.SObjectField field )
    {
        return new SchemaBluewolfFieldReference( field );
    }

    global static BluewolfFieldReference build( String field )
    {
        Integer index = field.indexOf('.');

        if ( index == -1 )
        {
            return new SimpleBluewolfFieldReference( field );
        }

        return new ChainedBluewolfFieldReference( field.substring( 0, index ), build( field.substring( index + 1 ) ) );
    }

    // concrete implementations

    global virtual class SchemaBluewolfFieldReference extends BluewolfFieldReference
    {
        @TestVisible Schema.SObjectField field;

        global SchemaBluewolfFieldReference( Schema.SObjectField field )
        {
            this.field = field;
        }

        global override Object getFrom( sObject record )
        {
            return record.get( field );
        }

        global override String toString()
        {
            return '' + field;
        }
    }

    global virtual class SimpleBluewolfFieldReference extends BluewolfFieldReference
    {
        @TestVisible String field;

        global SimpleBluewolfFieldReference( String field )
        {
            this.field = field;
        }

        global override Object getFrom( sObject record )
        {
            return record.get( field );
        }

        global override String toString()
        {
            return field;
        }
    }

    global virtual class ChainedBluewolfFieldReference extends BluewolfFieldReference
    {
        @TestVisible String field;
        @TestVisible BluewolfFieldReference next;

        global ChainedBluewolfFieldReference( String field, BluewolfFieldReference next )
        {
            this.field = field;
            this.next = next;
        }

        global override Object getFrom( sObject record )
        {
            sObject parent = record.getSObject( field );

            return parent == null ? null : next.getFrom( parent );
        }

        global override String toString()
        {
            return field + '.' + next.toString();
        }
    }
}