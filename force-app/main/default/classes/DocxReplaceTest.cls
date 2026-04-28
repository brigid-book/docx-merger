@isTest
private class DocxReplaceTest {
    	
    @isTest
    static void merge_fields_are_replaced() {
        String docXml = '<document><body><p><r><t>{{</t></r><r><t>{{</t></r><r><t>header1}}</t></r></p></body></document>';
        Map<String,String> mergeFields = new Map<String,String>{
            '{{mergefield}}' =>  'I HAVE BEEN MERGED',
            '{{header1}}' =>  'NEW HEADER 1',
            '{{header2}}' =>  'NEW HEADER 2'
        };
        docXml = DocxReplace.replaceMergeFields(docXml, mergefields);
        Dom.Document document = new Dom.Document();
        document.load(docXml);
        String documentText = String.join(DocxReplace.getTexts(document), '');
        Assert.areEqual('{{NEW HEADER 1', documentText);
    }
    
    @isTest
    static void merge_fields_are_case_insensitive() {
        String docXml = '<document><body><p><r><t>{{Header1}}</t></r></p></body></document>';
        Map<String,String> mergeFields = new Map<String,String>{
            '{{mergefield}}' =>  'I HAVE BEEN MERGED',
            '{{header1}}' =>  'NEW HEADER 1',
            '{{header2}}' =>  'NEW HEADER 2'
        };
        docXml = DocxReplace.replaceMergeFields(docXml, mergefields);
        Dom.Document document = new Dom.Document();
        document.load(docXml);
        String documentText = String.join(DocxReplace.getTexts(document), '');
        Assert.areEqual('NEW HEADER 1', documentText);
    }
    
    @isTest
    static void multiLineMergeFieldsAreOutputAsSeparateParagraphs() {
        String docXml = '<document><body><p><r><t>foo bar </t></r><r><t>{{multiline}}</t></r></p></body></document>';
        Map<String,String> mergeFields = new Map<String,String>{
            '{{mergefield}}' =>  'I HAVE BEEN MERGED',
            '{{header1}}' =>  'NEW HEADER 1',
            '{{multiline}}' =>  'line 1\nline 2'
        };
        docXml = DocxReplace.replaceMergeFields(docXml, mergefields);
        Dom.Document document = new Dom.Document();
        document.load(docXml);
        Dom.XmlNode body = document.getRootElement().getChildren()[0];
        List<Dom.XmlNode> paragraphs = new List<Dom.XmlNode>();
        for (Dom.XmlNode node : body.getChildren()) {
            if (node.getName() == 'p') {
                paragraphs.add(node);
            }
        }
        System.debug(document.toXmlString());
        Assert.areEqual(2, paragraphs.size());
        String paragraph1Text = String.join(DocxReplace.getTexts(paragraphs[0]), '');
        Assert.areEqual('foo bar line 1', paragraph1Text);
        String paragraph2Text = String.join(DocxReplace.getTexts(paragraphs[1]), '');
        Assert.areEqual('line 2', paragraph2Text);
    }
    
}