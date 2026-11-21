let
    Source = Csv.Document(File.Contents(CleanFolder & "oct_airport_id_map.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
    Kept = Table.SelectColumns(Promoted, {"num", "iata"}),
    Typed = Table.TransformColumnTypes(Kept, {{"num", type text}, {"iata", type text}})
in
    Typed
