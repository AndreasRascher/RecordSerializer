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
        Base64String: Text;
        FieldNode: XMLNode;
        ExportField: Dictionary of [Text, Text];
        ExportFields: List of [Dictionary of [Text, Text]];
        FieldID: Integer;
        FieldPropKey: Text;
    begin
        RecordNode := XmlElement.Create('Record', '').AsXmlNode;
        AddAttribute(RecordNode, 'ID', ReplaceInvalidXMLCharacters(Format(RecRef.RecordId)));
        CreateListOfExportFields(RecRef, ExportFields);
        foreach ExportField in ExportFields do begin
            Clear(Fldref);
            Evaluate(FieldID, ExportField.Get('ID'));
            FldRef := RecRef.Field(FieldID);
            if not RefTypeHelper.IsEmptyFldRef(Fldref) then begin
                FieldNode := XmlElement.Create('Field').AsXmlNode;
                foreach FieldPropKey in ExportField.Keys do begin
                    AddAttribute(FieldNode, FieldPropKey, ExportField.Get(FieldPropKey));
                end;
                FieldNode.AsXmlElement.Add(RefTypeHelper.GetFldRefValueText(Fldref));
                RecordNode.AsXmlElement.Add(FieldNode);
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
        XList: XmlNodeList;
        XField: XmlNode;
        FieldValueAsText: Text;
        FldRef: FieldRef;
    begin
        Clear(RecRef);
        RecRef.Open(TableID);
        XmlDocument.ReadFrom(XMLContent, XMLDoc);
        XMLDoc.SelectSingleNode('//Record', XRecord);
        XRecord.SelectNodes('//Field', XList);
        foreach XField in XList do begin
            FieldValueAsText := XField.AsXmlElement().InnerXml;
            FldRef := RecRef.Field(GetFieldIDFromFieldNode(XField));
            RefTypeHelper.EvaluateFldRef(FieldValueAsText, FldRef);
        end;
    end;
    //#endregion DeserializeFromXML XML->Record

    //#region DeserializeFromXML XML->RecordSet
    procedure XMLToRecordSet(XMLContent: Text; TableID: Integer; var TmpRecRef: RecordRef);
    var
        XMLDoc: XmlDocument;
        XRecord: XmlNode;
        XRecords: XmlNode;
        XRecordList: XmlNodeList;
        XList: XmlNodeList;
        XFields: XmlNodeList;
        XField: XmlNode;
        FieldValueAsText: Text;
        FldRef: FieldRef;
    begin
        Clear(TmpRecRef);
        TmpRecRef.Open(TableID, true);
        XmlDocument.ReadFrom(XMLContent, XMLDoc);
        XMLDoc.SelectSingleNode('//RecordSet', XRecords);
        XRecords.SelectNodes('//Record', XRecordList);
        foreach XRecord in XRecordList do begin
            XRecord.SelectNodes('//Field', XFields);
            foreach XField in XFields do begin
                FieldValueAsText := XField.AsXmlElement().InnerXml;
                FldRef := TmpRecRef.Field(GetFieldIDFromFieldNode(XField));
                RefTypeHelper.EvaluateFldRef(FieldValueAsText, FldRef);
            end;
            TmpRecRef.Insert();
        end;
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
        XNode.AsXmlElement.SetAttribute(AttrName, AttrValue);
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
        FldIndex: Integer;
        FldRef: FieldRef;
        FieldProps: Dictionary of [Text, Text];
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

    // procedure TableViewToXML(RecVariant: Variant; TableView: text) XMLDoc: XmlDocument;
    // var
    //     RecRef: RecordRef;
    //     Records: XmlNode;
    //     RecordNode: XmlNode;
    //     RootNode: XmlNode;
    // begin
    //     VariantToRecordRef(RecVariant, RecRef);
    //     RootNode := XmlElement.Create('Root').AsXmlNode();
    //     XMLDoc.Add(RootNode);

    //     RecRef.SetView(TableView);
    //     If not RecRef.findset then
    //         exit;
    //     AddRecordDefinition(RootNode, RecRef);
    //     Records := RootNode;
    //     AddGroupNode(Records, 'Records');
    //     repeat
    //         RecordNode := RecRefToXML(RecRef);
    //         Records.AsXmlElement.Add(RecordNode);
    //     until RecRef.next = 0;
    //     ShowXMLContentInMessage;
    // end;

    local procedure GetFieldIDFromFieldNode(XField: XmlNode) FieldID: Integer
    var
        FieldName: Text;
    begin
        Evaluate(FieldID, GetAttributeValue(XField, 'ID'));
        FieldName := GetAttributeValue(XField, 'Name');
    end;

    procedure AddFieldDefinitionXML(RecRef: RecordRef) XFieldDefinition: XmlNode
    var
        FldRef: FieldRef;
        XField: XmlNode;
        RecRef_Init: RecordRef;
        ID: Integer;
        FieldIDs: List of [Dictionary of [Text, Text]];
        FieldID: Dictionary of [Text, Text];
    begin
        RecRef_Init.Open(RecRef.Number);
        RecRef_Init.Init;
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

    //     procedure AddGroupNode(var _XMLNode: XmlNode; _NodeName: Text)
    //     var
    //         _XMLNewChild: XmlNode;
    //     begin
    //         AddElement(_XMLNode, _NodeName, '', _XMLNewChild);
    //         _XMLNode := _XMLNewChild;
    //     end;

    //     procedure AddNode(var pXMLNode: XmlNode; pNodeName: Text; pNodeText: Text)
    //     var
    //         lXMLNewChild: XmlNode;
    //     begin
    //         AddElement(pXMLNode, pNodeName, pNodeText, lXMLNewChild);
    //     end;

    //     procedure AddRecordDefinition(var ParentNode: XmlNode; RecRef: RecordRef)
    //     var
    //         RecordDefinition: XmlNode;
    //     begin
    //         AddElement(ParentNode, 'RecordDefinition', '', RecordDefinition);
    //         AddNode(RecordDefinition, 'Number', FORMAT(RecRef.NUMBER));
    //         AddNode(RecordDefinition, 'Name', RecRef.NAME);
    //         AddNode(RecordDefinition, 'Caption', RecRef.Caption);
    //         AddNode(RecordDefinition, 'CurrentCompany', RecRef.CurrentCompany);
    //         AddFieldDefinitionXML(RecordDefinition, RecRef);
    //     end;




    //     procedure IsExportField(var FldRef: FieldRef) IsAvailableForExport: Boolean
    //     begin
    //         case true of
    //             (FldRef.Class <> FldRef.Class::Normal):
    //                 exit(false);
    //             (not FldRef.Active):
    //                 exit(false);
    //             else
    //                 exit(true);
    //         end;
    //     end;




    //     procedure ShowXMLContentInMessage();
    //     var
    //         XmlDocText: Text;
    //     begin
    //         XmlDoc.WriteTo(XmlDocText);
    //         Message(XmlDocText);
    //     end;





    //     var
    //         XMLDoc: XMLDocument;
    //         RootNode: XmlNode;
    var
        RefTypeHelper: Codeunit RefTypeHelper;
}