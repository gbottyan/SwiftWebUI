//
//  File.swift
//
//
//  Created by Gabor Bottyan on 28/02/2024.
//


//
//  SubscriptionView.swift
//  SwiftWebUI
//
//  Created by Helge Heß on 20.06.19.
//  Copyright © 2019 Helge Heß. All rights reserved.
//

#if canImport(Combine)
import Combine

public extension View {
    
    //@available(*, unavailable) // enable once ready
    func timer(_ time: Double = 1000) -> TimerView<Self> {
        return TimerView(time:time, view: self)
    }
    
}

public struct TimerView<Content: View>: View {
    public typealias Body = Never
    let time: Double
    let view: Content
    
    init(time: Double, view: Content) {
        self.view = view
        self.time = time
    }
}


extension TimerView: TreeBuildingView {
    func buildTree(in context: TreeStateContext) -> HTMLTreeNode {
        return context.currentBuilder.buildTree(for: self, in: context)
    }
}


extension HTMLTreeBuilder {
    
    func buildTree<Content: View>(for view: TimerView<Content>, in context: TreeStateContext) -> HTMLTreeNode {
        context.appendContentElementIDComponent()
        let childTree = buildTree(for: view.view, in: context)
        context.deleteLastElementIDComponent()
        let tree = TimerNode(time: view.time, elementID : context.currentElementID, content: childTree)
        return tree
    }
}

final class TimerNode: HTMLWrappingNode {
    var time: Double
    let elementID    : ElementID
    let content      : HTMLTreeNode
    
    init(time: Double, elementID: ElementID, content: HTMLTreeNode) {
        self.elementID    = elementID
        self.content      = content
        self.time = time
    }
    
    func generateHTML(into html: inout String) {
        // TBD: We could use <h1> etc, but this makes it harder to update?
        html += "<div"
        
        html.appendAttribute("id", elementID.webID)
        html += ">"
        html += "<script language='javascript'>setInterval(() => {console.log(\"this is the the message for: \(elementID.webID) \"); SwiftUI.valueCommit('\(elementID.webID)')}, \(time));</script>"
        defer { html += "</div>" }
        
        self.content.generateHTML(into: &html)
    }
    
    func invoke(_ webID: [String], in context: TreeStateContext) throws {
        try content.invoke(webID, in: context)
    }
    
    func nodeByApplyingNewContent(_ newContent: HTMLTreeNode) -> TimerNode {
        // TBD: Create a new subscription or reuse the old?
        return TimerNode(time: time, elementID: elementID, content: newContent)
    }
}

#endif // canImport(Combine)
