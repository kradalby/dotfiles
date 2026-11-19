# Websites tracked in Umami: name -> { id; domain; }.
#
# The IDs are chosen here, not by Umami. Each app carries its ID in its own
# source or config, and core.oracldn/umami.nix creates any that are missing,
# so an app and the server cannot disagree about which sites exist.
{
  krapage = {
    id = "a3ba0493-127b-4de7-a889-f029c9ef5726";
    domain = "kradalby.no";
  };
  hvor = {
    id = "0de65a1e-5275-4e39-a78e-364e704c0867";
    domain = "hvor.kradalby.no";
  };
  hugin = {
    id = "2145b3cd-1fcf-496c-8b45-c43951ff9129";
    domain = "hugin.dalby.ts.net";
  };
  resume = {
    id = "22ed64e2-2fb1-4e6f-936e-70245264f121";
    domain = "resume.kradalby.no";
  };
  asparges-beta = {
    id = "7c69f259-3316-4bb0-ad18-1a33c70a7f49";
    domain = "beta.aspargesgaarden.no";
  };
  sfiber = {
    id = "2d30563a-673d-422c-b03a-90c140052360";
    domain = "minside.sandefjordfiber.no";
  };
}
