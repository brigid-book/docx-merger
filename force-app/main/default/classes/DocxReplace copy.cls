public class DocxReplace {
    
    private static final List<String> nodesToSkip = new List<String>{null, 'rPr', 'tcPr', 'tcW', 'tcBorders', 'trHeight', 'trPr', 'top', 'bottom', 'left', 'right', 'pStyle', 'pPr', 'proofErr', 'textAlignment', 'numPr', 'ilvl', 'numId', 'tblPr', 'tblW', 'tblLook', 'tblGrid', 'instrText'};
    
    public static String replaceMergeFields(String docXml, Map<String, String> data) {
        
        Dom.Document document = new Dom.Document();
        document.load(docXml);
        
        List<String> texts = getTexts(document);
        List<TextSegment> segments = createTextSegments(texts);
        String combinedText = getCombinedText(segments);
        for (String mergeField : data.keySet()) {
            Boolean complete = false;
            //if the same merge field appears more than once in the document, we want to make sure to replace all instances, hence the loop
            while (!complete) {
                Boolean matchIsFound = findMatchingTextSegments(segments, combinedText, '{{' + mergeField + '}}');
                if (matchIsFound) {
                    //if a match is found, segments are updated, and combinedText is recalculated to reflect the change
                    texts = updateMatchingTextSegments(segments, data.get(mergeField));
                    combinedText = getCombinedText(segments);
                }
                else {
                    //if no match is found, we can end the loop and move on
                    complete = true;
                }
            }
        }
        document = replaceTextsInDocument(document, texts);
        deleteUnnecessaryNodes(document);
        return document.toXmlString();
    }
    
    public static String stringReplaceByIndex(String text, String replacement, Integer replacementStartIndex, Integer replacementEndIndex) {
        String beforeText = text.left(replacementStartIndex);
        String afterText = text.right(text.length() - replacementEndIndex);
        return beforeText + replacement + afterText;
    }
    
    @TestVisible
    private static List<String> getTexts(Dom.Document document) {
        Dom.XmlNode rootNode = document.getRootElement();
        List<String> texts = getTexts(rootNode);
        return texts;
    }
    
    @TestVisible
    private static List<String> getTexts(Dom.XmlNode node) {
        List<String> texts = new List<String>();
        if (node.getName() == 't') {
            texts.add(node.getText());
        }
        for (Dom.XmlNode childNode : node.getChildren()) {
            if (childNode.getName() != null && !nodesToSkip.contains(childNode.getName())) {
                texts.addAll(getTexts(childNode));
            }
        }
        return texts;
    }
    
    private static List<TextSegment> createTextSegments(List<String> texts) {
        
        List<TextSegment> textSegments = new List<TextSegment>();
        Integer segmentIndex = 0;
        Integer currentStartIndex = 0;
        for (String text : texts) {
            TextSegment segment = new TextSegment(segmentIndex, text, currentStartIndex, currentStartIndex + text.length());
            textSegments.add(segment);
            currentStartIndex += text.length();
            segmentIndex++;
        }
        
        return textSegments;
    }
    
    private static String getCombinedText(List<TextSegment> textSegments) {
        //combine all segments into one string to use for searching, in case a merge field is split across multiple segments
        String combinedText = '';
        for (TextSegment segment : textSegments) {
            combinedText += segment.text;
        }
        return combinedText;
    }
    
    private static Boolean nodeOrDescendantsContainText(Dom.XmlNode node) {
        if (node.getName() == 't' && String.isNotEmpty(node.getText())) {
            return true;
        }
        for (Dom.XmlNode child : node.getChildren()) {
            if (nodeOrDescendantsContainText(child)) return true;
        }
        return false;
    }
    
    private static Boolean findMatchingTextSegments(List<TextSegment> textSegments, String combinedText, String mergeField) {
        
        //don't allow searching for a blank string
        if (String.isBlank(mergeField)) {
            return false;
        }
        
        //search the text case-insensitively
        mergeField = mergeField.toLowerCase();
        combinedText = combinedText.toLowerCase();
        Integer matchStartIndex = combinedText.indexOf(mergeField);
        Integer matchEndIndex = matchStartIndex + mergeField.length();
        
        //if search string not found, return false
        if (matchStartIndex == -1) {
            return false;
        }
        
        Integer segmentIndex = 0;
        Integer currentPosition = 0;
        Boolean isStarted = false;
        Boolean isCompleted = false;
        
        while (!isCompleted) {
            TextSegment segment = textSegments[segmentIndex];
            
            //look for run where merge field start index is within range of the run
            if (isStarted == false && matchStartIndex >= segment.startPosition && matchStartIndex < segment.endPosition) {
                isStarted = true;
                if (matchEndIndex <= segment.endPosition) {
                    //merge field is contained entirely within this run
                    segment.matchIndex = matchStartIndex - currentPosition;
                    segment.matchLength = mergeField.length();
                    isCompleted = true;
                }
                else {
                    //merge field begins in this run but does not end in this run
                    segment.matchIndex = matchStartIndex - currentPosition;
                    segment.matchLength = segment.endPosition - matchStartIndex;
                }
            }
            else if (isStarted == true) {
                if (matchEndIndex > segment.endPosition) {
                    //merge field continues in the next run
                    segment.matchIndex = 0;
                    segment.matchLength = segment.endPosition - segment.startPosition;
                }
                else {
                    //merge field ends in this run
                    segment.matchIndex = 0;
                    segment.matchLength = matchEndIndex - currentPosition;
                    isCompleted = true;
                }
            }
            currentPosition = segment.endPosition;
            segmentIndex++;
        }
        
        return true;
    }
    
	private static List<String> updateMatchingTextSegments(List<TextSegment> segments, String replacementText) {
        
        Boolean replacementInserted = false;
        for (TextSegment segment : segments) {
            if (segment.matchIndex != null) {
                Integer start = segment.matchIndex;
            	Integer length = segment.matchLength;
                String replacement = replacementInserted ? '' : replacementText;
                String newText = stringReplaceByIndex(segment.text, replacement, start, start + length);
                replacementInserted = true;
                segment.text = newText;
                segment.matchIndex = null;
                segment.matchLength = null;
            }
        }
        recalculateSegmentIndeces(segments);
        
        List<String> texts = new List<String>();
        for (TextSegment segment : segments) {
            texts.add(segment.text);
        }
        
        return texts;
    }
    
    public static void recalculateSegmentIndeces(List<TextSegment> segments) {
        Integer currentIndex = 0;
        for (TextSegment segment : segments) {
            segment.startPosition = currentIndex;
            currentIndex += segment.text.length();
            segment.endPosition = currentIndex;
        }
    }
    
    @TestVisible
    private static Dom.Document replaceTextsInDocument(Dom.Document document, List<String> segments) {
        Dom.XmlNode rootNode = document.getRootElement();
        replaceTextsInDocument(rootNode, segments);
        return document;
    }
    
    private static List<String> replaceTextsInDocument(Dom.XmlNode node, List<String> segments) {
        
        for (Dom.XmlNode childNode : node.getChildren()) {
            if (!nodesToSkip.contains(childNode.getName())) {
                segments = replaceTextsInDocument(childNode, segments);
            }
        }
        
        if (node.getName() == 't') {
            if (segments[0] != node.getText()) {
                //w:t elements never have any child elements, just text, so there is only one node to get
                //not sure if there is any way to update the existing text node, so I'm replacing it instead
                node.removeChild(node.getChildren()[0]);
                List<String> lines = segments[0].split('\n');
                node.addTextNode(lines[0]);
                
                //if more than one line, we have to do some extra processing to make it show up correctly
                if (lines.size() > 1) {
                    
                    //get the run containing the text (w:t is always a child of w:r)
                    Dom.XmlNode run = node.getParent();
                    Dom.XmlNode runProperties = run.getChildElement('rPr', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
                    //get the parent of the run (usually will be a paragraph)
                    Dom.XmlNode grandparentNode = run.getParent();
                    
                    //if the run is the child of a paragraph, create a new paragraph for each line of text
                    if (grandparentNode.getName() == 'p') {
                        Dom.XmlNode paragraphProperties = grandParentNode.getChildElement('pPr', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
                        
                        Dom.XmlNode greatGrandparentNode = grandparentNode.getParent();						
                        
                        //we already added the first line in the existing text node, so skip index 0
                        //also we gotta count backwards because each line is inserted after the grandparent node, so counting normally would get us an order like 04321 instead of 01234
                        for (Integer i=lines.size()-1; i>0; i--) {
                            Dom.XmlNode newParagraph = insertAfter(greatGrandparentNode, createNewNode('p', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w'), grandparentNode);
                            Dom.XmlNode newRun = newParagraph.addChildElement('r', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w');
                            if (paragraphProperties != null) {
                                newParagraph.insertBefore(paragraphProperties, newRun);
                            }
                            Dom.XmlNode newText = newRun.addChildElement('t', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w');
                            if (runProperties != null) {
                                newRun.insertBefore(runProperties, newText);
                            }
                            newText.addTextNode(lines[i]);
                        }
                    }
                    //otherwise, all lines will be part of the same paragraph
                    else {
                        //we already added the first line in the existing text node, so begin at index 1
                        for (Integer i=1; i<lines.size(); i++) {
                            grandparentNode.addChildElement('br', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w');
                            Dom.XmlNode newRun = grandparentNode.addChildElement('r', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w');
                            Dom.XmlNode newText = newRun.addChildElement('t', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w');
                            if (runProperties != null) {
                                newRun.insertBefore(runProperties, newText);
                            }
                            newText.addTextNode(lines[i]);
                        }
                    }
                }
            }
            segments.remove(0);
        }
        
        return segments;
    }
    
    private static void deleteUnnecessaryNodes(Dom.Document document) {
        Dom.XmlNode rootNode = document.getRootElement();
        deleteUnnecessaryNodes(rootNode);
    }
    
    private static Boolean deleteUnnecessaryNodes(Dom.XmlNode node) {
        String nodeName = node.getName();
        Boolean toBeDeleted = false;
        List<Dom.XmlNode> childNodes = node.getChildren();
        for (Dom.XmlNode childNode : childNodes.clone()) {
            if (deleteUnnecessaryNodes(childNode)) {
                node.removeChild(childNode);
                childNodes.remove(childNodes.indexOf(childNode));
            }
        }
        
        //delete empty paragraphs
        if (nodeName == 'p' && !nodeOrDescendantsContainText(node)) {
            toBeDeleted = true;
            //don't delete the last paragraph in a table cell; doing so would corrupt the document
            Dom.XmlNode parentNode = node.getParent();
            if (parentNode.getName() == 'tc') {
                List<Dom.XmlNode> siblingNodes =  parentNode.getChildren();
                Integer numberOfParagraphNodes = 0;
                for (Dom.XmlNode sibling : siblingNodes) {
                    if (sibling.getName() == 'p') {
                        numberOfParagraphNodes++;
                    }
                }
                if (numberOfParagraphNodes < 2) {
                    toBeDeleted = false;
                }
            }
        }
        //delete empty runs
        else if (nodeName == 'r' && !nodeOrDescendantsContainText(node)) {
            toBeDeleted = true;
        }
        //delete empty text
        else if (nodeName == 't' && node.getText() == '') {
            toBeDeleted = true;
        }
        
        return toBeDeleted;
    }
    
    private static Dom.XmlNode createNewNode(String name, String namespace, String prefix) {
        String xml = '<xml></xml>';
        Dom.Document document = new Dom.Document();
        document.load(xml);
        Dom.XmlNode rootNode = document.getRootElement();
        return rootNode.addChildElement(name, namespace, prefix);
    }
    
    private static Dom.XmlNode insertAfter(Dom.XmlNode parent, Dom.XmlNode newNode, Dom.XmlNode referenceNode) {
        List<Dom.XmlNode> siblings = parent.getChildren();
        
        Dom.XmlNode nodeAfter = null;
        for (Integer i = 0; i < siblings.size(); i++) {
            if (siblings[i] === referenceNode) {
                if (i + 1 < siblings.size()) {
                    nodeAfter = siblings[i + 1];
                }
                break;
            }
        }
        
        return parent.insertBefore(newNode, nodeAfter);
    }
    
    private class TextSegment {
        Integer index;
        String text;
        //shows where the segment is located within the combined text of the document
        Integer startPosition;
        Integer endPosition;
        //shows the location and length of the match if one is found
        Integer matchIndex;
        Integer matchLength;
        
        TextSegment(Integer index, String text, Integer startPosition, Integer endPosition) {
            this.index = index;
            this.text = text;
            this.startPosition = startPosition;
            this.endPosition = endPosition;
        }
        
        void offsetIndex(Integer offset) {
            this.startPosition += offset;
            this.endPosition += offset;
        }
        
    }
}