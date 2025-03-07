import Combine
import ComposableArchitecture
import ComposableStoreKit
import SharedModels
import XCTest

@testable import ServerConfig
@testable import SettingsFeature

@MainActor
class SettingsPurchaseTests: XCTestCase {
  var defaultEnvironment: SettingsEnvironment {
    var environment = SettingsEnvironment.unimplemented
    environment.apiClient.baseUrl = { URL(string: "http://localhost:9876")! }
    environment.applicationClient.alternateIconName = { nil }
    environment.build.number = { 42 }
    environment.mainQueue = .immediate
    environment.backgroundQueue = .immediate
    environment.fileClient.save = { @Sendable _, _ in }
    environment.userNotifications.getNotificationSettings = {
      (try? await Task.never()) ?? .init(authorizationStatus: .notDetermined)
    }
    return environment
  }

  func testUpgrade_HappyPath() async throws {
    let didAddPaymentProductIdentifier = ActorIsolated<String?>(nil)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
    environment.storeKit.addPayment = {
      await didAddPaymentProductIdentifier.setValue($0.productIdentifier)
    }
    environment.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    environment.storeKit.observer = { storeKitObserver.stream }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.tappedProduct(.fullGame)) {
      $0.isPurchasing = true
    }
    await didAddPaymentProductIdentifier.withValue {
      XCTAssertNoDifference($0, "xyz.isowords.full_game")
    }
    storeKitObserver.continuation.yield(.updatedTransactions([.purchasing]))
    storeKitObserver.continuation.yield(.updatedTransactions([.purchased]))
    storeKitObserver.continuation.yield(.removedTransactions([.purchased]))

    await store.receive(.paymentTransaction(.updatedTransactions([.purchasing])))
    await store.receive(.paymentTransaction(.updatedTransactions([.purchased])))
    await store.receive(.paymentTransaction(.removedTransactions([.purchased]))) {
      $0.isPurchasing = false
    }
    await store.receive(.currentPlayerRefreshed(.success(.blobWithPurchase))) {
      $0.fullGamePurchasedAt = .mock
    }
    await task.cancel()
  }

  func testRestore_HappyPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.apiClient.refreshCurrentPlayer = { .blobWithPurchase }
    environment.storeKit.restoreCompletedTransactions = {
      await didRestoreCompletedTransactions.setValue(true)
    }
    environment.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    environment.storeKit.observer = { storeKitObserver.stream }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssertNoDifference($0, true) }
    storeKitObserver.continuation.yield(.updatedTransactions([.restored]))
    storeKitObserver.continuation.yield(.removedTransactions([.restored]))
    storeKitObserver.continuation.yield(
      .restoreCompletedTransactionsFinished(transactions: [.restored]))

    await store.receive(.paymentTransaction(.updatedTransactions([.restored])))
    await store.receive(.paymentTransaction(.removedTransactions([.restored])))
    await store.receive(.currentPlayerRefreshed(.success(.blobWithPurchase))) {
      $0.isRestoring = false
      $0.fullGamePurchasedAt = .mock
    }
    await store.receive(
      .paymentTransaction(.restoreCompletedTransactionsFinished(transactions: [.restored]))
    )
    await task.cancel()
  }

  func testRestore_NoPurchasesPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.storeKit.restoreCompletedTransactions = {
      await didRestoreCompletedTransactions.setValue(true)
    }
    environment.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    environment.storeKit.observer = { storeKitObserver.stream }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssertNoDifference($0, true) }
    storeKitObserver.continuation.yield(.restoreCompletedTransactionsFinished(transactions: []))

    await store.receive(
      .paymentTransaction(.restoreCompletedTransactionsFinished(transactions: []))
    ) {
      $0.isRestoring = false
      $0.alert = .noRestoredPurchases
    }

    await task.cancel()
  }

  func testRestore_ErrorPath() async throws {
    let didRestoreCompletedTransactions = ActorIsolated(false)
    let storeKitObserver = AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>
      .streamWithContinuation()

    var environment = self.defaultEnvironment
    environment.serverConfig.config = {
      .init(productIdentifiers: .init(fullGame: "xyz.isowords.full_game"))
    }
    environment.apiClient.currentPlayer = { .some(.blobWithoutPurchase) }
    environment.storeKit.restoreCompletedTransactions = {
      await didRestoreCompletedTransactions.setValue(true)
    }
    environment.storeKit.fetchProducts = { _ in
      .init(invalidProductIdentifiers: [], products: [.fullGame])
    }
    environment.storeKit.observer = { storeKitObserver.stream }

    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: environment
    )

    let task = await store.send(.task) {
      $0.buildNumber = 42
      $0.developer.currentBaseUrl = .localhost
    }
    await store.receive(
      .productsResponse(.success(.init(invalidProductIdentifiers: [], products: [.fullGame])))
    ) {
      $0.fullGameProduct = .success(.fullGame)
    }
    await store.send(.restoreButtonTapped) {
      $0.isRestoring = true
    }

    await didRestoreCompletedTransactions.withValue { XCTAssert($0) }

    let restoreCompletedTransactionsError = NSError(domain: "", code: 1)
    storeKitObserver.continuation
      .yield(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))

    await store.receive(
      .paymentTransaction(.restoreCompletedTransactionsFailed(restoreCompletedTransactionsError))
    ) {
      $0.isRestoring = false
      $0.alert = .restoredPurchasesFailed
    }

    await task.cancel()
  }
}

extension CurrentPlayerEnvelope {
  static let blobWithPurchase = Self(appleReceipt: .mock, player: .blob)
  static let blobWithoutPurchase = Self(appleReceipt: nil, player: .blob)
}

extension StoreKitClient.Payment {
  static let fullGame = Self(
    applicationUsername: nil,
    productIdentifier: "xyz.isowords.full_game",
    quantity: 1,
    requestData: nil,
    simulatesAskToBuyInSandbox: false
  )
}

extension StoreKitClient.PaymentTransaction {
  static let purchasing = Self(
    error: nil,
    original: nil,
    payment: .fullGame,
    rawValue: nil,
    transactionDate: .mock,
    transactionIdentifier: "deadbeef",
    transactionState: .purchasing
  )
  static let purchased = Self(
    error: nil,
    original: nil,
    payment: .fullGame,
    rawValue: nil,
    transactionDate: .mock,
    transactionIdentifier: "deadbeef",
    transactionState: .purchased
  )
  static let restored = Self(
    error: nil,
    original: nil,
    payment: .fullGame,
    rawValue: nil,
    transactionDate: .mock,
    transactionIdentifier: "deadbeef",
    transactionState: .restored
  )
}

extension StoreKitClient.Product {
  static let fullGame = Self(
    downloadContentLengths: [],
    downloadContentVersion: "",
    isDownloadable: false,
    localizedDescription: "Full game",
    localizedTitle: "Full game",
    price: 5,
    priceLocale: .init(identifier: "en_US"),
    productIdentifier: "xyz.isowords.full_game"
  )
}
