var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-pjvkfm/strip-cf-connecting-ip-header.js
function stripCfConnectingIPHeader(input, init) {
  const request = new Request(input, init);
  request.headers.delete("CF-Connecting-IP");
  return request;
}
__name(stripCfConnectingIPHeader, "stripCfConnectingIPHeader");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    return Reflect.apply(target, thisArg, [
      stripCfConnectingIPHeader.apply(null, argArray)
    ]);
  }
});

// node_modules/itty-router/index.mjs
var t = /* @__PURE__ */ __name(({ base: e = "", routes: t2 = [], ...r2 } = {}) => ({ __proto__: new Proxy({}, { get: (r3, o2, a, s) => (r4, ...c) => t2.push([o2.toUpperCase?.(), RegExp(`^${(s = (e + r4).replace(/\/+(\/|$)/g, "$1")).replace(/(\/?\.?):(\w+)\+/g, "($1(?<$2>*))").replace(/(\/?\.?):(\w+)/g, "($1(?<$2>[^$1/]+?))").replace(/\./g, "\\.").replace(/(\/?)\*/g, "($1.*)?")}/*$`), c, s]) && a }), routes: t2, ...r2, async fetch(e2, ...o2) {
  let a, s, c = new URL(e2.url), n = e2.query = { __proto__: null };
  for (let [e3, t3] of c.searchParams)
    n[e3] = n[e3] ? [].concat(n[e3], t3) : t3;
  e:
    try {
      for (let t3 of r2.before || [])
        if (null != (a = await t3(e2.proxy ?? e2, ...o2)))
          break e;
      t:
        for (let [r3, n2, l, i] of t2)
          if ((r3 == e2.method || "ALL" == r3) && (s = c.pathname.match(n2))) {
            e2.params = s.groups || {}, e2.route = i;
            for (let t3 of l)
              if (null != (a = await t3(e2.proxy ?? e2, ...o2)))
                break t;
          }
    } catch (t3) {
      if (!r2.catch)
        throw t3;
      a = await r2.catch(t3, e2.proxy ?? e2, ...o2);
    }
  try {
    for (let t3 of r2.finally || [])
      a = await t3(a, e2.proxy ?? e2, ...o2) ?? a;
  } catch (t3) {
    if (!r2.catch)
      throw t3;
    a = await r2.catch(t3, e2.proxy ?? e2, ...o2);
  }
  return a;
} }), "t");
var r = /* @__PURE__ */ __name((e = "text/plain; charset=utf-8", t2) => (r2, o2 = {}) => {
  if (void 0 === r2 || r2 instanceof Response)
    return r2;
  const a = new Response(t2?.(r2) ?? r2, o2.url ? void 0 : o2);
  return a.headers.set("content-type", e), a;
}, "r");
var o = r("application/json; charset=utf-8", JSON.stringify);
var p = r("text/plain; charset=utf-8", String);
var f = r("text/html");
var u = r("image/jpeg");
var h = r("image/png");
var g = r("image/webp");

// src/middleware/cors.js
function handleCORS(request) {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Account-ID",
    "Access-Control-Max-Age": "86400"
  };
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders
    });
  }
  request.corsHeaders = corsHeaders;
}
__name(handleCORS, "handleCORS");

// src/utils/helpers.js
function generateId() {
  return crypto.randomUUID();
}
__name(generateId, "generateId");

// src/utils/auth.js
function generateSessionToken() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
__name(generateSessionToken, "generateSessionToken");

// src/routes/auth.js
function authRoutes(router2) {
  router2.post("/api/auth/oauth/callback", async (request, env) => {
    try {
      const {
        provider,
        code,
        oauth_id,
        email,
        name,
        avatar_url,
        access_token,
        refresh_token,
        expires_in
      } = await request.json();
      if (!provider || !oauth_id || !email) {
        return new Response(JSON.stringify({
          error: "Missing required OAuth data",
          message: "provider, oauth_id, and email are required"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      let account = await env.DB.prepare(`
                SELECT * FROM accounts 
                WHERE oauth_provider = ? AND oauth_id = ?
            `).bind(provider, oauth_id).first();
      const now = Math.floor(Date.now() / 1e3);
      if (!account) {
        const existingAccount = await env.DB.prepare(
          "SELECT id FROM accounts WHERE email = ?"
        ).bind(email).first();
        if (existingAccount) {
          await env.DB.prepare(`
                        UPDATE accounts 
                        SET oauth_provider = ?, oauth_id = ?, avatar_url = ?, updated_at = ?
                        WHERE email = ?
                    `).bind(provider, oauth_id, avatar_url, now, email).run();
          account = await env.DB.prepare(
            "SELECT * FROM accounts WHERE email = ?"
          ).bind(email).first();
        } else {
          const accountId = generateId();
          const username = email.split("@")[0];
          await env.DB.prepare(`
                        INSERT INTO accounts (
                            id, username, email, display_name, oauth_provider, 
                            oauth_id, avatar_url, created_at, updated_at
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `).bind(
            accountId,
            username,
            email,
            name || username,
            provider,
            oauth_id,
            avatar_url,
            now,
            now
          ).run();
          account = await env.DB.prepare(
            "SELECT * FROM accounts WHERE id = ?"
          ).bind(accountId).first();
        }
      } else {
        await env.DB.prepare(`
                    UPDATE accounts 
                    SET email = ?, display_name = ?, avatar_url = ?, updated_at = ?
                    WHERE id = ?
                `).bind(email, name || account.display_name, avatar_url, now, account.id).run();
      }
      if (access_token) {
        const tokenId = generateId();
        const expiresAt = expires_in ? now + expires_in : null;
        await env.DB.prepare(`
                    INSERT OR REPLACE INTO oauth_tokens (
                        id, account_id, provider, access_token, refresh_token, 
                        expires_at, created_at, updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                `).bind(
          tokenId,
          account.id,
          provider,
          access_token,
          refresh_token,
          expiresAt,
          now,
          now
        ).run();
      }
      const sessionToken = generateSessionToken();
      const sessionId = generateId();
      const sessionExpiresAt = now + 30 * 24 * 60 * 60;
      await env.DB.prepare(`
                INSERT INTO sessions (
                    id, account_id, session_token, expires_at, created_at, 
                    user_agent, ip_address
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).bind(
        sessionId,
        account.id,
        sessionToken,
        sessionExpiresAt,
        now,
        request.headers.get("User-Agent") || "",
        request.headers.get("CF-Connecting-IP") || ""
      ).run();
      const response = {
        account: {
          id: account.id,
          username: account.username,
          email: account.email,
          display_name: account.display_name,
          handle: account.handle,
          avatar_url: account.avatar_url,
          needs_handle: !account.handle
        },
        session: {
          token: sessionToken,
          expires_at: sessionExpiresAt
        }
      };
      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("OAuth callback error:", error);
      return new Response(JSON.stringify({
        error: "OAuth authentication failed",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.post("/api/auth/complete-setup", async (request, env, ctx) => {
    try {
      const authResult = await authenticateSession(request, env);
      if (authResult instanceof Response)
        return authResult;
      const { handle } = await request.json();
      if (!handle) {
        return new Response(JSON.stringify({
          error: "Handle required",
          message: "handle is required"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      if (!/^[a-zA-Z0-9_]{3,20}$/.test(handle)) {
        return new Response(JSON.stringify({
          error: "Invalid handle",
          message: "Handle must be 3-20 characters, alphanumeric and underscore only"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const existingHandle = await env.DB.prepare(
        "SELECT id FROM accounts WHERE handle = ? AND id != ?"
      ).bind(handle, request.account.id).first();
      if (existingHandle) {
        return new Response(JSON.stringify({
          error: "Handle taken",
          message: "This handle is already taken"
        }), {
          status: 409,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const now = Math.floor(Date.now() / 1e3);
      await env.DB.prepare(`
                UPDATE accounts 
                SET handle = ?, updated_at = ?
                WHERE id = ?
            `).bind(handle, now, request.account.id).run();
      const account = await env.DB.prepare(
        "SELECT id, username, email, display_name, handle, avatar_url FROM accounts WHERE id = ?"
      ).bind(request.account.id).first();
      return new Response(JSON.stringify(account), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Complete setup error:", error);
      return new Response(JSON.stringify({
        error: "Failed to complete setup",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/auth/check-handle/:handle", async (request, env) => {
    try {
      const handle = request.params.handle;
      if (!/^[a-zA-Z0-9_]{3,20}$/.test(handle)) {
        return new Response(JSON.stringify({
          available: false,
          message: "Invalid handle format"
        }), {
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const existingHandle = await env.DB.prepare(
        "SELECT id FROM accounts WHERE handle = ?"
      ).bind(handle).first();
      return new Response(JSON.stringify({
        available: !existingHandle,
        message: existingHandle ? "Handle is taken" : "Handle is available"
      }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Check handle error:", error);
      return new Response(JSON.stringify({
        available: false,
        message: "Error checking handle"
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.post("/api/auth/logout", async (request, env) => {
    try {
      const sessionToken = request.headers.get("Authorization")?.replace("Bearer ", "");
      if (sessionToken) {
        await env.DB.prepare(
          "DELETE FROM sessions WHERE session_token = ?"
        ).bind(sessionToken).run();
      }
      return new Response(JSON.stringify({ success: true }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Logout error:", error);
      return new Response(JSON.stringify({
        error: "Logout failed",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.post("/api/auth/refresh", async (request, env) => {
    try {
      const { refresh_token } = await request.json();
      if (!refresh_token) {
        return new Response(JSON.stringify({
          error: "Refresh token required"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const tokenRecord = await env.DB.prepare(`
                SELECT t.*, a.* FROM oauth_tokens t
                JOIN accounts a ON t.account_id = a.id
                WHERE t.refresh_token = ?
            `).bind(refresh_token).first();
      if (!tokenRecord) {
        return new Response(JSON.stringify({
          error: "Invalid refresh token"
        }), {
          status: 401,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const sessionToken = generateSessionToken();
      const sessionId = generateId();
      const now = Math.floor(Date.now() / 1e3);
      const sessionExpiresAt = now + 30 * 24 * 60 * 60;
      await env.DB.prepare(`
                INSERT INTO sessions (
                    id, account_id, session_token, expires_at, created_at
                )
                VALUES (?, ?, ?, ?, ?)
            `).bind(sessionId, tokenRecord.account_id, sessionToken, sessionExpiresAt, now).run();
      return new Response(JSON.stringify({
        session: {
          token: sessionToken,
          expires_at: sessionExpiresAt
        },
        account: {
          id: tokenRecord.account_id,
          username: tokenRecord.username,
          handle: tokenRecord.handle,
          display_name: tokenRecord.display_name,
          avatar_url: tokenRecord.avatar_url
        }
      }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Refresh session error:", error);
      return new Response(JSON.stringify({
        error: "Failed to refresh session",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
}
__name(authRoutes, "authRoutes");
async function authenticateSession(request, env) {
  const authHeader = request.headers.get("Authorization");
  const sessionToken = authHeader?.replace("Bearer ", "");
  if (!sessionToken) {
    return new Response(JSON.stringify({
      error: "Authentication required",
      message: "Authorization header with session token is required"
    }), {
      status: 401,
      headers: {
        "Content-Type": "application/json",
        ...request.corsHeaders
      }
    });
  }
  try {
    const session = await env.DB.prepare(`
            SELECT s.*, a.id as account_id, a.username, a.display_name, a.handle, a.email
            FROM sessions s
            JOIN accounts a ON s.account_id = a.id
            WHERE s.session_token = ? AND s.expires_at > ?
        `).bind(sessionToken, Math.floor(Date.now() / 1e3)).first();
    if (!session) {
      return new Response(JSON.stringify({
        error: "Invalid session",
        message: "Session token is invalid or expired"
      }), {
        status: 401,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
    await env.DB.prepare(
      "UPDATE sessions SET last_used_at = ? WHERE id = ?"
    ).bind(Math.floor(Date.now() / 1e3), session.id).run();
    request.account = {
      id: session.account_id,
      username: session.username,
      display_name: session.display_name,
      handle: session.handle,
      email: session.email
    };
    return null;
  } catch (error) {
    console.error("Session auth error:", error);
    return new Response(JSON.stringify({
      error: "Authentication failed",
      message: "Database error during authentication"
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        ...request.corsHeaders
      }
    });
  }
}
__name(authenticateSession, "authenticateSession");

// src/routes/photos.js
function photoRoutes(router2) {
  router2.post("/api/photos", async (request, env) => {
    try {
      const {
        photo_data,
        latitude,
        longitude,
        location_name,
        caption
      } = await request.json();
      if (!photo_data) {
        return new Response(JSON.stringify({
          error: "Missing photo data",
          message: "photo_data field is required"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const photoId = generateId();
      const accountId = request.account.id;
      const now = Math.floor(Date.now() / 1e3);
      await env.DB.prepare(`
                INSERT INTO photos (id, account_id, photo_data, latitude, longitude, location_name, caption, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(
        photoId,
        accountId,
        JSON.stringify(photo_data),
        latitude,
        longitude,
        location_name,
        caption,
        now,
        now
      ).run();
      const followers = await env.DB.prepare(
        "SELECT follower_id FROM follows WHERE following_id = ?"
      ).bind(accountId).all();
      const timelinePromises = followers.results.map((follower) => {
        const timelineId = generateId();
        return env.DB.prepare(`
                    INSERT INTO photo_timeline (id, photo_id, account_id, visible_to_account_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                `).bind(timelineId, photoId, accountId, follower.follower_id, now).run();
      });
      const ownTimelineId = generateId();
      timelinePromises.push(
        env.DB.prepare(`
                    INSERT INTO photo_timeline (id, photo_id, account_id, visible_to_account_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                `).bind(ownTimelineId, photoId, accountId, accountId, now).run()
      );
      await Promise.all(timelinePromises);
      const photo = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name 
                FROM photos p
                JOIN accounts a ON p.account_id = a.id
                WHERE p.id = ?
            `).bind(photoId).first();
      return new Response(JSON.stringify({
        ...photo,
        photo_data: JSON.parse(photo.photo_data)
      }), {
        status: 201,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Create photo error:", error);
      return new Response(JSON.stringify({
        error: "Failed to create photo",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/photos/timeline", async (request, env) => {
    try {
      const url = new URL(request.url);
      const since = url.searchParams.get("since") || "0";
      const limit = Math.min(parseInt(url.searchParams.get("limit") || "50"), 100);
      const accountId = request.account.id;
      const photos = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name, pt.created_at as timeline_created_at
                FROM photo_timeline pt
                JOIN photos p ON pt.photo_id = p.id
                JOIN accounts a ON p.account_id = a.id
                WHERE pt.visible_to_account_id = ? AND pt.created_at > ?
                ORDER BY pt.created_at DESC
                LIMIT ?
            `).bind(accountId, parseInt(since), limit).all();
      const result = photos.results.map((photo) => ({
        ...photo,
        photo_data: JSON.parse(photo.photo_data)
      }));
      return new Response(JSON.stringify({
        photos: result,
        waterline: result.length > 0 ? result[0].timeline_created_at : since
      }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Get timeline error:", error);
      return new Response(JSON.stringify({
        error: "Failed to get timeline",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/photos/account/:accountId", async (request, env) => {
    try {
      const targetAccountId = request.params.accountId;
      const url = new URL(request.url);
      const limit = Math.min(parseInt(url.searchParams.get("limit") || "50"), 100);
      const offset = parseInt(url.searchParams.get("offset") || "0");
      const currentAccountId = request.account.id;
      let canView = targetAccountId === currentAccountId;
      if (!canView) {
        const follow = await env.DB.prepare(
          "SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?"
        ).bind(currentAccountId, targetAccountId).first();
        canView = !!follow;
      }
      if (!canView) {
        return new Response(JSON.stringify({
          error: "Permission denied",
          message: "You must follow this account to view their photos"
        }), {
          status: 403,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const photos = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name 
                FROM photos p
                JOIN accounts a ON p.account_id = a.id
                WHERE p.account_id = ?
                ORDER BY p.created_at DESC
                LIMIT ? OFFSET ?
            `).bind(targetAccountId, limit, offset).all();
      const result = photos.results.map((photo) => ({
        ...photo,
        photo_data: JSON.parse(photo.photo_data)
      }));
      return new Response(JSON.stringify(result), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Get photos by account error:", error);
      return new Response(JSON.stringify({
        error: "Failed to get photos",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/photos/:id", async (request, env) => {
    try {
      const photoId = request.params.id;
      const photo = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name 
                FROM photos p
                JOIN accounts a ON p.account_id = a.id
                WHERE p.id = ?
            `).bind(photoId).first();
      if (!photo) {
        return new Response(JSON.stringify({
          error: "Photo not found"
        }), {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const currentAccountId = request.account.id;
      let canView = photo.account_id === currentAccountId;
      if (!canView) {
        const follow = await env.DB.prepare(
          "SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?"
        ).bind(currentAccountId, photo.account_id).first();
        canView = !!follow;
      }
      if (!canView) {
        return new Response(JSON.stringify({
          error: "Permission denied",
          message: "You must follow this account to view their photos"
        }), {
          status: 403,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      return new Response(JSON.stringify({
        ...photo,
        photo_data: JSON.parse(photo.photo_data)
      }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Get photo error:", error);
      return new Response(JSON.stringify({
        error: "Failed to get photo",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.delete("/api/photos/:id", async (request, env) => {
    try {
      const photoId = request.params.id;
      const accountId = request.account.id;
      const photo = await env.DB.prepare(
        "SELECT account_id FROM photos WHERE id = ?"
      ).bind(photoId).first();
      if (!photo) {
        return new Response(JSON.stringify({
          error: "Photo not found"
        }), {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      if (photo.account_id !== accountId) {
        return new Response(JSON.stringify({
          error: "Permission denied",
          message: "You can only delete your own photos"
        }), {
          status: 403,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      await env.DB.prepare("DELETE FROM photos WHERE id = ?").bind(photoId).run();
      return new Response(JSON.stringify({ success: true }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Delete photo error:", error);
      return new Response(JSON.stringify({
        error: "Failed to delete photo",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
}
__name(photoRoutes, "photoRoutes");

// src/routes/follows.js
function followRoutes(router2) {
  router2.post("/api/follows", async (request, env) => {
    try {
      const { following_id } = await request.json();
      const follower_id = request.account.id;
      if (!following_id) {
        return new Response(JSON.stringify({
          error: "Missing following_id",
          message: "following_id is required"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      if (follower_id === following_id) {
        return new Response(JSON.stringify({
          error: "Cannot follow yourself"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const targetAccount = await env.DB.prepare(
        "SELECT id FROM accounts WHERE id = ?"
      ).bind(following_id).first();
      if (!targetAccount) {
        return new Response(JSON.stringify({
          error: "Account not found"
        }), {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const existingFollow = await env.DB.prepare(
        "SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?"
      ).bind(follower_id, following_id).first();
      if (existingFollow) {
        return new Response(JSON.stringify({
          error: "Already following this user"
        }), {
          status: 409,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const followId = generateId();
      const now = Math.floor(Date.now() / 1e3);
      await env.DB.prepare(`
                INSERT INTO follows (id, follower_id, following_id, created_at)
                VALUES (?, ?, ?, ?)
            `).bind(followId, follower_id, following_id, now).run();
      const existingPhotos = await env.DB.prepare(
        "SELECT id, created_at FROM photos WHERE account_id = ? ORDER BY created_at DESC LIMIT 100"
      ).bind(following_id).all();
      const timelinePromises = existingPhotos.results.map((photo) => {
        const timelineId = generateId();
        return env.DB.prepare(`
                    INSERT INTO photo_timeline (id, photo_id, account_id, visible_to_account_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                `).bind(timelineId, photo.id, following_id, follower_id, photo.created_at).run();
      });
      await Promise.all(timelinePromises);
      const follow = await env.DB.prepare(`
                SELECT f.*, a.username, a.display_name 
                FROM follows f
                JOIN accounts a ON f.following_id = a.id
                WHERE f.id = ?
            `).bind(followId).first();
      return new Response(JSON.stringify(follow), {
        status: 201,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Follow user error:", error);
      return new Response(JSON.stringify({
        error: "Failed to follow user",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.delete("/api/follows/:following_id", async (request, env) => {
    try {
      const following_id = request.params.following_id;
      const follower_id = request.account.id;
      const follow = await env.DB.prepare(
        "SELECT id FROM follows WHERE follower_id = ? AND following_id = ?"
      ).bind(follower_id, following_id).first();
      if (!follow) {
        return new Response(JSON.stringify({
          error: "Not following this user"
        }), {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      await env.DB.prepare(
        "DELETE FROM follows WHERE follower_id = ? AND following_id = ?"
      ).bind(follower_id, following_id).run();
      await env.DB.prepare(
        "DELETE FROM photo_timeline WHERE visible_to_account_id = ? AND account_id = ?"
      ).bind(follower_id, following_id).run();
      return new Response(JSON.stringify({ success: true }), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Unfollow user error:", error);
      return new Response(JSON.stringify({
        error: "Failed to unfollow user",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/follows/followers", async (request, env) => {
    try {
      const url = new URL(request.url);
      const accountId = url.searchParams.get("account_id") || request.account.id;
      const limit = Math.min(parseInt(url.searchParams.get("limit") || "50"), 100);
      const offset = parseInt(url.searchParams.get("offset") || "0");
      const followers = await env.DB.prepare(`
                SELECT f.created_at, a.id, a.username, a.display_name
                FROM follows f
                JOIN accounts a ON f.follower_id = a.id
                WHERE f.following_id = ?
                ORDER BY f.created_at DESC
                LIMIT ? OFFSET ?
            `).bind(accountId, limit, offset).all();
      return new Response(JSON.stringify(followers.results), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Get followers error:", error);
      return new Response(JSON.stringify({
        error: "Failed to get followers",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/follows/following", async (request, env) => {
    try {
      const url = new URL(request.url);
      const accountId = url.searchParams.get("account_id") || request.account.id;
      const limit = Math.min(parseInt(url.searchParams.get("limit") || "50"), 100);
      const offset = parseInt(url.searchParams.get("offset") || "0");
      const following = await env.DB.prepare(`
                SELECT f.created_at, a.id, a.username, a.display_name
                FROM follows f
                JOIN accounts a ON f.following_id = a.id
                WHERE f.follower_id = ?
                ORDER BY f.created_at DESC
                LIMIT ? OFFSET ?
            `).bind(accountId, limit, offset).all();
      return new Response(JSON.stringify(following.results), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Get following error:", error);
      return new Response(JSON.stringify({
        error: "Failed to get following",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/follows/search", async (request, env) => {
    try {
      const url = new URL(request.url);
      const query = url.searchParams.get("q");
      const limit = Math.min(parseInt(url.searchParams.get("limit") || "20"), 50);
      if (!query || query.length < 2) {
        return new Response(JSON.stringify({
          error: "Query too short",
          message: "Search query must be at least 2 characters"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const users = await env.DB.prepare(`
                SELECT a.id, a.username, a.display_name, a.bio,
                       CASE WHEN f.follower_id IS NOT NULL THEN 1 ELSE 0 END as is_following
                FROM accounts a
                LEFT JOIN follows f ON a.id = f.following_id AND f.follower_id = ?
                WHERE (a.username LIKE ? OR a.display_name LIKE ?) AND a.id != ?
                ORDER BY is_following DESC, a.username
                LIMIT ?
            `).bind(
        request.account.id,
        `%${query}%`,
        `%${query}%`,
        request.account.id,
        limit
      ).all();
      return new Response(JSON.stringify(users.results), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Search users error:", error);
      return new Response(JSON.stringify({
        error: "Failed to search users",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
}
__name(followRoutes, "followRoutes");

// src/routes/accounts.js
function accountRoutes(router2) {
  router2.post("/api/accounts", async (request, env) => {
    try {
      const { username, email, display_name, bio } = await request.json();
      if (!username || !email) {
        return new Response(JSON.stringify({
          error: "Missing required fields",
          message: "Username and email are required"
        }), {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const accountId = generateId();
      const now = Math.floor(Date.now() / 1e3);
      await env.DB.prepare(`
                INSERT INTO accounts (id, username, email, display_name, bio, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).bind(accountId, username, email, display_name || username, bio || "", now, now).run();
      const account = await env.DB.prepare(
        "SELECT id, username, email, display_name, bio, created_at FROM accounts WHERE id = ?"
      ).bind(accountId).first();
      return new Response(JSON.stringify(account), {
        status: 201,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Create account error:", error);
      return new Response(JSON.stringify({
        error: "Failed to create account",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.get("/api/accounts/:id", async (request, env) => {
    try {
      const accountId = request.params.id;
      const account = await env.DB.prepare(`
                SELECT id, username, display_name, bio, created_at,
                       (SELECT COUNT(*) FROM photos WHERE account_id = accounts.id) as photo_count,
                       (SELECT COUNT(*) FROM follows WHERE following_id = accounts.id) as follower_count,
                       (SELECT COUNT(*) FROM follows WHERE follower_id = accounts.id) as following_count
                FROM accounts WHERE id = ?
            `).bind(accountId).first();
      if (!account) {
        return new Response(JSON.stringify({
          error: "Account not found"
        }), {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      return new Response(JSON.stringify(account), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Get account error:", error);
      return new Response(JSON.stringify({
        error: "Failed to get account",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
  router2.put("/api/accounts/:id", async (request, env) => {
    try {
      const accountId = request.params.id;
      if (request.account.id !== accountId) {
        return new Response(JSON.stringify({
          error: "Permission denied",
          message: "You can only update your own account"
        }), {
          status: 403,
          headers: {
            "Content-Type": "application/json",
            ...request.corsHeaders
          }
        });
      }
      const { display_name, bio } = await request.json();
      const now = Math.floor(Date.now() / 1e3);
      await env.DB.prepare(`
                UPDATE accounts 
                SET display_name = ?, bio = ?, updated_at = ?
                WHERE id = ?
            `).bind(display_name, bio, now, accountId).run();
      const account = await env.DB.prepare(
        "SELECT id, username, email, display_name, bio, updated_at FROM accounts WHERE id = ?"
      ).bind(accountId).first();
      return new Response(JSON.stringify(account), {
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    } catch (error) {
      console.error("Update account error:", error);
      return new Response(JSON.stringify({
        error: "Failed to update account",
        message: error.message
      }), {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...request.corsHeaders
        }
      });
    }
  });
}
__name(accountRoutes, "accountRoutes");

// src/index.js
var router = t();
router.all("*", handleCORS);
router.get("/health", () => {
  return new Response(JSON.stringify({
    status: "ok",
    timestamp: (/* @__PURE__ */ new Date()).toISOString()
  }), {
    headers: { "Content-Type": "application/json" }
  });
});
authRoutes(router);
router.all("/api/accounts/*", authenticateSession);
accountRoutes(router);
router.all("/api/photos/*", authenticateSession);
photoRoutes(router);
router.all("/api/follows/*", authenticateSession);
followRoutes(router);
router.all("*", () => new Response("Not Found", { status: 404 }));
var src_default = {
  async fetch(request, env, ctx) {
    try {
      return await router.handle(request, env, ctx);
    } catch (error) {
      console.error("Worker error:", error);
      return new Response(JSON.stringify({
        error: "Internal server error",
        message: error.message
      }), {
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
    }
  }
};

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-pjvkfm/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-pjvkfm/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof __Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
__name(__Facade_ScheduledController__, "__Facade_ScheduledController__");
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = (request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    };
    #dispatcher = (type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    };
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
