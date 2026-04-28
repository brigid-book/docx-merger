public with sharing class DocxMerger {
    
    public List<ContentVersion> extractedFiles; //the individual files within the word document zip archive
    public ContentVersion contentFile; //the document.xml file from the extractedFiles list
    
    public Id mergeDoc(String staticResourceName, Id parentId, Map<String,String> mergeFields) {
        return mergedoc(staticResourceName, parentId, mergeFields, staticResourceName + ' - merged');
    }
    
    public Id mergeDoc(String staticResourceName, Id parentId, Map<String,String> mergeFields, String newDocumentTitle) {
        //get static resource by name
        StaticResource zipfile;
        try {
            zipFile = [SELECT Body FROM StaticResource WHERE Name = :staticResourceName];
        }
        catch (QueryException e) {
            e.setMessage('The template document with the specified name could not be found. It may have been deleted, or you may not have permission to access it.');
            throw e;
        }
        Blob zipFileBody = zipFile.Body;
        return mergeDoc(zipFileBody, parentId, mergeFields, newDocumentTitle);
    }
    
    public Id mergeDoc(Blob zipFileBody, Id parentId, Map<String,String> mergeFields, String newDocumentTitle) {
        
        Blob fileData = readFile(zipFileBody);
        String docXml = fileData.toString();
		
        //we're going to insert a line explicitly declaring the "xml" namespace as "http://www.w3.org/XML/1998/namespace"
        //this is required so that apex doesn't do its bullsh*t "namespace normalization" thing and f**k up any elements/attributes that have the xml namespace, thereby corrupting the word document
        //you do not know how much of a headache this has caused me
        Integer indexToInsertXmlns = docXml.indexOf('xmlns');
        docXml = DocxReplace.stringReplaceByIndex(docXml, 'xmlns:xml="http://www.w3.org/XML/1998/namespace" ', indexToInsertXmlns, indexToInsertXmlns);
        
        //evaluate merge fields and recompress with updated xml
        docXml = DocxReplace.replaceMergeFields(docXml, mergeFields);
        contentFile.VersionData = Blob.valueof(docxml);
        ContentVersion mergedDocument = ZipUtility.doCompress(extractedFiles);
        
        //insert the new file
        Id mergedFileId = insertMergedFile(mergedDocument, newDocumentTitle, parentId);
        
        return mergedFileId;
    }
    
    private Blob readFile(Blob zipFileData) {
        extractedFiles = ZipUtility.doExtract(zipFileData);
        for (ContentVersion file : extractedFiles) {
            if (file.PathOnClient == 'word/document.xml') {
                contentFile = file;
            }
        }
        if (contentFile == null) {
            NoDataFoundException e = new NoDataFoundException();
            e.setMessage('The file "document.xml" could not be found within the data of the specified document. Please ensure that the specified file is a .docx file.');
            throw e;
        }
        Blob fileData = contentFile.VersionData;
        return fileData;
    }
    
    private Id insertMergedFile(ContentVersion mergedDocument, String newDocumentTitle, Id parentId) {
        ContentVersion mergedFile = new ContentVersion();
        mergedFile.VersionData = mergedDocument.VersionData;
        mergedFile.Title = newDocumentTitle;
        mergedFile.ContentLocation = 's';
        mergedFile.PathOnClient = newDocumentTitle + '.docx';
        insert mergedFile;

        Id insertedDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :mergedFile.Id].ContentDocumentId;
        ContentDocumentLink documentLink = new ContentDocumentLink();
        documentLink.ContentDocumentId = insertedDocumentId;
        documentLink.LinkedEntityId = parentId;
        documentLink.ShareType = 'I';
        documentLink.Visibility = 'AllUsers';
        insert documentLink;
        
        return mergedFile.Id;
    }
    
    /*
	public Id mergeDoc(Id ContentDocumentId, Id parentId, Map<String,String> mergeFields, String newDocumentTitle) {
        //get content version file by id
        ContentVersion zipFile;
        try {
            zipFile = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId AND IsLatest = TRUE];
        }
        catch (QueryException e) {
            e.setMessage('The contentDocument with the specified id could not be found. It may have been deleted, or you may not have permission to access it.');
            throw e;
        }
        Blob fileData = readFile(zipFile.VersionData);
        return mergeDoc(fileData, parentId, mergeFields, newDocumentTitle);
    }
	*/
    
}