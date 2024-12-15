{pkgs, ...}: {
  home.packages = with pkgs; [
    (pkgs.writeShellApplication
      {
        name = "rebase-schema";

        runtimeInputs = [git gnused];

        text = ''
          # Courtesy of Zofrex
          rebase_schema() {
            git restore --staged control/cfgdb/schemas/v*.sql.gz &&
            git restore control/cfgdb/schemas/v*.sql.gz &&
            ./tool/go build ./control/cfgdb &&
            currentVersion=$(grep -i 'insert.*into.*main\.version' control/cfgdb/schema.sql | sed -E 's/.*[, ]+([0-9]+)[ )]+.*/\1/') &&
            echo "Current version $${currentVersion}" &&
            nextVersion=$((currentVersion + 1)) &&
            echo "Next version $${nextVersion}" &&
            sed -i "" -E '/insert.*into.*main.version/Is/(.*[, ]+)[0-9]+([ )]+.*)/\1'"$nextVersion"'\2/' control/cfgdb/schema.sql &&
            ./tool/go generate ./control/cfgdb &&
            echo "Adding control/cfgdb/schema.sql ..." &&
            git add control/cfgdb/schema.sql &&
            echo "Adding control/cfgdb/schemas/v$${nextVersion}.sql.gz ..." &&
            git add "control/cfgdb/schemas/v$${nextVersion}.sql.gz"
          }

          rebase_schema
        '';
      })
  ];
}
