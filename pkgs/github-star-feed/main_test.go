package main

import (
	"encoding/xml"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/stretchr/testify/require"
)

// The sample keeps GitHub's real shapes (space-separated dates, author email,
// media:thumbnail, a token in the self link) with invented names.
func TestFilter(t *testing.T) {
	sample, err := os.ReadFile("testdata/github.atom")
	require.NoError(t, err)

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Write(sample)
	}))
	defer upstream.Close()

	f, err := fetch(t.Context(), upstream.Client(), upstream.URL)
	require.NoError(t, err)
	kept, kinds, err := filter(f)
	require.NoError(t, err)
	require.Equal(t, map[string]int{
		"pr_merged": 1, "star": 2, "publish_release": 1, "ForkEvent": 1, "visibility_repo": 1,
	}, kinds)

	body, err := render(f.ID, kept)
	require.NoError(t, err)
	require.NotContains(t, string(body), "SECRETTOKEN")
	require.NotContains(t, string(body), "@example.com")

	var got feed
	require.NoError(t, xml.Unmarshal(body, &got))
	want := feed{
		XMLName: xml.Name{Space: "http://www.w3.org/2005/Atom", Local: "feed"},
		ID:      "tag:github.com,2008:/example/stars",
		Title:   "GitHub stars and follows",
		Updated: "2026-11-25T19:37:30Z",
		Author:  &person{Name: "GitHub"},
		Entries: []entry{
			{
				ID:      "tag:github.com,2008:star/1002",
				Updated: "2026-11-25T19:37:30Z",
				Link:    link{Rel: "alternate", Type: "text/html", Href: "https://github.com/acme/gadget"},
				Title:   text{Type: "html", Body: "bob starred acme/gadget"},
				Author:  person{Name: "bob", URI: "https://github.com/bob"},
				Content: text{Type: "html", Body: `<div class="body">A gadget &amp; more</div>`},
			},
			{
				ID:      "tag:github.com,2008:star/1006",
				Updated: "2026-11-25T16:18:51Z",
				Link:    link{Rel: "alternate", Type: "text/html", Href: "https://github.com/acme/widget"},
				Title:   text{Type: "html", Body: "erin starred acme/widget"},
				Author:  person{Name: "erin", URI: "https://github.com/erin"},
				Content: text{Type: "html", Body: "<div>widget</div>"},
			},
		},
	}
	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("rendered feed (-want +got):\n%s", diff)
	}
}
