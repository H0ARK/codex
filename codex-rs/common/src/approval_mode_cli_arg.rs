//! Standard type to use with the `--approval-mode` CLI option.
//! Available when the `cli` feature is enabled for the crate.

use clap::ArgAction;
use clap::Parser;
use clap::ValueEnum;

use std::path::PathBuf;

#[derive(Clone, Copy, Debug, ValueEnum)]
#[value(rename_all = "kebab-case")]
pub enum ApprovalModeCliArg {
    /// Run all commands without asking for user approval.
    /// Only asks for approval if a command fails to execute, in which case it
    /// will escalate to the user to ask for un-sandboxed execution.
    OnFailure,

    /// Only run "known safe" commands (e.g. ls, cat, sed) without
    /// asking for user approval. Will escalate to the user if the model
    /// proposes a command that is not allow-listed.
    UnlessAllowListed,

    /// Never ask for user approval
    /// Execution failures are immediately returned to the model.
    Never,
}

/// Approval policy for executing commands (duplicated from codex-core to break circular dependency)
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AskForApproval {
    /// Under this policy, only “known safe” commands—as determined by
    /// `is_safe_command()`—that **only read files** are auto‑approved.
    /// Everything else will ask the user to approve.
    UnlessAllowListed,

    /// In addition to everything allowed by **`Suggest`**, commands that
    /// *write* to files **within the user\'s approved list of writable paths**
    /// are also auto‑approved.
    OnFailure,

    /// Never ask for user approval
    /// Execution failures are immediately returned to the model.
    Never,
}

/// Sandbox permission types (duplicated from codex-core to break circular dependency)
#[derive(Clone, Debug, PartialEq)]
pub enum SandboxPermission {
    /// Is allowed to read all files on disk.
    DiskFullReadAccess,

    /// Is allowed to write to the operating system\'s temp dir that
    /// is restricted to the user the agent is running as.
    DiskWritePlatformUserTempFolder,

    /// Is allowed to write to the operating system\'s shared temp
    /// dir (e.g., `/tmp` on Unix systems`).
    DiskWritePlatformGlobalTempFolder,

    /// Is allowed to write to the current working directory.
    DiskWriteCwd,

    /// Is allowed to write to a specific folder.
    DiskWriteFolder(PathBuf),

    /// Is allowed to write anywhere on disk.
    DiskFullWriteAccess,

    /// Is allowed to make network requests.
    NetworkFullAccess,
}

impl From<ApprovalModeCliArg> for AskForApproval {
    fn from(value: ApprovalModeCliArg) -> Self {
        match value {
            ApprovalModeCliArg::UnlessAllowListed => AskForApproval::UnlessAllowListed,
            ApprovalModeCliArg::OnFailure => AskForApproval::OnFailure,
            ApprovalModeCliArg::Never => AskForApproval::Never,
        }
    }
}

#[derive(Parser, Debug)]
pub struct SandboxPermissionOption {
    /// Specify this flag multiple times to specify the full set of permissions
    /// to grant to Codex.
    ///
    /// ```shell
    /// codex -s disk-full-read-access \
    ///       -s disk-write-cwd \
    ///       -s disk-write-platform-user-temp-folder \
    ///       -s disk-write-platform-global-temp-folder
    /// ```
    ///
    /// Note disk-write-folder takes a value:
    ///
    /// ```shell
    ///     -s disk-write-folder=$HOME/.pyenv/shims
    /// ```
    ///
    /// These permissions are quite broad and should be used with caution:
    ///
    /// ```shell
    ///     -s disk-full-write-access
    ///     -s network-full-access
    /// ```
    #[arg(long = "sandbox-permission", short = 's', action = ArgAction::Append, value_parser = parse_sandbox_permission)]
    pub permissions: Option<Vec<SandboxPermission>>,
}

/// Custom value-parser so we can keep the CLI surface small *and*
/// still handle the parameterised `disk-write-folder` case.
fn parse_sandbox_permission(raw: &str) -> std::io::Result<SandboxPermission> {
    let base_path = std::env::current_dir()?;
    use SandboxPermission::*;

    if let Some(path) = raw.strip_prefix("disk-write-folder=") {
        return if path.is_empty() {
            Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "--sandbox-permission disk-write-folder=<PATH> requires a non-empty PATH",
            ))
        } else {
            let path = PathBuf::from(path);
            let path = if path.is_absolute() {
                path
            } else {
                base_path.join(path)
            };
            Ok(DiskWriteFolder(path))
        };
    }

    match raw {
        "disk-full-read-access" => Ok(DiskFullReadAccess),
        "disk-write-platform-user-temp-folder" => Ok(DiskWritePlatformUserTempFolder),
        "disk-write-platform-global-temp-folder" => Ok(DiskWritePlatformGlobalTempFolder),
        "disk-write-cwd" => Ok(DiskWriteCwd),
        "disk-full-write-access" => Ok(DiskFullWriteAccess),
        "network-full-access" => Ok(NetworkFullAccess),
        _ => Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("Unknown sandbox permission: {raw}"),
        )),
    }
}
