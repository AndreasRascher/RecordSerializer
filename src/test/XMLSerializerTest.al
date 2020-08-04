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
        "Payment Terms": Array[2] of Record "Payment Terms";
        RecRef: RecordRef;
        RecRef_Left: RecordRef;
        RecRef_Right: RecordRef;
        XMLContent: Text;
        FieldsToIgnore: Record Field temporary;
    begin
        //[GIVEN]
        "Payment Terms"[1].FindFirst();
        //[WHEN]
        XmlSerializer.RecordToXML("Payment Terms"[1], XMLContent);
        XmlSerializer.XMLToRecord(XMLContent, Database::"Payment Terms", RecRef);
        RecRef.SetTable("Payment Terms"[2]);
        //[THEN]
        RecRef_Left.GetTable("Payment Terms"[1]);
        RecRef_Right.GetTable("Payment Terms"[2]);
        CompareFields(RecRef_Left, RecRef_Right, 'Unequal field values');
    end;

    [Test]
    procedure RecordSet_SerializeAndDeserialize_PaymentTerms()
    var
        PaymentTerms: Record "Payment Terms";
        TmpRecRef: RecordRef;
        RecRef_Left: RecordRef;
        RecRef_Right: RecordRef;
        XMLContent: Text;
        FieldsToIgnore: Record Field temporary;
        RecordCount: Integer;
        i: Integer;
    begin
        //[GIVEN]
        PaymentTerms.Find('-');
        PaymentTerms.SetFilter(Code, '%1..', PaymentTerms.Code);
        PaymentTerms.Next(5);
        PaymentTerms.SetFilter(Code, '%1..%2', PaymentTerms.getrangemin(Code), PaymentTerms.Code);
        //[WHEN]
        XmlSerializer.RecordSetToXML(PaymentTerms, '', XMLContent);
        XmlSerializer.XMLToRecordSet(XMLContent, Database::"Payment Terms", TmpRecRef);
        //[THEN]
        for i := 0 To 5 do begin
            if (i = 0) then begin
                TmpRecRef.FindSet;
                PaymentTerms.Find('-')
            end else begin
                TmpRecRef.Next();
                PaymentTerms.Next();
            end;
            RecRef_Left := TmpRecRef;
            RecRef_Right.GetTable(PaymentTerms);
            CompareFields(RecRef_Left, RecRef_Right, 'Unequal field values');
        end;
    end;

    local procedure CompareFields(RecRef_left: RecordRef; RecRef_right: RecordRef; ErrorMessage: text)
    var
        FldIndex: Integer;
        RefTypeHelper: Codeunit RefTypeHelper;
        FieldContent1: text;
        FieldContent2: text;
        FldRef_Left: FieldRef;
        FldRef_Right: Fieldref;
    begin
        for FldIndex := 1 to RecRef_left.FieldCount do begin
            FldRef_Left := RecRef_left.FieldIndex(FldIndex);
            FldRef_Right := RecRef_right.FieldIndex(FldIndex);
            case RecRef_left.FieldIndex(FldIndex).Type of
                FieldType::Media:
                    begin
                        RefTypeHelper.GetBlobFieldAsText(FldRef_Left, false, FieldContent1);
                        RefTypeHelper.GetBlobFieldAsText(FldRef_Right, false, FieldContent2);
                        if FieldContent1 <> FieldContent2 then
                            Error(ErrorMessage + '\Field "%1"', FldRef_Left.Name);
                    end;
                FieldType::Blob:
                    begin
                        RefTypeHelper.GetMediaFieldAsText(FldRef_Left, false, FieldContent1);
                        RefTypeHelper.GetBlobFieldAsText(FldRef_Right, false, FieldContent2);
                        if FieldContent1 <> FieldContent2 then
                            Error(ErrorMessage + '\Field "%1"', FldRef_Left.Name);
                    end;
                else begin
                        if FldRef_Left.Value <> FldRef_Right.Value then
                            Error(ErrorMessage + '\Field "%1"', FldRef_Left.Name);
                    end;
            end;
        end;
    end;


    var
        XmlSerializer: Codeunit XmlSerializer;
        Assert: Codeunit "Library Assert";
}