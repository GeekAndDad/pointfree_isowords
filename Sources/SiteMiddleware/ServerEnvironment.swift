import DatabaseClient
import DictionaryClient
import EnvVars
import Foundation
import MailgunClient
import Overture
import ServerConfig
import ServerRouter
import SharedModels
import SnsClient
import URLRouting
import VerifyReceiptMiddleware

public struct ServerEnvironment {
  public var changelog: () -> Changelog
  public var database: DatabaseClient
  public var date: () -> Date
  public var dictionary: DictionaryClient
  public var itunes: ItunesClient
  public var envVars: EnvVars
  public var mailgun: MailgunClient
  public var randomCubes: () -> ArchivablePuzzle
  public var router: ServerRouter
  public var snsClient: SnsClient

  public init(
    changelog: @escaping () -> Changelog,
    database: DatabaseClient,
    date: @escaping () -> Date,
    dictionary: DictionaryClient,
    envVars: EnvVars,
    itunes: ItunesClient,
    mailgun: MailgunClient,
    randomCubes: @escaping () -> ArchivablePuzzle,
    router: ServerRouter,
    snsClient: SnsClient
  ) {
    self.changelog = changelog
    self.database = database
    self.date = date
    self.dictionary = dictionary
    self.envVars = envVars
    self.itunes = itunes
    self.mailgun = mailgun
    self.randomCubes = randomCubes
    self.router = router
    self.snsClient = snsClient
  }
}

#if DEBUG
  import XCTestDynamicOverlay

  extension ServerEnvironment {
    public static let unimplemented = Self(
      changelog: XCTUnimplemented("\(Self.self).changelog", placeholder: .current),
      database: .unimplemented,
      date: XCTUnimplemented("\(Self.self).date", placeholder: Date()),
      dictionary: .unimplemented,
      envVars: EnvVars(appEnv: .testing),
      itunes: .unimplemented,
      mailgun: .unimplemented,
      randomCubes: XCTUnimplemented("\(Self.self).randomCubes", placeholder: .mock),
      router: .unimplemented,
      snsClient: .unimplemented
    )
  }
#endif
