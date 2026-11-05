let
    // Step 1: Define metadata for each parameter describing its purpose and usage
    metaDocumentation = type function (
        data as (type table meta [
            Documentation.FieldCaption = "Data table",
            Documentation.FieldDescription = "Table with one row per line of text, where groups of lines are separated by a marker row.",
            Documentation.SampleValues = {"#table({""Line""}, {{""^""}, {""Name: Bob""}, {""Age: 30""}})"},
            Formatting.IsMultiLine = false,
            Formatting.IsCode = false
        ]),
        txGroupFn as (type function meta [
            Documentation.FieldCaption = "Group marker function",
            Documentation.FieldDescription = "Function that receives a line value and returns true when the row marks the start of a new group. Marker rows are removed from the result.",
            Documentation.SampleValues = {"each Text.StartsWith(_, ""^"")"},
            Formatting.IsMultiLine = false,
            Formatting.IsCode = true
        ]),
        optional txGroupColumn as (type nullable text meta [
            Documentation.FieldCaption = "Group column name",
            Documentation.FieldDescription = "Name of the column that holds the group ID. Defaults to ""TxGroup"".",
            Documentation.SampleValues = {"TxGroup"},
            Formatting.IsMultiLine = false,
            Formatting.IsCode = false
        ]),
        optional lineColumn as (type nullable text meta [
            Documentation.FieldCaption = "Line column name",
            Documentation.FieldDescription = "Name of the column in the source table that holds the line text. Defaults to ""Line"".",
            Documentation.SampleValues = {"Line"},
            Formatting.IsMultiLine = false,
            Formatting.IsCode = false
        ])
    ) as table
    // Step 2: Define global metadata in detail
    meta [

        Documentation.Name = "FromRows",
        Documentation.Author = "DataMistry",
        Documentation.InspiredBy = "",
        Documentation.LongDescription =
        "
                <p><b>  Table.FromRows (grouped lines to columns)  </b></p>

                <li>------------------------------------------------------</li>

                <li><b>  Creator: </b> DataMistry  </li>
                <li><b>  Web: </b> https://datamistry.au  </li>

                <li>------------------------------------------------------</li>

                <p><b>  Function Description:  </b></br>
                Converts a single-column table of text lines into a wide table. Rows for which the
                group marker function returns true start a new group and are removed. All other rows
                are numbered within their group (L-1, L-2, ...) and pivoted so each group becomes one row.

                <p><b>  Parameters Description:  </b></br>
                <ul>
                    <li><b>  • data:  </b>  Source table containing the lines. <code> (eg: Source ) </code> </li>
                    <li><b>  • txGroupFn:  </b>  Function returning true for group marker lines. <code> (eg: each Text.StartsWith(_, ""^"") ) </code> </li>
                    <li><b>  • txGroupColumn:  </b>  Optional. Name of the group ID column. Default ""TxGroup"". <code> (eg: ""TxGroup"") </code> </li>
                    <li><b>  • lineColumn:  </b>  Optional. Name of the line column in data. Default ""Line"". <code> (eg: ""Line"") </code> </li>
                </ul>

                <b>  Returns:  </b></br>
                A table with one row per group, a group ID column and one column per line position (L-1, L-2, ...).

                <p><b>  Formula Bar (fx) Output:  </b></br>
                <code>  FromRows( Source, each Text.StartsWith(_, ""^""), ""TxGroup"", ""Line"" )  </code>

            ",
        Documentation.Examples = {
            [
                Description = " Group lines separated by a ""^"" marker row into one row per group. ",
                Code = "FromRows(#table({""Line""}, {{""^""}, {""Bob""}, {""30""}, {""^""}, {""Amy""}, {""25""}}), each _ = ""^"")",
                Result = "#table({""TxGroup"", ""L-1"", ""L-2""}, {{0, ""Bob"", ""30""}, {3, ""Amy"", ""25""}})"
            ]
        }
    ],

    // Define the main function and parameters
    myFunction = (
        data as table,
        txGroupFn as function,
        optional txGroupColumn as nullable text,
        optional lineColumn as nullable text
    ) as table =>

    // _______________________________ \\
    let
        groupCol = txGroupColumn ?? "TxGroup",
        lineCol = lineColumn ?? "Line",

        // Add an Index column to create unique IDs for grouping transactions
        AddIndex = Table.AddIndexColumn(data, "Index", 0, 1, Int64.Type),

        // Mark each group identifier row with its index
        GroupMarker = Table.AddColumn(AddIndex, groupCol, each
            if txGroupFn(Record.Field(_, lineCol)) then [Index] else null
        ),
        // FillDown group column to fill up null values
        GroupMarker2 = Table.FillDown(GroupMarker, {groupCol}),
        // Replace null with 0
        #"Replaced Value" = Table.ReplaceValue(GroupMarker2, null, 0, Replacer.ReplaceValue, {groupCol}),
        // Remove Group Identifier rows
        #"Filtered Rows" = Table.SelectRows(#"Replaced Value", (currentRow) => not txGroupFn(Record.Field(currentRow, lineCol))),
        // Add InGroup Index
        #"Added Custom" = Table.AddColumn(#"Filtered Rows", "InGroupIndex", each "L-" & Number.ToText([Index] - Int64.From(Record.Field(_, groupCol)))),
        #"Removed Columns" = Table.RemoveColumns(#"Added Custom", {"Index"}),
        #"Pivoted Column" = Table.Pivot(#"Removed Columns", List.Distinct(#"Removed Columns"[InGroupIndex]), "InGroupIndex", lineCol)
    in
        #"Pivoted Column"
    // _______________________________ \\
in

    Value.ReplaceType(myFunction, metaDocumentation)
