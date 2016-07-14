@isTest
public class skedUtils_Test {

    static testmethod void testskedUtils() {
        integer timeInMinutes = skedUtils.ConvertBetweenTimezones(600, 'America/New_York', 'America/Los_Angeles');
        DateTime dateTimeValue = skedUtils.ConvertBetweenTimezones(system.now(), 'America/New_York', 'America/Los_Angeles');
    }
    
}