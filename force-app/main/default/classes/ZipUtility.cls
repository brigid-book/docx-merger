//https://salesforcefox.com/how-to-zip-unzip-files-natively-in-salesforce-use-this-ready-to-use-zip-utility/
public class ZipUtility {
    
    public static List<ContentVersion> doExtract(ContentVersion zipFile) {
        return doExtract(zipFile.VersionData);
    }
    
    public static List<ContentVersion> doExtract(Blob zipFileData) {
        Compression.ZipReader reader = new Compression.ZipReader(zipFileData);
        
        //make a list of files contained within the zip archive
        List<ContentVersion> extractedFiles = new List<ContentVersion>(); 
        for (Compression.ZipEntry entry : reader.getEntries()) {
            String entryName = entry.getName();
            //skip folders (names ending with '/')
            if (!entryName.endsWith('/')) {
                Blob fileBlob = reader.extract(entry);
                //put extracted data into a contentVersion object
                ContentVersion extractedFile = new ContentVersion(
                    Title = entryName,
                    PathOnClient = entryName,
                    VersionData = fileBlob
                );
                extractedFiles.add(extractedFile);
            }
        }
        return extractedFiles;
    }
    
    public static ContentVersion doCompress(List<ContentVersion> files) {
        Compression.ZipWriter writer = new Compression.ZipWriter();
        
        //add the files to be compressed
        for (ContentVersion file : files) {
            writer.addEntry(file.PathOnClient, file.VersionData);
        }
        //compress the above files into a zip archive
        Blob zipBlob = writer.getArchive();
        
        //create a contentVersion object to hold the zipped file
        string zipFileName = 'CompressedFiles.zip';
        ContentVersion zipFile = new ContentVersion(
            Title = zipFileName,
            PathOnClient = zipFileName,
            VersionData  = zipBlob
        );
        
        return zipFile;
    }
    
}