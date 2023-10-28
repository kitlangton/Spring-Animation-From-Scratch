import Observation
import SwiftUI

struct CirclesView: View {
  var offset: CGPoint

  var body: some View {
    ZStack {
      Circle().fill(.tertiary).frame(width: 50, height: 50).offset(y: -200)
      Circle().fill(.tertiary).frame(width: 100, height: 100).offset(y: 200)

      Circle()
        .fill(.black)
        .stroke(.primary, lineWidth: 8)
        .frame(width: offset.x, height: offset.x)
        .offset(y: offset.y)
    }
  }
}

@propertyWrapper
struct Animated<Value: SpringValueProtocol>: DynamicProperty {
  init(wrappedValue: Value) {
    springDouble = SpringValue(value: wrappedValue)
  }

  @State var springDouble: SpringValue<Value>

  var wrappedValue: Value {
    get {
      springDouble.value
    }

    nonmutating set {
      springDouble.animate(to: newValue)
    }
  }

  var projectedValue: SpringValue<Value> {
    springDouble
  }
}

protocol SpringValueProtocol {
  static func - (lhs: Self, rhs: Self) -> Self

  static func + (lhs: Self, rhs: Self) -> Self

  static func += (lhs: inout Self, rhs: Self)

  func scaled(by scalar: Double) -> Self

  static var zero: Self { get }

  var magnitudeSquared: Double { get }
}

extension Double: SpringValueProtocol {
//  static func - (lhs: Double, rhs: Double) -> Double {
//    lhs - rhs
//  }
//
//  static func + (lhs: Double, rhs: Double) -> Double {
//    lhs + rhs
//  }
//
//  static func += (lhs: inout Double, rhs: Double) {
//    lhs += rhs
//  }

  func scaled(by scalar: Double) -> Double {
    self * scalar
  }

  static var zero: Double {
    0
  }
}

extension CGPoint: SpringValueProtocol {
  static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }

  static func += (lhs: inout CGPoint, rhs: CGPoint) {
    lhs.x += rhs.x
    lhs.y += rhs.y
  }

  static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }

  func scaled(by scalar: Double) -> CGPoint {
    CGPoint(x: x * scalar, y: y * scalar)
  }

  static var zero: CGPoint {
    CGPoint(x: 0, y: 0)
  }

  var magnitudeSquared: Double {
    x * x + y * y
  }
}

@Observable
class SpringValue<Value: SpringValueProtocol>: AnimatedProtocol {
  init(value: Value) {
    self.value = value
    target = value
  }

  let id: UUID = .init()
  var value: Value
  var target: Value
  var velocity: Value = .zero

  let stiffness: Double = Spring().stiffness
  let damping: Double = Spring().damping

  let epsilon = 0.005

  var isDone: Bool {
    let displacement = value - target
    return velocity.magnitudeSquared < epsilon &&
      displacement.magnitudeSquared < epsilon
  }

  func animate(to: Value) {
    target = to
    AnimationManager.shared.addAnimation(self)
  }

  func update(timeDelta: Double) {
    let displacement: Value = value - target
    let springForce: Value = displacement.scaled(by: -stiffness) // HOOKE'S LAW
    let dampingForce: Value = velocity.scaled(by: -damping)

    let resultantForce = springForce + dampingForce
    let acceleration = resultantForce

    velocity += acceleration.scaled(by: timeDelta)
    value += velocity.scaled(by: timeDelta)
  }
}

protocol AnimatedProtocol {
  var id: UUID { get }
  var isDone: Bool { get }
  func update(timeDelta: TimeInterval)
}

@Observable
class AnimationManager {
  static let shared = AnimationManager()

  var animations: [UUID: AnimatedProtocol] = [:]

  func addAnimation(_ animation: AnimatedProtocol) {
    print("ADDING \(animation.id)")
    animations[animation.id] = animation
  }

  func step(timeDelta: TimeInterval) {
    for animation in animations.values {
      animation.update(timeDelta: timeDelta)
      print("STEPPING \(animation.id) \(timeDelta)")
      if animation.isDone {
        print("IS DONE - Removing Animation \(animation.id)")
        animations.removeValue(forKey: animation.id)
      }
    }
  }
}

struct AnimationManagerModifier: ViewModifier {
  @State var manager = AnimationManager.shared

  @State var lastRender: Date?

  func body(content: Content) -> some View {
    content
      .background {
        TimelineView(.animation(paused: manager.animations.isEmpty)) { context in
          Color.clear
            .onChange(of: context.date) {
              let timeDelta = context.date.timeIntervalSince(lastRender ?? Date())
              lastRender = context.date
              manager.step(timeDelta: timeDelta)
            }
        }
      }
      .onChange(of: manager.animations.isEmpty) {
        if $1 {
          lastRender = nil
        }
      }
  }
}

struct ContentView: View {
  @State var offset: CGPoint = .init(x: 100, y: 200)
  @Animated var offsetSpring: CGPoint = .init(x: 100, y: 200)

  @State var isBig: Bool = true

  var body: some View {
    HStack(spacing: 40) {
      CirclesView(offset: offset)
        .animation(.spring, value: offset)
      CirclesView(offset: offsetSpring)
    }
    .onTapGesture {
      if isBig {
        offset = CGPoint(x: 50, y: -200)
      } else {
        offset = CGPoint(x: 100, y: 200)
      }
      offsetSpring = offset
      isBig.toggle()
    }
    .modifier(AnimationManagerModifier())
  }
}

#Preview {
  ContentView()
}
