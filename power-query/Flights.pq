let
    Source = Csv.Document(File.Contents(RawFolder & "flights.csv"), [Delimiter = ",", Columns = 31, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    // Rule 8: keep only the columns the report needs
    Kept = Table.SelectColumns(Promoted, {"YEAR", "MONTH", "DAY", "AIRLINE", "FLIGHT_NUMBER", "ORIGIN_AIRPORT", "DESTINATION_AIRPORT", "SCHEDULED_DEPARTURE", "DEPARTURE_DELAY", "TAXI_OUT", "SCHEDULED_TIME", "AIR_TIME", "DISTANCE", "TAXI_IN", "SCHEDULED_ARRIVAL", "ARRIVAL_DELAY", "DIVERTED", "CANCELLED", "CANCELLATION_REASON", "AIR_SYSTEM_DELAY", "SECURITY_DELAY", "AIRLINE_DELAY", "LATE_AIRCRAFT_DELAY", "WEATHER_DELAY"}),
    BlanksToNull = Table.ReplaceValue(Kept, "", null, Replacer.ReplaceValue, {"FLIGHT_NUMBER", "SCHEDULED_DEPARTURE", "DEPARTURE_DELAY", "TAXI_OUT", "SCHEDULED_TIME", "AIR_TIME", "DISTANCE", "TAXI_IN", "SCHEDULED_ARRIVAL", "ARRIVAL_DELAY", "DIVERTED", "CANCELLED", "AIR_SYSTEM_DELAY", "SECURITY_DELAY", "AIRLINE_DELAY", "LATE_AIRCRAFT_DELAY", "WEATHER_DELAY", "YEAR", "MONTH", "DAY", "CANCELLATION_REASON"}),
    Typed = Table.TransformColumnTypes(BlanksToNull, {{"FLIGHT_NUMBER", Int64.Type}, {"SCHEDULED_DEPARTURE", Int64.Type}, {"DEPARTURE_DELAY", Int64.Type}, {"TAXI_OUT", Int64.Type}, {"SCHEDULED_TIME", Int64.Type}, {"AIR_TIME", Int64.Type}, {"DISTANCE", Int64.Type}, {"TAXI_IN", Int64.Type}, {"SCHEDULED_ARRIVAL", Int64.Type}, {"ARRIVAL_DELAY", Int64.Type}, {"DIVERTED", Int64.Type}, {"CANCELLED", Int64.Type}, {"AIR_SYSTEM_DELAY", Int64.Type}, {"SECURITY_DELAY", Int64.Type}, {"AIRLINE_DELAY", Int64.Type}, {"LATE_AIRCRAFT_DELAY", Int64.Type}, {"WEATHER_DELAY", Int64.Type}, {"YEAR", Int64.Type}, {"MONTH", Int64.Type}, {"DAY", Int64.Type}, {"AIRLINE", type text}, {"ORIGIN_AIRPORT", type text}, {"DESTINATION_AIRPORT", type text}, {"CANCELLATION_REASON", type text}}),
    // Rule 1: October 2015 uses numeric BTS airport IDs -> IATA codes
    OctMap = Record.FromList(Oct_Airport_Map[iata], Oct_Airport_Map[num]),
    FixAirports = Table.TransformColumns(Typed, {{"ORIGIN_AIRPORT", each Record.FieldOrDefault(OctMap, _, _), type text}, {"DESTINATION_AIRPORT", each Record.FieldOrDefault(OctMap, _, _), type text}}),
    // Rule 2: one date column
    AddDate = Table.AddColumn(FixAirports, "Flight Date", each #date([YEAR], [MONTH], [DAY]), type date),
    // Rule 3: hhmm numbers -> time, hour, time band (2400 -> 00:00)
    AddDepTime = Table.AddColumn(AddDate, "Sched Dep Time", each #time(Number.Mod(Number.IntegerDivide([SCHEDULED_DEPARTURE], 100), 24), Number.Mod([SCHEDULED_DEPARTURE], 100), 0), type time),
    AddArrTime = Table.AddColumn(AddDepTime, "Sched Arr Time", each #time(Number.Mod(Number.IntegerDivide([SCHEDULED_ARRIVAL], 100), 24), Number.Mod([SCHEDULED_ARRIVAL], 100), 0), type time),
    AddHour = Table.AddColumn(AddArrTime, "Dep Hour", each Number.Mod(Number.IntegerDivide([SCHEDULED_DEPARTURE], 100), 24), Int64.Type),
    AddBand = Table.AddColumn(AddHour, "Dep Time Band", each
        if [Dep Hour] >= 5 and [Dep Hour] < 9 then "Early Morning (05-08)"
        else if [Dep Hour] >= 9 and [Dep Hour] < 12 then "Morning (09-11)"
        else if [Dep Hour] >= 12 and [Dep Hour] < 17 then "Afternoon (12-16)"
        else if [Dep Hour] >= 17 and [Dep Hour] < 21 then "Evening (17-20)"
        else "Night (21-04)", type text),
    AddBandOrder = Table.AddColumn(AddBand, "Dep Band Order", each
        if [Dep Hour] >= 5 and [Dep Hour] < 9 then 1 else if [Dep Hour] >= 9 and [Dep Hour] < 12 then 2
        else if [Dep Hour] >= 12 and [Dep Hour] < 17 then 3 else if [Dep Hour] >= 17 and [Dep Hour] < 21 then 4 else 5, Int64.Type),
    // Rule 4: flight status
    AddStatus = Table.AddColumn(AddBandOrder, "Flight Status", each
        if [CANCELLED] = 1 then "Cancelled" else if [DIVERTED] = 1 then "Diverted"
        else if [ARRIVAL_DELAY] >= 15 then "Delayed" else "On-time", type text),
    // Rule 5: cancellation reason labels
    AddReason = Table.AddColumn(AddStatus, "Cancellation Reason", each
        if [CANCELLATION_REASON] = "A" then "Airline" else if [CANCELLATION_REASON] = "B" then "Weather"
        else if [CANCELLATION_REASON] = "C" then "National Air System" else if [CANCELLATION_REASON] = "D" then "Security"
        else "Not cancelled", type text),
    // Rule 6: arrival delay bands (completed flights only)
    AddDelayBand = Table.AddColumn(AddReason, "Delay Band", each
        if [ARRIVAL_DELAY] = null then "No arrival" else if [ARRIVAL_DELAY] < 0 then "Early"
        else if [ARRIVAL_DELAY] < 15 then "0-14 min" else if [ARRIVAL_DELAY] < 60 then "15-59 min"
        else if [ARRIVAL_DELAY] < 180 then "60-179 min" else "180+ min", type text),
    AddDelayOrder = Table.AddColumn(AddDelayBand, "Delay Band Order", each
        if [ARRIVAL_DELAY] = null then 6 else if [ARRIVAL_DELAY] < 0 then 1 else if [ARRIVAL_DELAY] < 15 then 2
        else if [ARRIVAL_DELAY] < 60 then 3 else if [ARRIVAL_DELAY] < 180 then 4 else 5, Int64.Type),
    // Rule 9: route + distance band
    AddRoute = Table.AddColumn(AddDelayOrder, "Route", each [ORIGIN_AIRPORT] & "-" & [DESTINATION_AIRPORT], type text),
    AddDistBand = Table.AddColumn(AddRoute, "Distance Band", each
        if [DISTANCE] < 500 then "Short (<500 mi)" else if [DISTANCE] < 1500 then "Medium (500-1,499 mi)" else "Long (1,500+ mi)", type text),
    AddDistOrder = Table.AddColumn(AddDistBand, "Distance Band Order", each if [DISTANCE] < 500 then 1 else if [DISTANCE] < 1500 then 2 else 3, Int64.Type),
    Removed = Table.RemoveColumns(AddDistOrder, {"YEAR", "MONTH", "DAY", "SCHEDULED_DEPARTURE", "SCHEDULED_ARRIVAL", "CANCELLATION_REASON"}),
    Renamed = Table.RenameColumns(Removed, {{"AIRLINE", "Airline Code"}, {"FLIGHT_NUMBER", "Flight Number"}, {"ORIGIN_AIRPORT", "Origin"}, {"DESTINATION_AIRPORT", "Destination"}, {"DEPARTURE_DELAY", "Departure Delay"}, {"TAXI_OUT", "Taxi Out"}, {"SCHEDULED_TIME", "Scheduled Minutes"}, {"AIR_TIME", "Air Time"}, {"DISTANCE", "Distance"}, {"TAXI_IN", "Taxi In"}, {"ARRIVAL_DELAY", "Arrival Delay"}, {"DIVERTED", "Diverted"}, {"CANCELLED", "Cancelled"}, {"AIR_SYSTEM_DELAY", "Air System Delay"}, {"SECURITY_DELAY", "Security Delay"}, {"AIRLINE_DELAY", "Airline Delay"}, {"LATE_AIRCRAFT_DELAY", "Late Aircraft Delay"}, {"WEATHER_DELAY", "Weather Delay"}}),
    // Rule 10: final data types (set last)
    FinalTypes = Table.TransformColumnTypes(Renamed, {{"Airline Code", type text}, {"Origin", type text}, {"Destination", type text}, {"Flight Date", type date}, {"Sched Dep Time", type time}, {"Sched Arr Time", type time}, {"Arrival Delay", Int64.Type}, {"Departure Delay", Int64.Type}, {"Cancelled", Int64.Type}, {"Diverted", Int64.Type}})
in
    FinalTypes
