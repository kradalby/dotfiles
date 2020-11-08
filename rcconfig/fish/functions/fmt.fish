function fmt
    prettier --write "**/*.{ts,js,md,yaml,yml,sass,css,scss}"
    golangci-lint run --fix
    black .
    terraform fmt -recursive
end
