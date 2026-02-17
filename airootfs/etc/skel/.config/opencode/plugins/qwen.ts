import type { Hooks, PluginInput } from "@opencode-ai/plugin"
import os from "os"
import { spawn } from "child_process"

const OAUTH_DUMMY_KEY = "opencode-oauth-dummy-key"

const CLIENT_ID = "f0304373b74a44d2b584a3fb70ca9e56"
const DEVICE_CODE_ENDPOINT = "https://chat.qwen.ai/api/v1/oauth2/device/code"
const TOKEN_ENDPOINT = "https://chat.qwen.ai/api/v1/oauth2/token"
const DEFAULT_DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
const SCOPE = "openid profile email model.completion"

interface PkceCodes {
  verifier: string
  challenge: string
}

async function generatePKCE(): Promise<PkceCodes> {
  const verifier = generateRandomString(43)
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const hash = await crypto.subtle.digest("SHA-256", data)
  const challenge = base64UrlEncode(hash)
  return { verifier, challenge }
}

function generateRandomString(length: number): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  const bytes = crypto.getRandomValues(new Uint8Array(length))
  return Array.from(bytes)
    .map((b) => chars[b % chars.length])
    .join("")
}

function base64UrlEncode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  const binary = String.fromCharCode(...bytes)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

interface DeviceAuthResponse {
  device_code: string
  user_code: string
  verification_uri: string
  verification_uri_complete: string
  expires_in: number
  interval: number
}

async function requestDeviceAuthorization(pkce: PkceCodes): Promise<DeviceAuthResponse> {
  const response = await fetch(DEVICE_CODE_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({
      client_id: CLIENT_ID,
      scope: SCOPE,
      code_challenge: pkce.challenge,
      code_challenge_method: "S256",
    }).toString(),
  })

  if (!response.ok) {
    throw new Error(`Device authorization failed: ${response.status} ${await response.text()}`)
  }

  return response.json()
}

interface TokenResponse {
  access_token: string
  refresh_token: string
  expires_in: number
  token_type: string
  resource_url?: string
}

async function pollDeviceToken(deviceCode: string, codeVerifier: string): Promise<TokenResponse | "pending" | "slow_down"> {
  const response = await fetch(TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:device_code",
      client_id: CLIENT_ID,
      device_code: deviceCode,
      code_verifier: codeVerifier,
    }).toString(),
  })

  if (response.ok) {
    return response.json()
  }

  const errorData = await response.json().catch(() => ({}))
  if (errorData.error === "authorization_pending") return "pending"
  if (errorData.error === "slow_down") return "slow_down"

  throw new Error(`Token polling failed: ${errorData.error || response.status}`)
}

async function refreshAccessToken(refreshToken: string): Promise<TokenResponse> {
  const response = await fetch(TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: CLIENT_ID,
    }).toString(),
  })

  if (!response.ok) {
    throw new Error(`Token refresh failed: ${response.status} ${await response.text()}`)
  }

  return response.json()
}

function enhanceQwenErrorResponse(body: any, status: number): { body: any; retryAfterMs?: number } | null {
  if (status === 429) {
    const retryAfter = body?.error?.extra?.retry_after_ms
    const message = "Rate limit exceeded. Please retry shortly."
    return {
      body: {
        ...body,
        error: {
          ...body?.error,
          message,
        },
      },
      retryAfterMs: retryAfter,
    }
  }

  if (status === 400) {
    const errorText = JSON.stringify(body).toLowerCase()
    if (errorText.includes("quota") && errorText.includes("exceeded")) {
      return {
        body: {
          ...body,
          error: {
            ...body?.error,
            message: "Quota exhausted for this account. Please wait for your quota to reset or upgrade your plan.",
          },
        },
      }
    }
  }

  return null
}

export default async function QwenAuthPlugin(input: PluginInput): Promise<Hooks> {
  const registerQwenModel = (config: any, modelID: string, name: string) => {
    config.provider["qwen"].models[modelID] = {
      id: "coder-model",
      name: name,
      release_date: "2025-02-17",
      attachment: true,
      reasoning: true,
      temperature: true,
      tool_call: true,
      limit: {
        context: 1_000_000,
        input: 1_000_000,
        output: 65_500
      },
      provider: {
        npm: "@ai-sdk/openai-compatible",
        api: DEFAULT_DASHSCOPE_BASE_URL
      }
    }
  }

  return {
    config: async (config) => {
      config.provider ??= {}
      config.provider["qwen"] ??= {
        name: "Qwen",
        env: [],
        options: {},
        models: {}
      }
      config.provider["qwen"].models ??= {}
      
      registerQwenModel(config, "coder-model", "Qwen 3.5 Plus")
    },
    auth: {
      provider: "qwen",
      async loader(getAuth, provider) {
        return {
          apiKey: OAUTH_DUMMY_KEY,
          async fetch(requestInput: RequestInfo | URL, init?: RequestInit) {
            const currentAuth = await getAuth() as any
            if (!currentAuth || currentAuth.type !== "oauth") return fetch(requestInput, init)

            if (!currentAuth.access || currentAuth.expires < Date.now()) {
              try {
                const tokens = await refreshAccessToken(currentAuth.refresh)
                await input.client.auth.set({
                  path: { id: "qwen" },
                  body: {
                    type: "oauth",
                    refresh: tokens.refresh_token,
                    access: tokens.access_token,
                    expires: Date.now() + tokens.expires_in * 1000,
                    resource_url: tokens.resource_url
                  } as any,
                })
                currentAuth.access = tokens.access_token
                currentAuth.refresh = tokens.refresh_token
                currentAuth.expires = Date.now() + tokens.expires_in * 1000
                currentAuth.resource_url = tokens.resource_url
              } catch (e) {
                // Return error in response body instead of stderr
                return new Response(
                  JSON.stringify({
                    error: {
                      message: `Authentication refresh failed: ${e instanceof Error ? e.message : String(e)}`,
                      type: "auth_error",
                    },
                  }),
                  {
                    status: 500,
                    headers: { "Content-Type": "application/json" },
                  }
                )
              }
            }

            const headers = new Headers(init?.headers)
            
            // Mimic original QwenCode CLI headers to avoid aggressive rate limiting
            const version = "0.10.2"
            const userAgent = `QwenCode/${version} (${os.platform()}; ${os.arch()})`
            
            headers.set("Authorization", `Bearer ${currentAuth.access}`)
            headers.set("User-Agent", userAgent)
            headers.set("X-DashScope-UserAgent", userAgent)
            headers.set("X-DashScope-AuthType", "qwen-oauth")
            headers.set("X-DashScope-CacheControl", "enable")

            let endpoint = currentAuth.resource_url || "portal.qwen.ai"
            if (!endpoint.startsWith("http")) {
               endpoint = `https://${endpoint}`
            }
            if (!endpoint.endsWith("/v1")) {
               endpoint = `${endpoint}/v1`
            }

            let url = requestInput.toString()
            if (url.includes("dashscope.aliyuncs.com/compatible-mode/v1")) {
               url = url.replace("https://dashscope.aliyuncs.com/compatible-mode/v1", endpoint)
            }

            // Retry logic for 429 and 5xx errors
            let attempt = 0
            const maxAttempts = 5
            let currentDelay = 1500

            while (attempt < maxAttempts) {
              attempt++
              try {
                const res = await fetch(url, {
                  ...init,
                  headers,
                })

                if (res.status === 429 || (res.status >= 500 && res.status < 600)) {
                  if (attempt >= maxAttempts || init?.signal?.aborted) {
                    // Enhance error response before returning
                    const clone = res.clone()
                    const body = await clone.json().catch(() => ({}))
                    const enhanced = enhanceQwenErrorResponse(body, res.status)
                    if (enhanced) {
                      const retryHeaders = new Headers(res.headers)
                      if (enhanced.retryAfterMs) {
                        const retryAfterSec = Math.ceil(enhanced.retryAfterMs / 1000).toString()
                        retryHeaders.set("Retry-After", retryAfterSec)
                        retryHeaders.set("retry-after-ms", String(enhanced.retryAfterMs))
                      }
                      return new Response(JSON.stringify(enhanced.body), {
                        status: res.status,
                        headers: retryHeaders,
                      })
                    }
                    return res
                  }
                  
                  const retryAfter = res.headers.get("retry-after")
                  let waitTime = currentDelay
                  if (retryAfter) {
                    const seconds = parseInt(retryAfter)
                    if (!isNaN(seconds)) {
                      waitTime = seconds * 1000
                    } else {
                      const date = new Date(retryAfter)
                      if (!isNaN(date.getTime())) {
                        waitTime = Math.max(0, date.getTime() - Date.now())
                      }
                    }
                  }
                  
                  // Add jitter
                  const jitter = waitTime * 0.3 * (Math.random() * 2 - 1)
                  const finalWait = Math.max(0, waitTime + jitter)

                  if (init?.signal?.aborted) return res
                  await Bun.sleep(finalWait)
                  currentDelay = Math.min(30000, currentDelay * 2) // Exponential backoff
                  continue
                }

                // Check for quota exceeded in body for non-streaming and enhance response
                if (res.status === 400 && !init?.body?.toString().includes('"stream":true')) {
                   const clone = res.clone()
                   const body = await clone.json().catch(() => ({}))
                   const enhanced = enhanceQwenErrorResponse(body, res.status)
                   if (enhanced) {
                     return new Response(JSON.stringify(enhanced.body), {
                       status: res.status,
                       headers: res.headers,
                     })
                   }
                }

                return res
              } catch (e: any) {
                if (e.name === "AbortError" || e.message?.includes("aborted")) throw e
                if (attempt >= maxAttempts) throw e
                await Bun.sleep(currentDelay)
                currentDelay = Math.min(30000, currentDelay * 2)
              }
            }
            
            throw new Error("Maximum retry attempts reached")
          },
        }
      },
      methods: [
        {
          label: "Qwen Code OAuth",
          type: "oauth",
          authorize: async () => {
            const pkce = await generatePKCE()
            const deviceAuth = await requestDeviceAuthorization(pkce)

            try {
              const command = os.platform() === "darwin" ? "open" : "xdg-open"
              spawn(command, [deviceAuth.verification_uri_complete], {
                detached: true,
                stdio: 'ignore'
              }).unref()
            } catch (e) {
              // Ignore failure to open browser
            }

            return {
              url: deviceAuth.verification_uri_complete,
              instructions: `We've opened ${deviceAuth.verification_uri_complete} in your browser. Please authorize opencode to continue with Qwen Code...`,
              method: "auto",
              callback: async () => {
                let interval = (deviceAuth.interval || 5) * 1000
                const expiresAt = Date.now() + deviceAuth.expires_in * 1000

                while (Date.now() < expiresAt) {
                  const result = await pollDeviceToken(deviceAuth.device_code, pkce.verifier)
                  if (result === "pending") {
                    await Bun.sleep(interval)
                    continue
                  }
                  if (result === "slow_down") {
                    interval += 5000
                    await Bun.sleep(interval)
                    continue
                  }
                  return {
                    type: "success",
                    refresh: result.refresh_token,
                    access: result.access_token,
                    expires: Date.now() + result.expires_in * 1000,
                    resource_url: result.resource_url
                  } as any
                }
                return { type: "failed" }
              },
            }
          },
        },
      ],
    }
  }
}
