set json (remarshal -if yaml -of json -i $argv[1])
echo "builtins.fromJSON ''$json''" \
   | nix-instantiate --eval --strict -E - \
   | perl -ne 's/(?!\ )([A-Za-z0-9\-\/]+[\.\/]+[A-Za-z0-9\-\/]+)(?=\ =\ )/"$1"/g; print;'
