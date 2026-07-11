// ac-web is a tiny, auth-less web UI for spawning `ac` coding-agent sessions
// from a phone over Tailscale. It lists repos under ~/git, their worktrees, and
// running ac sessions, and drives `ac spawn` / `ac rm` to create and clean up
// detached sessions. Bind it to the tailnet IP so only the tailnet can reach it.
package main

import (
	"context"
	"flag"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
)

const port = "8846"

// Deadlines bound every subprocess so a wedged git/tmux/tailscale can't hang a
// handler forever (Restart=always can't help a process that never exits). Reads
// are quick; spawn runs `git fetch` on a fresh branch, which is legitimately slow.
const (
	readTimeout  = 15 * time.Second
	spawnTimeout = 5 * time.Minute
)

var (
	gitRoot = envOr("GIT_ROOT", filepath.Join(home(), "git"))
	wtRoot  = envOr("WT_ROOT", filepath.Join(home(), "worktrees"))
)

func main() {
	listen := flag.String("listen", "", "address to bind (default: <tailnet-ipv4>:"+port+")")
	flag.Parse()

	addr := *listen
	if addr == "" {
		addr = tailnetAddr()
	}

	slog.Info("ac-web listening", "addr", addr, "git", gitRoot, "wt", wtRoot)
	// CrossOriginProtection rejects cross-origin unsafe requests (Sec-Fetch-Site /
	// Origin vs Host); same-origin form posts pass. With POST-only mutating routes
	// below, this closes the CSRF hole a tailnet-device browser would otherwise open.
	srv := &http.Server{
		Addr:              addr,
		Handler:           http.NewCrossOriginProtection().Handler(routes()),
		ReadHeaderTimeout: 5 * time.Second,
	}
	slog.Error("serve", "err", srv.ListenAndServe())
	os.Exit(1)
}

// routes wires the mux. Mutating endpoints are POST-only (method patterns), so a
// forged GET (img/link/prefetch) 405s instead of running a command.
func routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", handleIndex)
	mux.HandleFunc("POST /spawn", handleSpawn)
	mux.HandleFunc("POST /kill", handleKill)
	mux.HandleFunc("POST /rmworktree", handleRmWorktree)
	return mux
}

// --- data ---

type session struct {
	Server, Repo, Branch, Agent string
	Workdir                     string // cwd of the session, for the rm-worktree live check
	Attached                    bool
}

type worktree struct {
	Branch     string // checked-out branch: the spawn identity, matches `ac`
	Rel        string // path under wtRoot/<repo>: the delete identity
	LastActive time.Time
	path       string // absolute worktree path (for lastActive lookup)
}

type repo struct {
	Name      string
	Worktrees []worktree
	Active    time.Time
}

type pageData struct {
	Sessions []session
	Repos    []repo
}

// repos lists directories under gitRoot that are git repos, most-recently
// active first. A repo's activity is the newest of its own HEAD and its
// worktrees.
func repos() []repo {
	entries, err := os.ReadDir(gitRoot)
	if err != nil {
		slog.Error("read git root", "dir", gitRoot, "err", err)
		return nil
	}
	var out []repo
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, err := os.Stat(filepath.Join(gitRoot, e.Name(), ".git")); err != nil {
			continue
		}
		wts := worktreesFor(e.Name())
		active := lastActive(filepath.Join(gitRoot, e.Name()))
		if len(wts) > 0 && wts[0].LastActive.After(active) { // wts sorted newest-first
			active = wts[0].LastActive
		}
		out = append(out, repo{Name: e.Name(), Worktrees: wts, Active: active})
	}
	slices.SortFunc(out, func(a, b repo) int { return b.Active.Compare(a.Active) })
	return out
}

// lastActive returns the committer time of HEAD in dir, or zero on error.
// ponytail: HEAD commit date is the signal; a worktree freshly branched from an
// old base sorts old. If that bites, switch to the worktree admin-dir mtime.
func lastActive(dir string) time.Time {
	out, err := output(readTimeout, "git", "-C", dir, "log", "-1", "--format=%ct", "HEAD")
	if err != nil {
		return time.Time{}
	}
	sec, _ := strconv.ParseInt(strings.TrimSpace(string(out)), 10, 64)
	return time.Unix(sec, 0)
}

// worktreesFor returns the branch worktrees for a repo (those living under
// wtRoot/<repo>/), newest-first, each with its last-active time filled in. The
// parsing is in parseWorktrees; this wrapper does the git call and the per-path
// activity lookup.
func worktreesFor(name string) []worktree {
	out, err := output(readTimeout, "git", "-C", filepath.Join(gitRoot, name), "worktree", "list", "--porcelain")
	if err != nil {
		slog.Error("worktree list", "repo", name, "err", err)
		return nil
	}
	res := parseWorktrees(out, filepath.Join(wtRoot, name)+"/")
	for i := range res {
		res[i].LastActive = lastActive(res[i].path)
	}
	slices.SortFunc(res, func(a, b worktree) int { return b.LastActive.Compare(a.LastActive) })
	return res
}

// parseWorktrees turns `git worktree list --porcelain` output into the branch
// worktrees living under prefix. Each carries the branch it has checked out — the
// spawn identity, which `ac spawn <repo> <branch>` resolves the same way the CLI
// does — and its path relative to prefix, the unambiguous delete identity (it can
// differ from the branch name after a rename). Detached HEAD falls back to the
// dir name; the main worktree (outside prefix) is excluded.
func parseWorktrees(out []byte, prefix string) []worktree {
	var res []worktree
	var path, branch string
	var under bool
	commit := func() { // flush the current porcelain block
		if under {
			b := branch
			if b == "" { // detached HEAD: fall back to the dir name
				b = strings.TrimPrefix(path, prefix)
			}
			res = append(res, worktree{Branch: b, Rel: strings.TrimPrefix(path, prefix), path: path})
		}
		path, branch, under = "", "", false
	}
	for line := range strings.SplitSeq(string(out), "\n") {
		switch {
		case strings.HasPrefix(line, "worktree "):
			commit()
			path = strings.TrimPrefix(line, "worktree ")
			under = strings.HasPrefix(path, prefix)
		case strings.HasPrefix(line, "branch "):
			branch = strings.TrimPrefix(strings.TrimPrefix(line, "branch "), "refs/heads/")
		}
	}
	commit()
	return res
}

// sessions parses `ac ls --porcelain`.
func sessions() []session {
	out, err := output(readTimeout, "ac", "ls", "--porcelain")
	if err != nil {
		slog.Error("ac ls", "err", err)
		return nil
	}
	return parseSessions(out)
}

// parseSessions decodes ac's porcelain contract, one live session per line:
// server<TAB>repo<TAB>branch<TAB>agent<TAB>attached(0|1)<TAB>workdir. Kept in
// lockstep with pkgs/scripts/ac.sh cmd_list_porcelain.
func parseSessions(out []byte) []session {
	var res []session
	for line := range strings.SplitSeq(strings.TrimRight(string(out), "\n"), "\n") {
		if line == "" {
			continue
		}
		f := strings.Split(line, "\t")
		if len(f) < 5 {
			continue
		}
		s := session{Server: f[0], Repo: f[1], Branch: f[2], Agent: f[3], Attached: f[4] == "1"}
		if len(f) >= 6 {
			s.Workdir = f[5]
		}
		res = append(res, s)
	}
	return res
}

// --- handlers ---

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if err := page.Execute(w, pageData{Sessions: sessions(), Repos: repos()}); err != nil {
		slog.Error("render", "err", err)
	}
}

func handleSpawn(w http.ResponseWriter, r *http.Request) {
	// Lowercase before validating: iPhone auto-capitalizes the branch text field,
	// and a stray capital would otherwise fork a duplicate workspace. Repo/branch
	// are always lowercase by convention, so this only ever undoes the phone.
	repoName := strings.ToLower(r.FormValue("repo"))
	branch := strings.ToLower(r.FormValue("branch"))
	if err := validateRepo(repoName); err != nil {
		fail(w, err)
		return
	}
	if err := validateBranch(branch); err != nil {
		fail(w, err)
		return
	}
	args := []string{"spawn", repoName}
	if branch != "" {
		args = append(args, branch)
	}
	run(w, r, "ac", args...)
}

func handleKill(w http.ResponseWriter, r *http.Request) {
	server := r.FormValue("server")
	if !serverRe.MatchString(server) {
		fail(w, fmt.Errorf("invalid server name: %q", server))
		return
	}
	run(w, r, "ac", "rm", server)
}

// handleRmWorktree removes a worktree by its path under wtRoot/<repo> (keeping
// the branch ref). Removing by path, not by branch name, is what makes this
// correct when the two differ after a rename. It refuses if a live session's cwd
// is that worktree — deleting it out from under a running agent orphans the
// session and loses in-flight work, the exact failure graceful shutdown exists to
// prevent. Single --force (not two): remove a dirty tree, but never a locked one.
func handleRmWorktree(w http.ResponseWriter, r *http.Request) {
	repoName := strings.ToLower(r.FormValue("repo"))
	rel := strings.ToLower(r.FormValue("path"))
	if err := validateRepo(repoName); err != nil {
		fail(w, err)
		return
	}
	if err := validateBranch(rel); err != nil || rel == "" { // same path-shape rules
		fail(w, fmt.Errorf("invalid worktree path: %q", rel))
		return
	}
	target := filepath.Join(wtRoot, repoName, rel)
	for _, s := range sessions() {
		if s.Workdir == target {
			fail(w, fmt.Errorf("session %s is live in %s/%s; kill it first", s.Server, repoName, rel))
			return
		}
	}
	run(w, r, "git", "-C", filepath.Join(gitRoot, repoName),
		"worktree", "remove", "--force", target)
}

// run executes a command and, on success, redirects back to the index; on
// failure it shows the combined output so the error isn't swallowed. The deadline
// (spawn's git fetch is the slow case) plus WaitDelay stops a wedged or
// daemonizing child from holding the handler open.
func run(w http.ResponseWriter, r *http.Request, name string, args ...string) {
	ctx, cancel := context.WithTimeout(r.Context(), spawnTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.WaitDelay = time.Second
	out, err := cmd.CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("%s %s failed: %v\n\n%s", name, strings.Join(args, " "), err, out), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func fail(w http.ResponseWriter, err error) { http.Error(w, err.Error(), http.StatusBadRequest) }

// --- validation (the exec trust boundary; args go via argv, never a shell) ---

var (
	// An opaque herdr workspace handle from `ac ls --porcelain`, passed straight
	// back to `ac rm` via argv (no shell). Any bare token is safe; the old `ac-`
	// prefix was a tmux-socket-name artifact and no longer applies.
	serverRe = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)
	branchRe = regexp.MustCompile(`^[A-Za-z0-9._/-]+$`)
)

func validateRepo(name string) error {
	if name == "" || strings.ContainsAny(name, "/\x00") || strings.Contains(name, "..") {
		return fmt.Errorf("invalid repo: %q", name)
	}
	if _, err := os.Stat(filepath.Join(gitRoot, name, ".git")); err != nil {
		return fmt.Errorf("not a repo under %s: %q", gitRoot, name)
	}
	return nil
}

// validateBranch permits an empty branch (spawn the main repo). Otherwise the
// name must look like a git branch: no leading '-', no '..', no whitespace.
func validateBranch(name string) error {
	if name == "" {
		return nil
	}
	if strings.HasPrefix(name, "-") || strings.Contains(name, "..") || !branchRe.MatchString(name) {
		return fmt.Errorf("invalid branch: %q", name)
	}
	return nil
}

// --- helpers ---

// output runs name+args under a deadline and returns stdout. WaitDelay keeps a
// child that daemonizes (holding the pipe) from stalling us after the kill.
func output(timeout time.Duration, name string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.WaitDelay = time.Second
	return cmd.Output()
}

func home() string {
	h, err := os.UserHomeDir()
	if err != nil {
		slog.Error("home dir", "err", err)
		os.Exit(1)
	}
	return h
}

// ago renders a coarse "time since" label for the UI: "", "just now", "3h", "5d".
func ago(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	d := time.Since(t)
	switch {
	case d < time.Minute:
		return "just now"
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	default:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// tailnetAddr resolves the host's Tailscale IPv4, retrying because tailscaled
// may lag behind network-online at boot.
func tailnetAddr() string {
	for range 30 {
		out, err := output(readTimeout, "tailscale", "ip", "-4")
		if err == nil {
			if ip := strings.TrimSpace(strings.SplitN(string(out), "\n", 2)[0]); ip != "" {
				return ip + ":" + port
			}
		}
		time.Sleep(2 * time.Second)
	}
	slog.Error("could not determine tailscale IPv4 (pass -listen to override)")
	os.Exit(1)
	return ""
}

var page = template.Must(template.New("page").Funcs(template.FuncMap{"ago": ago}).Parse(`<!doctype html>
<html><head><meta charset=utf-8>
<meta name=viewport content="width=device-width, initial-scale=1">
<title>ac-web</title>
<style>
 body{font-family:system-ui,sans-serif;margin:0 auto;max-width:40rem;padding:1rem;line-height:1.5}
 h2{margin:1.5rem 0 .5rem;border-bottom:1px solid #ccc}
 h3{margin:1rem 0 .25rem}
 form{display:inline}
 button{font-size:1rem;padding:.4rem .7rem;margin:.15rem 0}
 input{font-size:1rem;padding:.4rem}
 ul{list-style:none;padding:0}
 li{margin:.3rem 0}
 .muted{color:#666}
 .att{color:#0a0}
</style></head><body>
<h1>ac-web</h1>

<h2>Running sessions</h2>
{{if .Sessions}}<ul>
{{range .Sessions}}<li>
 <code>{{.Repo}}{{if .Branch}}/{{.Branch}}{{end}}</code> [{{.Agent}}]
 {{if .Attached}}<span class=att>* attached</span>{{end}}
 <form method=post action=/kill onsubmit="return confirm('Kill session {{.Server}}?')"><input type=hidden name=server value="{{.Server}}"><button>kill</button></form>
</li>{{end}}
</ul>{{else}}<p class=muted>none</p>{{end}}

<h2>Repos <span class=muted>(newest first)</span></h2>
{{range .Repos}}{{$repo := .Name}}
<h3>{{.Name}} <span class=muted>{{ago .Active}}</span></h3>
<form method=post action=/spawn><input type=hidden name=repo value="{{$repo}}"><button>spawn main</button></form>
<form method=post action=/spawn>
 <input type=hidden name=repo value="{{$repo}}">
 <input name=branch placeholder="new branch" required>
 <button>create + spawn</button>
</form>
{{if .Worktrees}}<ul>
{{range .Worktrees}}<li>
 <form method=post action=/spawn>
  <input type=hidden name=repo value="{{$repo}}">
  <input type=hidden name=branch value="{{.Branch}}">
  <button>spawn</button> <code>{{.Branch}}</code>{{if ne .Branch .Rel}} <span class=muted>in {{.Rel}}</span>{{end}} <span class=muted>{{ago .LastActive}}</span>
 </form>
 <form method=post action=/rmworktree onsubmit="return confirm('Remove worktree {{$repo}}/{{.Rel}}?')">
  <input type=hidden name=repo value="{{$repo}}">
  <input type=hidden name=path value="{{.Rel}}">
  <button>rm</button>
 </form>
</li>{{end}}
</ul>{{end}}
{{end}}
</body></html>
`))
