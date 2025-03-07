import XCTestDynamicOverlay

extension FeedbackGeneratorClient {
  #if DEBUG
    public static let unimplemented = Self(
      prepare: XCTUnimplemented("\(Self.self).prepare"),
      selectionChanged: XCTUnimplemented("\(Self.self).selectionChanged")
    )
  #endif

  public static let noop = Self(
    prepare: {},
    selectionChanged: {}
  )
}
