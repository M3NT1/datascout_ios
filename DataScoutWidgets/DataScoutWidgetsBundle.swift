import WidgetKit
import SwiftUI

@main
struct DataScoutWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DataScoutWidget()
        if #available(iOS 18.0, *) {
            DataScoutControlWidget()
        }
    }
}
