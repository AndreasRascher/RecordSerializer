codeunit 50200 XmlSerializer
{

    //#region SerializeToXML - Record->XML
    /// <summary> 
    /// Serialize RecordVariant to XML. Returns XMLText
    /// </summary>
    procedure RecordToXML(RecVariant: Variant; var XMLContent: Text)
    var
        RecRef: RecordRef;
    begin
        RefTypeHelper.VariantToRecordRef(RecVariant, RecRef);
        RecRefToXMLDoc(RecRef).WriteTo(XMLContent);
    end;

    /// <summary> 
    /// Serialize RecordRef Data to XML
    /// </summary>
    procedure RecRefToXMLDoc(var RecRef: RecordRef) XMLDoc: XmlDocument;
    var
        RecordNode: XmlNode;
    begin
        RecordNode := RecRefToXMLNode(RecRef);
        XMLDoc := XMLDocument.Create();
        XMLDoc.Add(RecordNode);
    end;

    procedure RecRefToXMLNode(var RecRef: RecordRef) RecordNode: XmlNode;
    var
        Fldref: FieldRef;
        FieldNode: XMLNode;
        ExportField: Dictionary of [Text, Text];
        ExportFields: List of [Dictionary of [Text, Text]];
        FieldID: Integer;
        FieldPropKey: Text;
    begin
        RecordNode := XmlElement.Create('Record', '').AsXmlNode();
        AddAttribute(RecordNode, 'ID', ReplaceInvalidXMLCharacters(Format(RecRef.RecordId)));
        CreateListOfExportFields(RecRef, ExportFields);
        foreach ExportField in ExportFields do begin
            Clear(Fldref);
            Evaluate(FieldID, ExportField.Get('ID'));
            FldRef := RecRef.Field(FieldID);
            if not RefTypeHelper.IsEmptyFldRef(Fldref) then begin
                FieldNode := XmlElement.Create('Field').AsXmlNode();
                foreach FieldPropKey in ExportField.Keys do
                    AddAttribute(FieldNode, FieldPropKey, ExportField.Get(FieldPropKey));
                FieldNode.AsXmlElement().Add(RefTypeHelper.GetFldRefValueText(Fldref));
                RecordNode.AsXmlElement().Add(FieldNode);
            end;  //end_case
        end; //end_for
    end;
    //#endregion SerializeToXML - Record->XML

    //#region SerializeToXML - RecordSet->XML
    procedure RecordSetToXML(RecVariant: Variant; TableView: text; var XMLContent: text)
    var
        RecRef: RecordRef;
    begin
        RefTypeHelper.VariantToRecordRef(RecVariant, RecRef);
        RecRefSetToXMLDoc(RecRef, TableView).WriteTo(XMLContent);
    end;

    procedure RecRefSetToXMLDoc(var RecRef: RecordRef; TableView: text) XMLDoc: XmlDocument;
    var
        XRecordSet: XmlNode;
    begin
        XRecordSet := RecRefSetToXMLNode(RecRef, TableView);
        XMLDoc := XmlDocument.Create();
        XMLDoc.Add(XRecordSet);
    end;

    procedure RecRefSetToXMLNode(var RecRef: RecordRef; TableView: text) XRecordSet: XmlNode;
    var
        XRecord: XmlNode;
    begin
        if TableView <> '' then
            RecRef.SetView(TableView);
        if not RecRef.FindSet() then
            exit;
        XRecordSet := XMLElement.Create('RecordSet').AsXmlNode();
        AddAttribute(XRecordSet, 'TableID', ReplaceInvalidXMLCharacters(format(RecRef.Number)));
        AddAttribute(XRecordSet, 'TableName', ReplaceInvalidXMLCharacters(format(RecRef.Name)));
        repeat
            XRecord := RecRefToXMLNode(RecRef);
            XRecordSet.AsXmlElement().Add(XRecord);
        until RecRef.Next() = 0;
    end;
    //#endregion SerializeToXML - Record->XML

    //#region DeserializeFromXML XML->Record
    procedure XMLToRecord(XMLContent: Text; TableID: Integer; var RecRef: RecordRef);
    var
        XMLDoc: XmlDocument;
        XRecord: XmlNode;
    begin
        XmlDocument.ReadFrom(XMLContent, XMLDoc);
        XMLDoc.SelectSingleNode('//Record', XRecord);
        XRecordNodeToRecordRef(XRecord, TableID, RecRef);
    end;
    //#endregion DeserializeFromXML XML->Record

    //#region DeserializeFromXML XML->RecordSet
    procedure XMLRecordSet_GetRecordCount(XMLContent: Text) RecordCount: Integer;
    var
        XMLDoc: XmlDocument;
        XRecordSet: XmlNode;
        XRecordList: XmlNodeList;
    begin
        XmlDocument.ReadFrom(XMLContent, XMLDoc);
        XMLDoc.SelectSingleNode('//RecordSet', XRecordSet);
        XRecordSet.SelectNodes('//Record', XRecordList);
        RecordCount := XRecordList.Count;
    end;

    procedure XMLRecordSet_GetRecordAtIndex(XMLContent: Text; Index: Integer; var ResultRecRef: RecordRef) OK: Boolean
    var
        XMLDoc: XmlDocument;
        XRecord: XmlNode;
        XRecordSet: XmlNode;
        TableID: Integer;
    begin
        OK := true;
        Clear(ResultRecRef);
        XmlDocument.ReadFrom(XMLContent, XMLDoc);
        XMLDoc.SelectSingleNode('//RecordSet', XRecordSet);
        if not XRecordSet.SelectSingleNode(StrSubstNo('//Record[%1]', Index), XRecord) then
            exit(false);
        TableID := TryFindTableID(XRecordSet);
        XRecordNodeToRecordRef(XRecord, TableID, ResultRecRef);
    end;
    //#endregion DeserializeFromXML XML->RecordSet
    local procedure ReplaceInvalidXMLCharacters(OriginalText: Text) ReplacedText: Text
    var
        CharToReplace: Text[1];
        i: Integer;
    begin
        ReplacedText := OriginalText;
        ReplacedText := ReplacedText.Replace('&', '&amp;');
        ReplacedText := ReplacedText.Replace('<', '&lt;');
        ReplacedText := ReplacedText.Replace('>', '&gt;');
        ReplacedText := ReplacedText.Replace('"', '&quot;');
        ReplacedText := ReplacedText.Replace('''', '&apos;');
        CharToReplace[1] := 8;
        for i := 1 to 13 do begin
            CharToReplace[1] := i;
            ReplacedText := ReplacedText.Replace(CharToReplace, StrSubstNo('&#%1;', i));
        end;
    end;

    local procedure AddAttribute(XNode: XmlNode; AttrName: Text; AttrValue: Text): Boolean
    begin
        if not XNode.IsXmlElement then
            exit(false);
        XNode.AsXmlElement().SetAttribute(AttrName, AttrValue);
    end;

    procedure GetAttributeValue(XNode: XmlNode; AttrName: Text): Text
    var
        XAttribute: XmlAttribute;
    begin
        if XNode.AsXmlElement().Attributes().Get(AttrName, XAttribute) then
            exit(XAttribute.Value());
    end;

    local procedure CreateListOfExportFields(var RecRef: RecordRef; var FieldIDs: List of [Dictionary of [Text, Text]])
    var
        FldRef: FieldRef;
        FieldProps: Dictionary of [Text, Text];
        FldIndex: Integer;
    begin
        for FldIndex := 1 to RecRef.FieldCount do begin
            FldRef := RecRef.FieldIndex(FldIndex);
            If (FldRef.Class = FldRef.Class::Normal) and FldRef.Active then begin
                Clear(FieldProps);
                FieldProps.Add('ID', Format(FldRef.Number));
                FieldProps.Add('Name', FldRef.Name);
                FieldIDs.Add(FieldProps);
            end;
        end;
    end;

    local procedure GetFieldIDFromFieldNode(XField: XmlNode) FieldID: Integer
    var
        FieldName: Text;
    begin
        Evaluate(FieldID, GetAttributeValue(XField, 'ID'));
        FieldName := GetAttributeValue(XField, 'Name');
    end;

    local procedure XRecordNodeToRecordRef(XRecord: XmlNode; TableID: Integer; var RecRef: RecordRef)
    var
        FldRef: FieldRef;
        ChildNodeCount: Integer;
        FieldValueAsText: Text;
        XField: XmlNode;
        XList: XmlNodeList;
    begin
        XRecord.SelectNodes('child::*', XList); // select all element children
        ChildNodeCount := XList.Count;
        Clear(RecRef);
        RecRef.Open(TableID);
        foreach XField in XList do begin
            FieldValueAsText := XField.AsXmlElement().InnerXml;
            FldRef := RecRef.Field(GetFieldIDFromFieldNode(XField));
            RefTypeHelper.EvaluateFldRef(FieldValueAsText, FldRef);
        end;
    end;

    local procedure TryFindTableID(XRecordSet: XmlNode) TableID: Integer;
    var
        TableMetadata: Record "Table Metadata";
        TableName: Text;
    begin
        // FirstTry ByName
        TableName := GetAttributeValue(XRecordSet, 'TableName');
        if TableName <> '' then begin
            TableMetadata.SetFilter(Name, '@%1', TableName);
            if TableMetadata.FindFirst() then
                exit(TableMetadata.ID);
        end;
        // SecondTry TableID
        if Evaluate(TableID, GetAttributeValue(XRecordSet, 'TableID')) then
            exit(TableID);
    end;

    procedure AddFieldDefinitionXML(RecRef: RecordRef) XFieldDefinition: XmlNode
    var
        RecRef_Init: RecordRef;
        FldRef: FieldRef;
        FieldID: Dictionary of [Text, Text];
        ID: Integer;
        FieldIDs: List of [Dictionary of [Text, Text]];
        XField: XmlNode;
    begin
        RecRef_Init.Open(RecRef.Number);
        RecRef_Init.Init();
        XFieldDefinition := XmlElement.Create('FieldDefinition').AsXmlNode();
        CreateListOfExportFields(RecRef, FieldIDs);
        foreach FieldID in FieldIDs do begin
            Clear(Fldref);
            Evaluate(ID, FieldID.Get('ID'));
            FldRef := RecRef.Field(ID);
            XField := XmlElement.Create('Field').AsXmlNode();
            AddAttribute(XField, 'Number', format(Fldref.Number));
            AddAttribute(XField, 'Type', FORMAT(FldRef.TYPE));
            if FldRef.Length <> 0 then
                AddAttribute(XField, 'Length', FORMAT(FldRef.LENGTH));
            if FldRef.Class <> FieldClass::Normal then
                AddAttribute(XField, 'Class', FORMAT(FldRef.CLASS));
            if not FldRef.Active then
                AddAttribute(XField, 'Active', FORMAT(Fldref.Active, 0, 9));
            AddAttribute(XField, 'Name', FORMAT(Fldref.Name, 0, 9));
            AddAttribute(XField, 'Caption', FORMAT(Fldref.Caption, 0, 9));
            if not (FldRef.Type in [FieldType::Blob, FieldType::Media, FieldType::MediaSet]) then
                AddAttribute(XField, 'InitValue', Format(RecRef_Init.Field(FldRef.Number).Value, 0, 9));
            If FldRef.Type = FieldType::Option then begin
                AddAttribute(XField, 'OptionCaption', FORMAT(Fldref.OptionCaption));
                AddAttribute(XField, 'OptionMembers', FORMAT(Fldref.OptionMembers));
            end;
            if Fldref.Relation <> 0 then
                AddAttribute(XField, 'Relation', FORMAT(Fldref.Relation));
            XFieldDefinition.AsXmlElement().Add(XField);
        end;
    end;

    var
        RefTypeHelper: Codeunit RefTypeHelper;
}