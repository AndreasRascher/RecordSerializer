codeunit 50001 RefTypeHelper
{
    procedure EvaluateFldRef(ValueAsText: Text; var FldRef: FieldRef)
    var
        TenantMedia: Record "Tenant Media";
        Base64Convert: Codeunit Base64Convert;
        DateFormulaType: DateFormula;
        RecordIDType: RecordId;
        BigIntegerType: BigInteger;
        BooleanType: Boolean;
        DateType: Date;
        DateTimeType: DateTime;
        DecimalType: Decimal;
        DurationType: Duration;
        GUIDType: Guid;
        IntegerType: Integer;
        OStream: OutStream;
        TimeType: Time;
    begin
        CASE FldRef.TYPE OF
            FldRef.Type::BigInteger:
                begin
                    Evaluate(BigIntegerType, ValueAsText);
                    FldRef.Value(BigIntegerType);
                end;
            FldRef.Type::Blob:
                begin
                    Clear(TenantMedia.Content);
                    IF ValueAsText <> '' then begin
                        TenantMedia.Content.CreateOutStream(OStream);
                        Base64Convert.FromBase64StringToStream(ValueAsText, OStream);
                    end;
                    FldRef.Value(TenantMedia.Content);
                end;
            FldRef.Type::Boolean:
                begin
                    Evaluate(BooleanType, ValueAsText, 9);
                    FldRef.Value(BooleanType);
                end;
            FldRef.Type::Text,
            FldRef.Type::Code:
                FldRef.Value(ValueAsText);
            FldRef.Type::Date:
                begin
                    Evaluate(DateType, ValueAsText, 9);
                    FldRef.Value(DateType);
                end;
            FldRef.Type::DateFormula:
                begin
                    Evaluate(DateFormulaType, ValueAsText, 9);
                    FldRef.Value(DateFormulaType);
                end;
            FldRef.Type::DateTime:
                begin
                    Evaluate(DateTimeType, ValueAsText, 9);
                    FldRef.Value(DateTimeType);
                end;
            FldRef.Type::Decimal:
                begin
                    Evaluate(DecimalType, ValueAsText, 9);
                    FldRef.Value(DecimalType);
                end;
            FldRef.Type::Duration:
                begin
                    Evaluate(DurationType, ValueAsText, 9);
                    FldRef.Value(DurationType);
                end;
            FldRef.Type::Guid:
                begin
                    Evaluate(GuidType, ValueAsText, 9);
                    FldRef.Value(GuidType);
                end;
            FldRef.Type::Integer,
            FldRef.Type::Option:
                begin
                    Evaluate(IntegerType, ValueAsText, 9);
                    FldRef.Value(IntegerType);
                end;
            //FldRef.Type::Media:
            //    ;
            //FldRef.Type::MediaSet:
            //    ;
            FldRef.Type::RecordId:
                begin
                    Evaluate(RecordIDType, ValueAsText, 9);
                    FldRef.Value(RecordIDType);
                end;
            FldRef.Type::Time:
                begin
                    Evaluate(TimeType, ValueAsText, 9);
                    FldRef.Value(TimeType);
                end;
            FldRef.Type::TableFilter:
                ;
            else
                Error('unhandled field type %1', FldRef.Type);
        end;

    end;

    procedure IsEmptyFldRef(FldRef: FieldRef) IsEmpty: Boolean
    var
        BooleanType: Boolean;
        GuidType: Guid;
        FieldTypeText: Text;
        DateType: Date;
        TimeType: Time;
        IntegerType: Integer;
    begin
        FieldTypeText := Strsubstno('%1="%2"', Format(FldRef.Type), FldRef.Value);
        case Format(FldRef.Type) of
            'Boolean':
                begin
                    BooleanType := FldRef.Value;
                    IsEmpty := not BooleanType;
                end;
            'BigInteger', 'Integer', 'Decimal':
                IsEmpty := Format(FldRef.Value) = '0';
            'Time':
                begin
                    TimeType := FldRef.Value;
                    IsEmpty := TimeType = 0T;
                end;
            'Date':
                begin
                    DateType := FldRef.Value;
                    IsEmpty := DateType = 0D;
                end;
            'Text',
            'Code',
            'DateFormula',
            'DateTime':
                IsEmpty := Format(FldRef.Value) = '';
            'GUID', 'Guid':
                begin
                    GuidType := FldRef.Value;
                    IsEmpty := IsNullGuid(GuidType);
                end;
            'Blob':
                begin
                    FldRef.CalcField();
                    IsEmpty := (Format(FldRef.Value) = '0');
                end;
            'Media', 'MediaSet':
                IsEmpty := IsNullGuid(Format(FldRef.Value));
            'Option':
                begin
                    IntegerType := FldRef.Value;
                    IsEmpty := IntegerType = 0;
                end;
            else
                Error('IsEmptyFldRef: unhandled field type %1', FldRef.Type);
        end; // end_case
    end;

    procedure GetFldRefValueText(var FldRef: FieldRef) ValueText: Text;
    begin
        if not FldRefValueText(FldRef, ValueText) then
            Clear(ValueText);
    end;

    procedure FldRefValueText(var FldRef: FieldRef; var ValueText: Text) OK: Boolean;
    begin
        OK := true;
        CASE Format(FldRef.Type) OF
            'BLOB':
                OK := GetBlobFieldAsText(FldRef, true, ValueText);
            'Media':
                OK := GetMediaFieldAsText(FldRef, true, ValueText);
            'MediaSet':
                Error('not Implemented');
            'BigInteger',
            'Boolean',
            'Code',
            'Date',
            'DateFormula',
            'DateTime',
            'Decimal',
            'Duration',
            'GUID',
            'Integer',
            'Option',
            'RecordId',
            'TableFilter',
            'Text',
            'Time':
                ValueText := FORMAT(FldRef.VALUE, 0, 9);
            else
                Error('unhandled Fieldtype %1', FldRef.Type);
        end;
    end;

    procedure GetMediaFieldAsText(var FldRef: FieldRef; Base64Encode: Boolean; var MediaContentAsText: Text) OK: Boolean
    var
        TenantMedia: Record "Tenant Media";
        Base64Convert: Codeunit Base64Convert;
        MediaID: Guid;
        IStream: InStream;
    begin
        Clear(MediaContentAsText);
        if FldRef.Type <> FieldType::Media then
            exit(false);
        if not Evaluate(MediaID, Format(FldRef.Value)) then
            exit(false);
        If (Format(FldRef.Value) = '') then
            exit(true);
        if IsNullGuid(MediaID) then
            exit(true);
        TenantMedia.Get(MediaID);
        TenantMedia.calcfields(Content);
        if TenantMedia.Content.HasValue then begin
            TenantMedia.Content.CreateInStream(IStream);
            if Base64Encode then
                MediaContentAsText := Base64Convert.StreamToBase64String(IStream)
            else
                IStream.ReadText(MediaContentAsText);
        end;
    end;

    procedure GetBlobFieldAsText(var FldRef: FieldRef; Base64Encode: Boolean; var BlobContentAsText: Text) OK: Boolean
    var
        TenantMedia: Record "Tenant Media";
        Base64Convert: Codeunit Base64Convert;
        IStream: InStream;
    begin
        OK := true;
        TenantMedia.Content := FldRef.Value;
        if not TenantMedia.Content.HasValue then
            exit(false);
        TenantMedia.Content.CreateInStream(IStream);
        if Base64Encode then
            BlobContentAsText := Base64Convert.StreamToBase64String(IStream)
        else
            IStream.ReadText(BlobContentAsText);
    end;

    procedure VariantToRecordRef(RecordVariant: Variant; var RecRef: RecordRef)
    begin
        Clear(RecRef);
        if not (RecordVariant.ISRECORD or RecordVariant.ISRECORDID or RecordVariant.ISRECORDREF) then
            Error('ParameterNotValidErr');

        Case True of
            RecordVariant.ISRECORD:
                RecRef.GETTABLE(RecordVariant);
            RecordVariant.ISRECORDID:
                RecRef.GET(RecordVariant);
            RecordVariant.ISRECORDREF:
                RecRef := RecordVariant;
        end;
    end;

}