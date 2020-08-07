codeunit 50000 XMLSerializerTest
{
    Subtype = Test;

    [Test]
    procedure Record_SerializeInteger()
    var
        Integer: Record Integer;
        XMLContent: Text;
    begin
        Integer.Get(1);
        XmlSerializer.RecordToXML(Integer, XMLContent);
    end;

    [Test]
    procedure Record_SerializePaymentTerms()
    var
        PaymentTerms: Record "Payment Terms";
        XMLContent: Text;
    begin
        PaymentTerms.FindFirst();
        XmlSerializer.RecordToXML(PaymentTerms, XMLContent);
    end;

    [Test]
    procedure Record_SerializeItem()
    var
        Item: Record "Item";
        XMLContent: Text;
    begin
        Item.FindFirst();
        XmlSerializer.RecordToXML(Item, XMLContent);
    end;

    [Test]
    procedure Record_SerializeAndDeserialize_PaymentTerms()
    var
        PaymentTerms: Record "Payment Terms";
        RecRef_Left: RecordRef;
        RecRef_Right: RecordRef;
        XMLContent: Text;
    begin
        //[GIVEN] Payment terms exits
        PaymentTerms.Find('-');
        repeat
            //[WHEN] Serialize and Deserialize Record
            XmlSerializer.RecordToXML(PaymentTerms, XMLContent);
            XmlSerializer.XMLToRecord(XMLContent, Database::"Payment Terms", RecRef_Left);
            RecRef_Right.GetTable(PaymentTerms);
            //[THEN] Result matches origin
            CompareFields(RecRef_Left, RecRef_Right, 'Unequal field values');
        until PaymentTerms.Next() = 0;
    end;

    [Test]
    procedure RecordSet_SerializeAndDeserialize_PaymentTerms()
    var
        PaymentTerms: Record "Payment Terms";
        RecRef_Left: RecordRef;
        RecRef_Right: RecordRef;
        XMLContent: Text;
        i: Integer;
        ExpectedQty: Integer;
    begin
        //[GIVEN] Top 5 Records from Payment Termns
        ExpectedQty := 5;
        PaymentTerms.Find('-');
        PaymentTerms.SetFilter(Code, '%1..', PaymentTerms.Code);
        PaymentTerms.Next(ExpectedQty - 1);
        PaymentTerms.SetFilter(Code, '%1..%2', PaymentTerms.getrangemin(Code), PaymentTerms.Code);

        if PaymentTerms.Count <> ExpectedQty then Error('%1 Lines in filter expected', ExpectedQty);
        //[WHEN] recordset is saved as xml
        XmlSerializer.RecordSetToXML(PaymentTerms, '', XMLContent);
        if XmlSerializer.XMLRecordSet_GetRecordCount(XMLContent) <> ExpectedQty then
            Error('%1 Lines in recordset expected', ExpectedQty);
        //[THEN get records one by one and compare fields 
        for i := 1 to XmlSerializer.XMLRecordSet_GetRecordCount(XMLContent) do begin
            XmlSerializer.XMLRecordSet_GetRecordAtIndex(XMLContent, i, RecRef_Left);
            if not RecRef_Right.Get(RecRef_Left.RecordId) then
                Error('Invalid Key Fields after deserialze');
            CompareFields(RecRef_Left, RecRef_Right, 'Unequal field value');
        end;
    end;

    local procedure CompareFields(RecRef_left: RecordRef; RecRef_right: RecordRef; ErrorMessage: text)
    var
        RefTypeHelper: Codeunit RefTypeHelper;
        FldRef_Left: FieldRef;
        FldRef_Right: Fieldref;
        FldIndex: Integer;
        FieldContent_Left: text;
        FieldContent_Right: text;
    begin
        for FldIndex := 1 to RecRef_left.FieldCount do begin
            FldRef_Left := RecRef_left.FieldIndex(FldIndex);
            FldRef_Right := RecRef_right.FieldIndex(FldIndex);
            case RecRef_left.FieldIndex(FldIndex).Type of
                FieldType::Media:
                    begin
                        RefTypeHelper.GetBlobFieldAsText(FldRef_Left, false, FieldContent_Left);
                        RefTypeHelper.GetBlobFieldAsText(FldRef_Right, false, FieldContent_Right);
                    end;
                FieldType::Blob:
                    begin
                        RefTypeHelper.GetMediaFieldAsText(FldRef_Left, false, FieldContent_Left);
                        RefTypeHelper.GetBlobFieldAsText(FldRef_Right, false, FieldContent_Right);
                    end;
                else begin
                        FieldContent_Left := Format(FldRef_Left.Value);
                        FieldContent_Right := Format(FldRef_Right.Value);
                    end;
            end; //end_case
            if FieldContent_Left <> FieldContent_Right then
                Error('%1\Field "%2"', ErrorMessage, FldRef_Left.Name);
            Assert.AreEqual(FieldContent_Left, FieldContent_Right, ErrorMessage + '\Field "%1"' + FldRef_Left.Name);
        end;
    end;


    var
        XmlSerializer: Codeunit XmlSerializer;
        Assert: Codeunit "Library Assert";
}