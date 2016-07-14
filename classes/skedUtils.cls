public class skedUtils {
    
    public static Date ConvertToDateValue(string dateString) {
        String[] temp = dateString.split('-');
        return Date.newInstance(Integer.valueOf(temp[0]), Integer.valueOf(temp[1]), Integer.valueOf(temp[2]));
    }
    
    public static integer ConvertBetweenTimezones(integer timeInMinutes, string fromTimezoneSidId, string toTimezoneSidId) {
        if (fromTimezoneSidId == toTimezoneSidId) {
            return timeInMinutes;
        }
        TimeZone fromTz = Timezone.getTimeZone(fromTimezoneSidId);
        Timezone toTz = Timezone.getTimeZone(toTimezoneSidId);
        integer offsetMinutes = toTz.getOffset(system.now()) - fromTz.getOffset(system.now());
        offsetMinutes = offsetMinutes / 60000;
        integer result = timeInMinutes + offsetMinutes;
        return result;
    }
    
    public static DateTime ConvertBetweenTimezones(DateTime input, string fromTimezoneSidId, string toTimezoneSidId) {
        if (fromTimezoneSidId == toTimezoneSidId) {
            return input;
        }
        TimeZone fromTz = Timezone.getTimeZone(fromTimezoneSidId);
        Timezone toTz = Timezone.getTimeZone(toTimezoneSidId);
        integer offsetMinutes = toTz.getOffset(input) - fromTz.getOffset(input);
        offsetMinutes = offsetMinutes / 60000;
        input = input.addMinutes(offsetMinutes);
        return input;
    }
    
    public static Map<string, Set<Date>> getHolidays() {
        Date currentDate = system.now().date().addDays(-1);//buffer for different timezone
        
        Map<string, Set<Date>> mapHolidays = new Map<string, Set<Date>>();
        List<sked__Holiday__c> skedGlobalHolidays = [SELECT Id, sked__Start_Date__c, sked__End_Date__c
                                                     FROM sked__Holiday__c
                                                     WHERE sked__Global__c = TRUE
                                                     AND sked__End_Date__c >= :currentDate];
        List<sked__Holiday_Region__c> skedRegionHolidays = [SELECT Id, sked__Holiday__r.sked__Start_Date__c, sked__Holiday__r.sked__End_Date__c, 
                                                            sked__Region__r.Name
                                                            FROM sked__Holiday_Region__c
                                                            WHERE sked__Holiday__r.sked__End_Date__c >= :currentDate];
        
        Set<Date> globalHolidays = new Set<Date>();
        for (sked__Holiday__c globalHoliday : skedGlobalHolidays) {
            Date tempDate = globalHoliday.sked__Start_Date__c;
            while (tempDate <= globalHoliday.sked__End_Date__c) {
                globalHolidays.add(tempDate);
                tempDate = tempDate.addDays(1);
            }
        }
        mapHolidays.put('global', globalHolidays);
        
        for (sked__Holiday_Region__c regionHoliday : skedRegionHolidays) {
            Set<Date> regionHolidays;
            if (mapHolidays.containsKey(regionHoliday.sked__Region__r.Id)) {
                regionHolidays = mapHolidays.get(regionHoliday.sked__Region__r.Id);
            } else {
                regionHolidays = new Set<Date>();
            }
            
            Date tempDate = regionHoliday.sked__Holiday__r.sked__Start_Date__c;
            while (tempDate <= regionHoliday.sked__Holiday__r.sked__End_Date__c) {
                regionHolidays.add(tempDate);
                tempDate = tempDate.addDays(1);
            }
            
            if (!mapHolidays.containsKey(regionHoliday.sked__Region__r.Id)) {
                mapHolidays.put(regionHoliday.sked__Region__r.Id, regionHolidays);
            }
        }
        return mapHolidays;
    }
}