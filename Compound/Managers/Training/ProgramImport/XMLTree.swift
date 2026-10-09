//
//  XMLTree.swift
//  Compound
//
//  A small element tree built with `XMLParser`, so the `.xlsx` reader can query each part
//  instead of writing a parser delegate per part. Element and attribute names keep only their
//  local part ("r:id" is "id"), since spreadsheet writers differ in the prefixes they use.
//

import Foundation

final class XMLTreeNode {
    let name: String
    let attributes: [String: String]
    fileprivate(set) var children: [XMLTreeNode] = []
    /// The text directly inside this element.
    fileprivate(set) var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    /// The first child named `name`.
    func child(_ name: String) -> XMLTreeNode? {
        children.first { $0.name == name }
    }

    /// Every descendant named `name`, in document order.
    func descendants(_ name: String) -> [XMLTreeNode] {
        children.flatMap { ($0.name == name ? [$0] : []) + $0.descendants(name) }
    }

    /// Parses `data`, or fails when it is not well-formed XML.
    static func parse(_ data: Data) throws -> XMLTreeNode {
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else { throw ProgramImportError.unreadableFile }
        return root
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: XMLTreeNode?
        private var stack: [XMLTreeNode] = []

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            var attributes: [String: String] = [:]
            for (key, value) in attributeDict {
                attributes[XMLTreeNode.localName(key)] = value
            }
            let node = XMLTreeNode(name: XMLTreeNode.localName(elementName), attributes: attributes)
            if let parent = stack.last {
                parent.children.append(node)
            } else {
                root = node
            }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            stack.removeLast()
        }
    }
}
