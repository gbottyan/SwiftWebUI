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
  func onReceive<P>(_ publisher: P,
                    perform action: @escaping ( P.Output ) -> Void)
       -> SubscriptionView<P, Self>
      where P: Publisher, P.Failure == Never
  {
    return SubscriptionView(publisher: publisher, action: action, view: self)
  }

}

public struct SubscriptionView<P: Publisher, Content: View>: View
                where P.Failure == Never
{
  public typealias Body = Never
  
  let publisher : P
  let action    : ( P.Output ) -> Void
  let view      : Content
  
  init(publisher: P, action: @escaping ( P.Output ) -> Void, view: Content) {
    self.publisher = publisher
    self.action    = action
    self.view      = view
  }
}


extension SubscriptionView: TreeBuildingView {
  func buildTree(in context: TreeStateContext) -> HTMLTreeNode {
    return context.currentBuilder.buildTree(for: self, in: context)
  }
}


extension HTMLTreeBuilder {
  
  func buildTree<P: Publisher, Content: View>(
         for view: SubscriptionView<P, Content>,
         in context: TreeStateContext) -> HTMLTreeNode
       where P.Failure == Never
  {
    context.appendContentElementIDComponent()
    let childTree = buildTree(for: view.view, in: context)
    context.deleteLastElementIDComponent()
    
    let tree = SubscriptionNode(elementID : context.currentElementID,
                                publisher : view.publisher,
                                action    : view.action,
                                content   : childTree)
    tree.resume(context: context)
    return tree
  }
}

final class SubscriptionNode<P: Publisher>: HTMLWrappingNode
              where P.Failure == Never
{
  let elementID    : ElementID
  let publisher    : P
  var subscription : AnyCancellable?
  let action       : ( P.Output ) -> Void
  let content      : HTMLTreeNode
  var value        : P.Output?
  
  init(elementID: ElementID, publisher: P,
       subscription: AnyCancellable? = nil,
       action: @escaping ( P.Output ) -> Void,
       content: HTMLTreeNode)
  {
    self.elementID    = elementID
    self.publisher    = publisher
    self.subscription = subscription
    self.action       = action
    self.content      = content
  }
    
   
    func generateHTML(into html: inout String) {
      // TBD: We could use <h1> etc, but this makes it harder to update?
      html += "<div"
      
      html.appendAttribute("id", elementID.webID)
      html += ">"
        html += "<script language='javascript'>setInterval(() => {console.log(\"this is the the message for: \(elementID.webID) \"); SwiftUI.valueCommit('\(elementID.webID)')}, 1000);</script>"
      defer { html += "</div>" }
      
        self.content.generateHTML(into: &html)
    }
  
  func invoke(_ webID: [String], in context: TreeStateContext) throws {
    guard elementID.isContainedInWebID(webID) else { return }
    if elementID.count == webID.count {
        if let value = self.value {
            action(value)
        }
    }
    else {
      try content.invoke(webID, in: context)
    }
  }
  
  func resume(context: TreeStateContext) {
    subscription?.cancel()
    let v = publisher.sink { [weak self] value in
        self?.value = value
        if let eid = self?.elementID {
            context.invalidateComponentWithID(eid)
        }
    }
    self.subscription = AnyCancellable(v)
  }
  
  func nodeByApplyingNewContent(_ newContent: HTMLTreeNode) -> SubscriptionNode
  {
    // TBD: Create a new subscription or reuse the old?
    return SubscriptionNode(elementID    : elementID,
                            publisher    : publisher,
                            subscription : subscription, // reuse old subscription
                            action       : action,
                            content      : newContent)
  }
}

#if DEBUG && false
fileprivate class MyStoreSubView: ObservableObject {
  static let global = MyStoreSubView()
  var didChange = PassthroughSubject<Void, Never>()
  var i = 5 { didSet { didChange.send(()) } }
  
}
fileprivate struct MySubView : View {
  var body: some View {
    Text("Blub")
      .onReceive(MyStoreSubView.global.didChange) { print("blub") }
  }
}
#endif

#endif // canImport(Combine)
