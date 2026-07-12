import SwiftUI
import UIKit

enum Format {
    /// Whole kcal, no decimals: 2415 -> "2415".
    static func kcal(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    /// Swiss-style grouped integer used for the big dashboard number: 2415 -> "2'415".
    static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "'"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value.rounded())) ?? String(Int(value.rounded()))
    }

    /// One decimal place for grams: 150.72 -> "150.7".
    static func grams(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Weight in the user's unit system: kg as-is, or converted to lb.
    static func weight(_ kg: Double, units: UnitSystem) -> String {
        switch units {
        case .metric: return "\(grams(kg)) kg"
        case .imperial: return "\(grams(kg * 2.2046226218)) lb"
        }
    }
}

/// Reusable "not implemented yet" alert modifier.
struct ComingSoonModifier: ViewModifier {
    @Binding var isPresented: Bool
    func body(content: Content) -> some View {
        content.alert("COMING SOON", isPresented: $isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This feature isn't available yet.")
        }
    }
}

extension View {
    func comingSoon(_ isPresented: Binding<Bool>) -> some View {
        modifier(ComingSoonModifier(isPresented: isPresented))
    }

    /// Adds a "Done" button above the keyboard so numeric-pad inputs (which have
    /// no return key) can always be dismissed.
    func keyboardDoneToolbar() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}

/// Toolbar with a trailing Done button shown whenever the keyboard is up.
struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

/// Time-of-day greeting for the dashboard header.
func greeting(for date: Date = Date()) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 5..<12: return "Good Morning"
    case 12..<18: return "Good Afternoon"
    case 18..<22: return "Good Evening"
    default: return "Good Night"
    }
}
