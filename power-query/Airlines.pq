let
    Source = Csv.Document(File.Contents(RawFolder & "airlines.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Renamed = Table.RenameColumns(Promoted, {{"IATA_CODE", "Airline Code"}, {"AIRLINE", "Airline Full Name"}}),
    Short = Table.AddColumn(Renamed, "Airline", each Record.FieldOrDefault([UA = "United", AA = "American", US = "US Airways", F9 = "Frontier", B6 = "JetBlue", OO = "SkyWest", AS = "Alaska", NK = "Spirit", WN = "Southwest", DL = "Delta", EV = "Atlantic Southeast", HA = "Hawaiian", MQ = "American Eagle", VX = "Virgin America"], [Airline Code], [Airline Full Name]), type text),
    Typed = Table.TransformColumnTypes(Short, {{"Airline Code", type text}, {"Airline Full Name", type text}})
in
    Typed
