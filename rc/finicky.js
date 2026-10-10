export default {
  defaultBrowser: finicky.getSystemInfo().localizedName === "kratail2" ? "Google Chrome" : "Safari",
  // Destination rules override opener rules; first match wins.
  handlers: [
    {
      match: finicky.matchHostnames([
        "youtube.com",
        "*.youtube.com",
        "youtu.be",
        "*.youtu.be",
        "youtube-nocookie.com",
        "*.youtube-nocookie.com",
        "youtube.app.goo.gl",
      ]),
      browser: "Firefox"
    },
    {
      match: /^https?:\/\/github\.com\/.*\/headscale\/.*$/,
      browser: "Safari"
    },
    {
      match: /^https?:\/\/github\.com\/kradalby([\/?#]|$)/,
      browser: "Safari"
    },
    {
      match: finicky.matchHostnames([
        "proton.com",
        "*.proton.com",
        "protonmail.com",
        "*.protonmail.com",
        "proton.me",
        "*.proton.me",
      ]),
      browser: "Safari"
    },
    {
      match: finicky.matchHostnames([
        "discord.gg",
        "*.discord.gg",
        "discordapp.com",
        "*.discordapp.com",
        "discord.com",
        "*.discord.com",
        "discordcdn.com",
        "*.discordcdn.com",
      ]),
      browser: "Safari"
    },
    {
      match: finicky.matchHostnames(["sandefjordfiber.no", "*.sandefjordfiber.no"]),
      browser: "Safari"
    },
    {
      match: (_url, { opener }) =>
        [
          "com.openai.chat",
          "com.openai.codex",
          "com.anthropic.claudefordesktop",
          "com.hnc.Discord",
          "net.whatsapp.WhatsApp",             // WhatsApp
          "org.whispersystems.signal-desktop",  // Signal
          "com.apple.MobileSMS",               // iMessage / Messages
          "ru.keepcoder.Telegram",             // Telegram
          "com.facebook.archon",               // Facebook Messenger
        ].includes(opener?.bundleId),
      browser: "Safari"
    }
  ],
  rewrite: [{
    // Unwrap redirect wrappers (Outlook Safelinks, Google /url, Slack) so the
    // real destination gets routed by the handlers above instead of the
    // wrapper host. Slack desktop sends every link through slack-redir.net.
    match: (url) =>
      /(^|\.)safelinks\.protection\.outlook\.com$/.test(url.host) ||
      /(^|\.)slack-redir\.net$/.test(url.host) ||
      (url.host === "www.google.com" && url.pathname === "/url"),
    url: (url) => {
      const target = url.searchParams.get("url") || url.searchParams.get("q") || url.searchParams.get("u");
      return target || url;
    },
  }, {
    match: () => true,
    url: (url) => {
      for (const key of [...url.searchParams.keys()]) {
        if (key.startsWith("utm_") || key.startsWith("uta_") || key === "fbclid" || key === "gclid") {
          url.searchParams.delete(key);
        }
      }
      return url;
    },
  }]
};
