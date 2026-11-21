let
    Dates = List.Dates(#date(2015, 1, 1), 365, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddMonthNo = Table.AddColumn(Typed, "Month No", each Date.Month([Date]), Int64.Type),
    AddMonth = Table.AddColumn(AddMonthNo, "Month", each Date.ToText([Date], "MMM", "en-US"), type text),
    AddMonthName = Table.AddColumn(AddMonth, "Month Name", each Date.ToText([Date], "MMMM", "en-US"), type text),
    AddQuarter = Table.AddColumn(AddMonthName, "Quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddWeekdayNo = Table.AddColumn(AddQuarter, "Weekday No", each Date.DayOfWeek([Date], Day.Monday) + 1, Int64.Type),
    AddWeekday = Table.AddColumn(AddWeekdayNo, "Weekday", each Date.ToText([Date], "ddd", "en-US"), type text),
    AddWeek = Table.AddColumn(AddWeekday, "Week", each Date.WeekOfYear([Date], Day.Monday), Int64.Type),
    AddDay = Table.AddColumn(AddWeek, "Day", each Date.Day([Date]), Int64.Type),
    AddWeekend = Table.AddColumn(AddDay, "Day Type", each if Date.DayOfWeek([Date], Day.Monday) >= 5 then "Weekend" else "Weekday", type text)
in
    AddWeekend
