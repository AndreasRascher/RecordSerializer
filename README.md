# RecordSerializer
## Codeunit XmlSerializer

Record <-> XML
 * RecordToXML(RecVariant: Variant; var XMLContent: Text)
 * XMLToRecord(XMLContent: Text; TableID: Integer; var RecRef: RecordRef)
 
RecordSet <-> XML
 * RecordSetToXML(RecVariant: Variant; TableView: text; var XMLContent: text)
 * XMLRecordSet_GetRecordCount(XMLContent: Text) RecordCount: Integer

## Codeunit RefTypeHelper
* Handle conversion of text from/to fieldref

## Codeunit Base64Convert
* Used to encode/decode BLOB data as text to base64
