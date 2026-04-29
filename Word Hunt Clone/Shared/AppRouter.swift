import Foundation
import Combine

enum AppScreen: Equatable {
    case menu
    case wordHunt
    case wordBites
}

final class AppRouter: ObservableObject {
    @Published var screen: AppScreen = .menu

    func goToMenu() { screen = .menu }
    func go(_ s: AppScreen) { screen = s }
}
