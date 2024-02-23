import Vapor
import Fluent
import Authentication

func routes(_ app: Application) throws {
    
    // Route to initiate the OAuth login flow
    app.get("login") { req -> Response in
        // Replace with the URL provided by Microsoft's OAuth documentation
        let microsoftOAuthURL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=\(Environment.get("Client") ?? "")&response_type=code&redirect_uri=\(Environment.get("MICROSOFT_REDIRECT_URI") ?? "")&response_mode=query&scope=user.read"
        
        return req.redirect(to: microsoftOAuthURL)
    }

    // Callback route to handle the redirect after Microsoft authentication
    app.get("auth", "microsoft", "callback") { req -> EventLoopFuture<Response> in
        guard let code = req.query["code"] else {
            throw Abort(.badRequest, reason: "Missing 'code' in request")
        }

        // Construct the request to Microsoft's token endpoint
        let tokenRequestURL = URI(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")
        let tokenRequestBody = TokenRequest(
            client_id: Environment.get("MICROSOFT_CLIENT_ID") ?? "",
            scope: "user.read", // The scopes you've requested
            code: code,
            redirect_uri: Environment.get("MICROSOFT_REDIRECT_URI") ?? "",
            grant_type: "authorization_code",
            client_secret: Environment.get("MICROSOFT_CLIENT_SECRET") ?? ""
        )

        // Send a POST request to Microsoft's token endpoint with the necessary data
        return req.client.post(tokenRequestURL, beforeSend: { request in
            try request.content.encode(tokenRequestBody, as: .urlEncodedForm)
        }).flatMapThrowing { response in
            // Check for a successful status code from the token endpoint
            guard response.status == .ok else {
                if let body = response.body {
                    let errorResponse = String(buffer: body)
                    throw Abort(.unauthorized, reason: "Microsoft token endpoint returned error: \(errorResponse)")
                } else {
                    throw Abort(.unauthorized, reason: "Unknown error from Microsoft token endpoint")
                }
            }

            // Decode the JSON response into a TokenResponse struct
            let tokenData = try response.content.decode(TokenResponse.self)

            // Here, you will store the tokenData in your database associated with the user's session
            // This will depend on your user session implementation
            // ...

            // For now, we'll redirect to a success message, but in a real app, you'd likely handle this differently
            return req.redirect(to: "/auth/success")
        }
    }

    // A simple route for testing the success of the OAuth flow
    app.get("auth", "success") { req -> String in
        return "Authentication with Microsoft successful!"
    }
}

// A helper struct to encode the token request
struct TokenRequest: Content {
    let client_id: String
    let scope: String
    let code: String
    let redirect_uri: String
    let grant_type: String
    let client_secret: String
}

// A helper struct to decode the token response
struct TokenResponse: Content {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String
    let idToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case idToken = "id_token"
    }
}
