let
    Source = Csv.Document(File.Contents(RawFolder & "airports.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Renamed = Table.RenameColumns(Promoted, {{"IATA_CODE", "IATA Code"}, {"AIRPORT", "Airport"}, {"CITY", "City"}, {"STATE", "State"}, {"COUNTRY", "Country"}, {"LATITUDE", "Lat Raw"}, {"LONGITUDE", "Lon Raw"}}),
    // 3 airports have no coordinates in the source -> filled from FAA airport reference points
    Fix = [ECP = {30.3578, -85.7956}, PBG = {44.6509, -73.4681}, UST = {29.9593, -81.3397}],
    AddLat = Table.AddColumn(Renamed, "Latitude", each if [Lat Raw] = "" then Record.Field(Fix, [IATA Code]){0} else Number.From([Lat Raw], "en-US"), type number),
    AddLon = Table.AddColumn(AddLat, "Longitude", each if [Lon Raw] = "" then Record.Field(Fix, [IATA Code]){1} else Number.From([Lon Raw], "en-US"), type number),
    Removed = Table.RemoveColumns(AddLon, {"Lat Raw", "Lon Raw"}),
    AddLabel = Table.AddColumn(Removed, "Airport Label", each [IATA Code] & " - " & [City] & ", " & [State], type text),
    Typed = Table.TransformColumnTypes(AddLabel, {{"IATA Code", type text}, {"Airport", type text}, {"City", type text}, {"State", type text}, {"Country", type text}})
in
    Typed
