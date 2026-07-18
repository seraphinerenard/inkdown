import SwiftUI

/// Document outline: the heading tree, indented by level. Selecting a heading
/// jumps the editor (and, via the bridge, the preview) to that source line.
struct OutlineView: View {
    let text: String
    var onSelect: (Int) -> Void

    var body: some View {
        let headings = DocumentOutline.headings(from: text)
        if headings.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "list.bullet.indent")
                    .font(.system(size: 26)).foregroundStyle(.tertiary)
                Text("No headings").font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(headings) { heading in
                Button {
                    onSelect(heading.line)
                } label: {
                    Text(heading.title)
                        .font(.system(size: heading.level <= 1 ? 13 : 12,
                                      weight: heading.level <= 2 ? .semibold : .regular))
                        .foregroundStyle(heading.level <= 2 ? .primary : .secondary)
                        .lineLimit(1)
                        .padding(.leading, CGFloat((heading.level - 1) * 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            }
            .listStyle(.sidebar)
        }
    }
}
