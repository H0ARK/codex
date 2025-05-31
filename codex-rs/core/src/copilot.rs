use crate::error::CodexErr;
use crate::protocol::{Event, EventMsg, CopilotAuthStartedEvent, CopilotAuthCompleteEvent, Op};
use crate::{Codex, config::Config};
use crate::copilot_token_store::{CopilotToken, CopilotTokenStore};
use async_channel::Sender;
use serde_json::Value;
use std::process::Command;
use std::sync::Arc;
use tokio::sync::Notify;
use anyhow;

const GITHUB_DEVICE_CODE_URL: &str = "https://github.com/login/device/code";
const GITHUB_DEVICE_TOKEN_URL: &str = "https://github.com/login/oauth/access_token";
const COPILOT_CHAT_AUTH_URL: &str = "https://api.github.com/copilot_internal/v2/token";
const GITHUB_CLIENT_ID: &str = "Iv1.b507a08c87ecfe98";

pub async fn handle_copilot_auth(tx_event: Sender<Event>, sub_id: String) -> Result<(), CodexErr> {
    // Step 1: Request device code
    let client = reqwest::Client::new();
    let device_request = [
        ("client_id", GITHUB_CLIENT_ID),
        ("scope", "copilot"),
    ];

    let response = client
        .post(GITHUB_DEVICE_CODE_URL)
        .header("Accept", "application/json")
        .form(&device_request)
        .send()
        .await?;

    if !response.status().is_success() {
        return Err(CodexErr::UnexpectedStatus(
            response.status(),
            "Failed to request device code".to_string(),
        ));
    }

    let device_response: Value = response.json().await?;
    let user_code = device_response["user_code"].as_str().unwrap();
    let verification_uri = device_response["verification_uri"].as_str().unwrap();
    let device_code = device_response["device_code"].as_str().unwrap();
    let interval = device_response["interval"].as_u64().unwrap_or(5);

    // Step 2: Send auth started event
    let auth_started_event = Event {
        id: sub_id.clone(),
        msg: EventMsg::CopilotAuthStarted(CopilotAuthStartedEvent {
            verification_uri: verification_uri.to_string(),
            user_code: user_code.to_string(),
        }),
    };
    tx_event.send(auth_started_event).await.ok();

    // Try to open browser
    let _ = open_browser(verification_uri);

    // Step 3: Poll for token
    let mut interval_timer = tokio::time::interval(std::time::Duration::from_secs(interval));
    let expires_at = std::time::Instant::now() + std::time::Duration::from_secs(300); // 5 minutes

    loop {
        if std::time::Instant::now() > expires_at {
            let event = Event {
                id: sub_id.clone(),
                msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                    success: false,
                    message: "Authentication expired".to_string(),
                }),
            };
            tx_event.send(event).await.ok();
            return Ok(());
        }

        interval_timer.tick().await;

        let token_request = [
            ("client_id", GITHUB_CLIENT_ID),
            ("device_code", device_code),
            ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
        ];

        let response = client
            .post(GITHUB_DEVICE_TOKEN_URL)
            .header("Accept", "application/json")
            .form(&token_request)
            .send()
            .await?;

        println!("Polling GitHub for token... (status: {})", response.status());

        if response.status().is_success() {
            let token_response: Value = response.json().await?;
            println!("Token response: {:?}", token_response);
            
            if let Some(access_token) = token_response["access_token"].as_str() {
                println!("✅ Got GitHub access token, exchanging for Copilot token...");
                
                println!("✅ Got GitHub access token, attempting Copilot authentication...");
                
                // Try multiple Copilot API endpoints as the internal one might not work
                let copilot_endpoints = [
                    ("https://api.github.com/copilot_internal/v2/token", "Internal V2"),
                    ("https://api.github.com/copilot/token", "Public"),
                    ("https://api.github.com/user/copilot_internal/token", "User Internal"),
                ];

                let mut last_error = String::new();
                let mut copilot_token_found = false;

                for (endpoint, endpoint_name) in copilot_endpoints.iter() {
                    println!("🔍 Trying {} endpoint: {}", endpoint_name, endpoint);
                    
                    let copilot_response = client
                        .get(*endpoint)
                        .bearer_auth(access_token)
                        .header("Accept", "application/json")
                        .header("User-Agent", "Codex-CLI")
                        .header("X-GitHub-Api-Version", "2022-11-28")
                        .send()
                        .await?;

                    let status = copilot_response.status();
                    println!("   Status: {}", status);

                    if status.is_success() {
                        let auth_response: Value = copilot_response.json().await?;
                        println!("   Response: {:?}", auth_response);
                        
                        // Try different possible token field names
                        let token_fields = ["token", "access_token", "chat_token", "copilot_token"];
                        for field in token_fields.iter() {
                            if let Some(copilot_token) = auth_response[field].as_str() {
                                println!("✅ Found Copilot token in field '{}' from {} endpoint", field, endpoint_name);
                                
                                // Save token persistently
                                match save_copilot_token(copilot_token) {
                                    Ok(_) => {
                                        println!("💾 Token saved to ~/.codex/copilot_token.json");
                                        // Also set for this session
                                        unsafe {
                                            std::env::set_var("COPILOT_TOKEN", copilot_token);
                                        }
                                    }
                                    Err(e) => {
                                        println!("⚠️  Warning: Could not save token persistently: {}", e);
                                        println!("🔑 To use this token in your shell, run:");
                                        println!("export COPILOT_TOKEN='{}'", copilot_token);
                                    }
                                }
                                println!("");
                        
                                let event = Event {
                                    id: sub_id.clone(),
                                    msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                                        success: true,
                                        message: format!("Successfully authenticated with GitHub Copilot via {}", endpoint_name),
                                    }),
                                };
                                tx_event.send(event).await.ok();
                                copilot_token_found = true;
                                break;
                            }
                        }
                        
                        if copilot_token_found {
                            return Ok(());
                        } else {
                            last_error = format!("No token field found in {} response", endpoint_name);
                            println!("   ⚠️ {}", last_error);
                        }
                    } else if status.as_u16() == 404 {
                        last_error = format!("{} endpoint not found", endpoint_name);
                        println!("   ⚠️ {}", last_error);
                    } else {
                        let error_text = copilot_response.text().await.unwrap_or_default();
                        last_error = format!("{} failed: {} - {}", endpoint_name, status, error_text);
                        println!("   ❌ {}", last_error);
                    }
                }

                // If we get here, none of the Copilot endpoints worked
                // For now, just use the GitHub token directly as a fallback
                println!("⚠️ No Copilot-specific endpoints worked, using GitHub token as fallback");
                // Save fallback token persistently
                match save_copilot_token(access_token) {
                    Ok(_) => {
                        println!("💾 GitHub token saved to ~/.codex/copilot_token.json (fallback)");
                        // Also set for this session
                        unsafe {
                            std::env::set_var("COPILOT_TOKEN", access_token);
                        }
                    }
                    Err(e) => {
                        println!("⚠️  Warning: Could not save token persistently: {}", e);
                        println!("🔑 To use this token in your shell, run:");
                        println!("export COPILOT_TOKEN='{}'", access_token);
                    }
                }
                println!("");
                
                let event = Event {
                    id: sub_id.clone(),
                    msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                        success: true,
                        message: format!("GitHub authentication complete. Note: Using GitHub token as Copilot endpoints are not accessible. Last error: {}", last_error),
                    }),
                };
                tx_event.send(event).await.ok();
                return Ok(());
            } else if let Some(error) = token_response["error"].as_str() {
                println!("GitHub OAuth error: {}", error);
                match error {
                    "authorization_pending" => {
                        println!("⏳ Still waiting for user authorization...");
                        continue;
                    },
                    "slow_down" => {
                        println!("⏳ Rate limited, slowing down polling...");
                        tokio::time::sleep(std::time::Duration::from_secs(interval + 5)).await;
                        continue;
                    }
                    "access_denied" => {
                        let event = Event {
                            id: sub_id.clone(),
                            msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                                success: false,
                                message: "User denied authorization".to_string(),
                            }),
                        };
                        tx_event.send(event).await.ok();
                        return Ok(());
                    }
                    "expired_token" => {
                        let event = Event {
                            id: sub_id.clone(),
                            msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                                success: false,
                                message: "Authorization code expired, please try again".to_string(),
                            }),
                        };
                        tx_event.send(event).await.ok();
                        return Ok(());
                    }
                    _ => {
                        let event = Event {
                            id: sub_id.clone(),
                            msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                                success: false,
                                message: format!("Authentication failed: {}", error),
                            }),
                        };
                        tx_event.send(event).await.ok();
                        return Ok(());
                    }
                }
            } else {
                println!("❌ Unexpected response format: {:?}", token_response);
                let event = Event {
                    id: sub_id.clone(),
                    msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                        success: false,
                        message: "Unexpected response from GitHub".to_string(),
                    }),
                };
                tx_event.send(event).await.ok();
                return Ok(());
            }
        } else {
            let status = response.status();
            let error_text = response.text().await.unwrap_or_default();
            println!("❌ Token request failed with status: {} - {}", status, error_text);
            
            // Don't fail immediately on HTTP errors, GitHub might be temporarily down
            if status.as_u16() >= 500 {
                println!("⏳ Server error, retrying...");
                continue;
            } else {
                let event = Event {
                    id: sub_id.clone(),
                    msg: EventMsg::CopilotAuthComplete(CopilotAuthCompleteEvent {
                        success: false,
                        message: format!("GitHub API error: {} - {}", status, error_text),
                    }),
                };
                tx_event.send(event).await.ok();
                return Ok(());
            }
        }
    }
}

fn open_browser(url: &str) -> Result<(), std::io::Error> {
    #[cfg(target_os = "macos")]
    {
        Command::new("open").arg(url).spawn()?;
    }
    #[cfg(target_os = "linux")]
    {
        Command::new("xdg-open").arg(url).spawn()?;
    }
    #[cfg(target_os = "windows")]
    {
        Command::new("cmd").args(["/c", "start", url]).spawn()?;
    }
    Ok(())
}

fn save_copilot_token(token: &str) -> anyhow::Result<()> {
    let store = CopilotTokenStore::new()?;
    let copilot_token = CopilotToken::from_raw_token(token);
    store.save_token(&copilot_token)?;
    Ok(())
}

pub fn load_copilot_token() -> Option<String> {
    let store = CopilotTokenStore::new().ok()?;
    store.get_valid_token()
}

pub fn ensure_copilot_token_in_env() -> bool {
    if let Ok(store) = CopilotTokenStore::new() {
        store.set_env_var().unwrap_or(false)
    } else {
        false
    }
}

#[cfg(feature = "cli")]
pub async fn run_copilot_auth_command(config_overrides: codex_common::CliConfigOverrides) -> anyhow::Result<()> {
    // Parse config overrides like exec does
    let cli_kv_overrides = match config_overrides.parse_overrides() {
        Ok(v) => v,
        Err(e) => {
            eprintln!("Error parsing -c overrides: {e}");
            return Err(anyhow::anyhow!("Config override error: {}", e));
        }
    };
    
    // Create a minimal config for copilot auth
    let config = Config::load_with_cli_overrides(cli_kv_overrides, Default::default())?;
    let ctrl_c = Arc::new(Notify::new());
    
    // Spawn codex instance
    let (codex, _init_id) = Codex::spawn(config, ctrl_c).await?;
    
    // Submit copilot auth operation
    let auth_id = codex.submit(Op::CopilotAuth).await?;
    
    // Listen for events
    while let Ok(event) = codex.next_event().await {
        if event.id == auth_id {
            match event.msg {
                EventMsg::CopilotAuthStarted(auth_event) => {
                    println!("To authenticate with GitHub Copilot:");
                    println!("1. Visit: {}", auth_event.verification_uri);
                    println!("2. Enter this code: {}", auth_event.user_code);
                    println!("3. Authorize the application");
                    println!("\nWaiting for authentication...");
                }
                EventMsg::CopilotAuthComplete(complete_event) => {
                    if complete_event.success {
                        println!("✓ {}", complete_event.message);
                    } else {
                        eprintln!("✗ {}", complete_event.message);
                    }
                    break;
                }
                EventMsg::Error(error_event) => {
                    eprintln!("Error: {}", error_event.message);
                    break;
                }
                _ => {}
            }
        }
    }
    
    Ok(())
}

#[cfg(feature = "cli")]
pub async fn run_copilot_status_command() -> anyhow::Result<()> {
    println!("🔍 Checking Copilot token status...");
    println!();
    
    let store = CopilotTokenStore::new()?;
    
    // Check for persisted token
    match store.load_token() {
        Ok(Some(token)) => {
            println!("✅ Persisted token found:");
            println!("   File: ~/.codex/copilot_token.json");
            
            if let Some(expires_in) = token.expires_in_minutes() {
                if expires_in > 0 {
                    println!("   Status: Valid (expires in {} minutes)", expires_in);
                } else {
                    println!("   Status: ⚠️  Expired");
                }
            } else {
                println!("   Status: Valid (no expiration)");
            }
            
            if let Some(sku) = &token.sku {
                println!("   SKU: {}", sku);
            }
            
            if let Some(proxy) = &token.proxy_endpoint {
                println!("   Proxy: {}", proxy);
            }
        }
        Ok(None) => {
            println!("❌ No persisted token found");
        }
        Err(e) => {
            println!("⚠️  Error loading persisted token: {}", e);
        }
    }
    
    // Check environment variable
    match std::env::var("COPILOT_TOKEN") {
        Ok(env_token) => {
            println!();
            println!("✅ Environment variable COPILOT_TOKEN is set");
            println!("   Value: {}...{}", &env_token[..20.min(env_token.len())], 
                    if env_token.len() > 40 { &env_token[env_token.len()-20..] } else { "" });
        }
        Err(_) => {
            println!();
            println!("❌ Environment variable COPILOT_TOKEN is not set");
        }
    }
    
    // Check if token would be available for API calls
    println!();
    if let Some(_token) = store.get_valid_token() {
        println!("✅ Token is available for API calls");
        println!();
        println!("💡 You can now use Copilot with:");
        println!("   codex --profile copilot-sonnet \"Your prompt here\"");
    } else {
        println!("❌ No valid token available for API calls");
        println!();
        println!("💡 Run 'codex copilot auth' to authenticate");
    }
    
    Ok(())
}