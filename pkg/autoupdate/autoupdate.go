package autoupdate

import (
	"bytes"
	"fmt"
	"log"
	"os/exec"
	"strings"
)

// AutoUpdateResult holds information about an auto-update attempt.
type AutoUpdateResult struct {
	Updated     bool
	OldRevision string
	NewRevision string
	Output      string
	Err         error
}

// PullLatest attempts to pull the latest git commits from the remote repository.
func PullLatest() AutoUpdateResult {
	if _, err := exec.LookPath("git"); err != nil {
		return AutoUpdateResult{Err: fmt.Errorf("git command not found: %w", err)}
	}

	// Verify inside git repository
	if err := exec.Command("git", "rev-parse", "--is-inside-work-tree").Run(); err != nil {
		return AutoUpdateResult{Err: fmt.Errorf("not in git repository: %w", err)}
	}

	// Get current commit hash before pull
	var outBefore bytes.Buffer
	cmdBefore := exec.Command("git", "rev-parse", "HEAD")
	cmdBefore.Stdout = &outBefore
	if err := cmdBefore.Run(); err != nil {
		return AutoUpdateResult{Err: fmt.Errorf("failed to get commit hash: %w", err)}
	}
	oldRev := strings.TrimSpace(outBefore.String())

	// Execute git pull
	var pullOut bytes.Buffer
	pullCmd := exec.Command("git", "pull", "--ff-only")
	pullCmd.Stdout = &pullOut
	pullCmd.Stderr = &pullOut
	err := pullCmd.Run()
	outputStr := strings.TrimSpace(pullOut.String())

	if err != nil {
		// Fallback to standard git pull if ff-only fails
		var fallbackOut bytes.Buffer
		fallbackCmd := exec.Command("git", "pull")
		fallbackCmd.Stdout = &fallbackOut
		fallbackCmd.Stderr = &fallbackOut
		if fbErr := fallbackCmd.Run(); fbErr != nil {
			return AutoUpdateResult{
				OldRevision: oldRev,
				NewRevision: oldRev,
				Output:      outputStr + " | " + strings.TrimSpace(fallbackOut.String()),
				Err:         fmt.Errorf("git pull failed: %w", fbErr),
			}
		}
		outputStr = strings.TrimSpace(fallbackOut.String())
	}

	// Commit hash after pull
	var outAfter bytes.Buffer
	cmdAfter := exec.Command("git", "rev-parse", "HEAD")
	cmdAfter.Stdout = &outAfter
	if err := cmdAfter.Run(); err != nil {
		return AutoUpdateResult{
			OldRevision: oldRev,
			NewRevision: oldRev,
			Output:      outputStr,
			Err:         fmt.Errorf("failed to get updated commit hash: %w", err),
		}
	}
	newRev := strings.TrimSpace(outAfter.String())

	return AutoUpdateResult{
		Updated:     oldRev != newRev,
		OldRevision: oldRev,
		NewRevision: newRev,
		Output:      outputStr,
		Err:         nil,
	}
}

// ExecuteAutoUpdate executes the git pull auto-update process and logs the output.
func ExecuteAutoUpdate() bool {
	log.Println("[AUTO-UPDATE] Checking for remote repository updates via git pull...")
	res := PullLatest()
	if res.Err != nil {
		log.Printf("[AUTO-UPDATE] Update check notice: %v\n", res.Err)
		return false
	}
	if res.Updated {
		oldShort := res.OldRevision
		if len(oldShort) > 7 {
			oldShort = oldShort[:7]
		}
		newShort := res.NewRevision
		if len(newShort) > 7 {
			newShort = newShort[:7]
		}
		log.Printf("[AUTO-UPDATE] Successfully updated from %s to %s!\nOutput: %s\n", oldShort, newShort, res.Output)
		return true
	}
	short := res.OldRevision
	if len(short) > 7 {
		short = short[:7]
	}
	log.Printf("[AUTO-UPDATE] Bigfin is up to date at commit %s.\n", short)
	return false
}
