import Vapor
import Fluent
import FluentPostgresDriver
import Imperial

public func configure(_ app: Application) throws {
    // Serve files from /Public folder
    if let publicDirectory = try? app.directory.publicDirectory {
        app.middleware.use(FileMiddleware(publicDirectory: publicDirectory))
    }

    // Set up databases
    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tlsConfiguration: .forClient(certificateVerification: .none)
    ), as: .psql)

    // Set up migrations
    app.migrations.add(CreateTodo())

    // Register routes
    try routes(app)

    // Register the OAuth provider using Imperial
    try app.oAuth.register(
        provider: .microsoft,
        clientId: Environment.get("MICROSOFT_CLIENT_ID") ?? "Client ID not found",
        clientSecret: Environment.get("MICROSOFT_CLIENT_SECRET") ?? "Client secret not found",
        completion: { request, response in
            // Handle the response, save the token, etc.
            // Implementation will vary based on how you want to handle the OAuth flow
        }
    )
}
