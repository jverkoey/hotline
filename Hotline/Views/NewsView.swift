import SwiftUI
import UniformTypeIdentifiers



struct NewsItemView: View {
  @Environment(Hotline.self) private var model: Hotline
  @Environment(NewsItemSelection.self) private var selectedArticle: NewsItemSelection
  
  let news: NewsInfo
  
  @State var expanded = false
  
  var body: some View {
    if news.count > 0 {
      DisclosureGroup(isExpanded: $expanded) {
        ForEach(news.children) { childNews in
          NewsItemView(news: childNews)
            .environment(self.selectedArticle)
            .frame(height: 38)
        }
      } label: {
        HStack {
          if news.type == .bundle {
            Text(Image(systemName: "tray.2.fill"))
          }
          else {
            Text(Image(systemName: "tray.full.fill"))
          }
          Text(news.name)
            .fontWeight(.medium)
            .lineLimit(1)
            .truncationMode(.tail)
          Spacer()
          if news.count > 0 {
            Text("\(news.count)")
              .foregroundStyle(.secondary)
          }
        }
      }
      .onChange(of: expanded) {
        if !expanded {
          return
        }
        
        Task {
          await model.getNewsList(at: news.path)
        }
      }
    }
    else {
      HStack {
        Text(Image(systemName: "doc.text"))
        Text(news.name)
          .fontWeight(.medium)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer()
        if news.count > 0 {
          Text("\(news.count)")
            .foregroundStyle(.secondary)
        }
      }
      .onTapGesture {
        if news.type == .article {
          print("SELECTED", news.name)
          selectedArticle.selectedArticle = news
        }
      }
    }
  }
}

@Observable
class NewsItemSelection: Equatable {
  var selectedArticle: NewsInfo? = nil
  
  static func == (lhs: NewsItemSelection, rhs: NewsItemSelection) -> Bool {
    return lhs.selectedArticle == rhs.selectedArticle
  }
}

struct NewsView: View {
  @Environment(Hotline.self) private var model: Hotline
  @Environment(\.colorScheme) var colorScheme
  
  @State private var fetched = false
  @State private var selectedCategory: NewsInfo? = nil
  @State private var topListHeight: CGFloat = 200
  @State private var dividerHeight: CGFloat = 30
  
  @State private var articleSelection = NewsItemSelection()
  @State private var articleText = ""
//  @State private var selectedArticleID: UInt?
  
  var articleList: some View {
    VStack(spacing: 0) {
      if model.news.count == 0 {
        Text("No News Available")
          .font(.headline)
          .opacity(0.3)
      }
      else {
        List(model.news) { category in
          NewsItemView(news: category)
            .environment(self.articleSelection)
            .frame(height: 38)
        }
        .scrollBounceBehavior(.basedOnSize)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
    
    //    .listStyle(.plain)
  }
    
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        articleList
          .frame(height: topListHeight)
          .frame(minHeight: topListHeight)
          .onChange(of: self.articleSelection.selectedArticle) {
            self.articleText = ""
            if
              let article = self.articleSelection.selectedArticle,
              let articleFlavor = article.articleFlavors?.first,
              let articleID = article.articleID {
              Task {
                if let articleText = await self.model.getNewsArticle(id: articleID, at: article.path, flavor: articleFlavor) {
                  self.articleText = articleText
                }
              }
            }
//            print("SELECTED ARTICLE", articleSelection.selectedArticle?.name)
          }
        
        // Movable Divider
        VStack(alignment: .center) {
          Divider()
          Spacer()
          HStack(alignment: .center) {
            Rectangle()
              .fill(.tertiary)
              .frame(width: 50, height: 6, alignment: .center)
              .cornerRadius(10)
          }
          Spacer()
        }
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(uiColor: UIColor.systemBackground))
        .frame(maxWidth: .infinity)
        .frame(height: dividerHeight)
        .gesture(
          DragGesture()
            .onChanged { gesture in
              let delta = gesture.translation.height
              topListHeight = max(min(topListHeight + delta, 500), 50)
            }
        )
        
        // Reader View
        ScrollView(.vertical) {
          HStack(alignment: .top, spacing: 0) {
            Text(self.articleText)
              .multilineTextAlignment(.leading)
            Spacer()
          }
          .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(uiColor: UIColor.systemBackground))
      }
      .task {
        if !fetched {
          let _ = await model.getNewsList()
          fetched = true
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(model.serverTitle)
            .font(.headline)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            model.disconnect()
          } label: {
            Text(Image(systemName: "xmark.circle.fill"))
              .symbolRenderingMode(.hierarchical)
              .font(.title2)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }
}

#Preview {
  MessageBoardView()
    .environment(HotlineState())
    .environment(Hotline(trackerClient: HotlineTrackerClient(), client: HotlineClient()))
}
