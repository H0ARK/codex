use std::fs;
use std::path::PathBuf;
use serde::{Deserialize, Serialize};
use anyhow::{Result, Context};
use dirs::home_dir;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CopilotToken {
    pub token: String,
    pub expires_at: Option<u64>,
    pub sku: Option<String>,
    pub proxy_endpoint: Option<String>,
    pub tracking_id: Option<String>,
}

impl CopilotToken {
    pub fn from_raw_token(raw_token: &str) -> Self {
        let mut token = CopilotToken {
            token: raw_token.to_string(),
            expires_at: None,
            sku: None,
            proxy_endpoint: None,
            tracking_id: None,
        };

        // Parse token components if it's a structured Copilot token
        if raw_token.starts_with("tid=") {
            for part in raw_token.split(';') {
                if let Some((key, value)) = part.split_once('=') {
                    match key {
                        "exp" => {
                            if let Ok(exp) = value.parse::<u64>() {
                                token.expires_at = Some(exp);
                            }
                        }
                        "sku" => {
                            token.sku = Some(value.to_string());
                        }
                        "proxy-ep" => {
                            token.proxy_endpoint = Some(value.to_string());
                        }
                        "tid" => {
                            token.tracking_id = Some(value.to_string());
                        }
                        _ => {}
                    }
                }
            }
        }

        token
    }

    pub fn is_expired(&self) -> bool {
        if let Some(expires_at) = self.expires_at {
            let current_time = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            current_time >= expires_at
        } else {
            false
        }
    }

    pub fn expires_in_minutes(&self) -> Option<u64> {
        if let Some(expires_at) = self.expires_at {
            let current_time = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            if expires_at > current_time {
                Some((expires_at - current_time) / 60)
            } else {
                Some(0)
            }
        } else {
            None
        }
    }
}

pub struct CopilotTokenStore {
    token_file: PathBuf,
}

impl CopilotTokenStore {
    pub fn new() -> Result<Self> {
        let codex_home = std::env::var("CODEX_HOME")
            .map(PathBuf::from)
            .or_else(|_| {
                home_dir()
                    .map(|h| h.join(".codex"))
                    .ok_or_else(|| anyhow::anyhow!("Could not find home directory"))
            })
            .context("Could not determine Codex home directory")?;

        // Ensure the directory exists
        fs::create_dir_all(&codex_home)
            .context("Failed to create Codex home directory")?;

        let token_file = codex_home.join("copilot_token.json");

        Ok(Self { token_file })
    }

    pub fn save_token(&self, token: &CopilotToken) -> Result<()> {
        let json = serde_json::to_string_pretty(token)
            .context("Failed to serialize token")?;

        fs::write(&self.token_file, json)
            .context("Failed to write token file")?;

        // Set restrictive permissions (owner read/write only)
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&self.token_file)?.permissions();
            perms.set_mode(0o600);
            fs::set_permissions(&self.token_file, perms)?;
        }

        Ok(())
    }

    pub fn load_token(&self) -> Result<Option<CopilotToken>> {
        if !self.token_file.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(&self.token_file)
            .context("Failed to read token file")?;

        let token: CopilotToken = serde_json::from_str(&content)
            .context("Failed to parse token file")?;

        if token.is_expired() {
            // Remove expired token
            self.clear_token()?;
            return Ok(None);
        }

        Ok(Some(token))
    }

    pub fn clear_token(&self) -> Result<()> {
        if self.token_file.exists() {
            fs::remove_file(&self.token_file)
                .context("Failed to remove token file")?;
        }
        Ok(())
    }

    pub fn get_valid_token(&self) -> Option<String> {
        if let Ok(Some(token)) = self.load_token() {
            if !token.is_expired() {
                return Some(token.token);
            }
        }
        
        // Fallback to environment variable
        std::env::var("COPILOT_TOKEN").ok()
    }

    pub fn set_env_var(&self) -> Result<bool> {
        if let Some(token) = self.get_valid_token() {
            unsafe {
                std::env::set_var("COPILOT_TOKEN", &token);
            }
            Ok(true)
        } else {
            Ok(false)
        }
    }
}

impl Default for CopilotTokenStore {
    fn default() -> Self {
        Self::new().expect("Failed to create CopilotTokenStore")
    }
}