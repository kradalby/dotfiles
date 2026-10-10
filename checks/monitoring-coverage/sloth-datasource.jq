[.. | objects | .datasource? | objects | select(.type == "prometheus") | .uid] as $uids
| any(.templating.list[];
    .name == "Datasource" and .type == "datasource" and .query == "prometheus")
  and ($uids | length > 0)
  and all($uids[]; . == "${Datasource}")
