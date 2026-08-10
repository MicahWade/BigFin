package autoupdate

import (
	"testing"
)

func TestPullLatestInRepo(t *testing.T) {
	res := PullLatest()
	if res.Err != nil {
		t.Logf("PullLatest notice (acceptable if offline or uncommitted changes): %v", res.Err)
	} else {
		t.Logf("PullLatest result: Updated=%v, Old=%s, New=%s", res.Updated, res.OldRevision, res.NewRevision)
		if res.OldRevision == "" {
			t.Errorf("Expected non-empty OldRevision hash")
		}
	}
}

func TestExecuteAutoUpdate(t *testing.T) {
	// ExecuteAutoUpdate should execute without panics or crashes
	_ = ExecuteAutoUpdate()
}
