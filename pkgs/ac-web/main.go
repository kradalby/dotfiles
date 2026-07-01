// ac-web is a tiny, auth-less web UI for spawning `ac` coding-agent sessions
// from a phone over Tailscale. It lists repos under ~/git, their worktrees, and
// running ac sessions, and drives `ac spawn` / `ac rm` to create and clean up
// detached sessions. Bind it to the tailnet IP so only the tailnet can reach it.
package main

import (
	"flag"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const port = "8846"

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

	mux := http.NewServeMux()
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/spawn", handleSpawn)
	mux.HandleFunc("/kill", handleKill)
	mux.HandleFunc("/rmworktree", handleRmWorktree)

	log.Printf("ac-web listening on http://%s  (git=%s wt=%s)", addr, gitRoot, wtRoot)
	log.Fatal(http.ListenAndServe(addr, mux))
}

// --- data ---

type session struct {
	Server, Repo, Branch, Agent string
	Attached                    bool
}

type worktree struct {
	Branch     string
	LastActive time.Time
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
	sort.Slice(out, func(i, j int) bool { return out[i].Active.After(out[j].Active) })
	return out
}

// lastActive returns the committer time of HEAD in dir, or zero on error.
// ponytail: HEAD commit date is the signal; a worktree freshly branched from an
// old base sorts old. If that bites, switch to the worktree admin-dir mtime.
func lastActive(dir string) time.Time {
	out, err := exec.Command("git", "-C", dir, "log", "-1", "--format=%ct", "HEAD").Output()
	if err != nil {
		return time.Time{}
	}
	sec, _ := strconv.ParseInt(strings.TrimSpace(string(out)), 10, 64)
	return time.Unix(sec, 0)
}

// worktreesFor returns the branch worktrees for a repo (those living under
// wtRoot/<repo>/), derived from `git worktree list`. The branch id is the path
// relative to wtRoot/<repo>, which is exactly what `ac spawn <repo> <branch>`
// expects. The main worktree (under gitRoot) is excluded.
func worktreesFor(name string) []worktree {
	out, err := exec.Command("git", "-C", filepath.Join(gitRoot, name), "worktree", "list", "--porcelain").Output()
	if err != nil {
		return nil
	}
	prefix := filepath.Join(wtRoot, name) + "/"
	var res []worktree
	for line := range strings.SplitSeq(string(out), "\n") {
		path, ok := strings.CutPrefix(line, "worktree ")
		if !ok {
			continue
		}
		if branch, under := strings.CutPrefix(path, prefix); under {
			res = append(res, worktree{Branch: branch, LastActive: lastActive(path)})
		}
	}
	sort.Slice(res, func(i, j int) bool { return res[i].LastActive.After(res[j].LastActive) })
	return res
}

// sessions parses `ac ls --porcelain`.
func sessions() []session {
	out, err := exec.Command("ac", "ls", "--porcelain").Output()
	if err != nil {
		return nil
	}
	var res []session
	for line := range strings.SplitSeq(strings.TrimRight(string(out), "\n"), "\n") {
		if line == "" {
			continue
		}
		f := strings.Split(line, "\t")
		if len(f) < 5 {
			continue
		}
		res = append(res, session{Server: f[0], Repo: f[1], Branch: f[2], Agent: f[3], Attached: f[4] == "1"})
	}
	return res
}

// --- handlers ---

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	if err := page.Execute(w, pageData{Sessions: sessions(), Repos: repos()}); err != nil {
		log.Print(err)
	}
}

func handleSpawn(w http.ResponseWriter, r *http.Request) {
	repoName := r.FormValue("repo")
	branch := r.FormValue("branch")
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

// handleRmWorktree removes a branch worktree (keeping the branch ref).
// --force --force clears dirty trees and stale agent locks.
func handleRmWorktree(w http.ResponseWriter, r *http.Request) {
	repoName := r.FormValue("repo")
	branch := r.FormValue("branch")
	if err := validateRepo(repoName); err != nil {
		fail(w, err)
		return
	}
	if err := validateBranch(branch); err != nil || branch == "" {
		fail(w, fmt.Errorf("invalid branch: %q", branch))
		return
	}
	run(w, r, "git", "-C", filepath.Join(gitRoot, repoName),
		"worktree", "remove", "--force", "--force", filepath.Join(wtRoot, repoName, branch))
}

// run executes a command and, on success, redirects back to the index; on
// failure it shows the combined output so the error isn't swallowed.
func run(w http.ResponseWriter, r *http.Request, name string, args ...string) {
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		http.Error(w, fmt.Sprintf("%s %s failed: %v\n\n%s", name, strings.Join(args, " "), err, out), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func fail(w http.ResponseWriter, err error) { http.Error(w, err.Error(), http.StatusBadRequest) }

// --- validation (the exec trust boundary; args go via argv, never a shell) ---

var (
	serverRe = regexp.MustCompile(`^ac-[A-Za-z0-9._-]+$`)
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

func home() string {
	h, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
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
		out, err := exec.Command("tailscale", "ip", "-4").Output()
		if err == nil {
			if ip := strings.TrimSpace(strings.SplitN(string(out), "\n", 2)[0]); ip != "" {
				return ip + ":" + port
			}
		}
		time.Sleep(2 * time.Second)
	}
	log.Fatal("could not determine tailscale IPv4 (pass -listen to override)")
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
  <button>spawn</button> <code>{{.Branch}}</code> <span class=muted>{{ago .LastActive}}</span>
 </form>
 <form method=post action=/rmworktree onsubmit="return confirm('Remove worktree {{$repo}}/{{.Branch}}?')">
  <input type=hidden name=repo value="{{$repo}}">
  <input type=hidden name=branch value="{{.Branch}}">
  <button>rm</button>
 </form>
</li>{{end}}
</ul>{{end}}
{{end}}
</body></html>
`))
